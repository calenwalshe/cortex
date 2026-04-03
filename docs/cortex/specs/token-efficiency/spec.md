# Spec: token-efficiency

**Slug:** token-efficiency
**Timestamp:** 20260402T230356Z
**Status:** approved

---

## 1. Problem

The Cortex and GSD systems have no visibility into token consumption. Every skill invocation, subagent spawn, research phase, and executor task burns Claude tokens with no tracking, no cost attribution, and no efficiency optimization. External API costs (Perplexity, Tavily, Gemini) are similarly untracked because cortex-research bypasses the power-search library that already has cost tracking built in. Meanwhile, Codex CLI is available as a cheaper autonomous execution layer but only used for reviews — not for the GSD executor tasks that consume the most Claude tokens. Without observability data, infrastructure planning is guesswork and efficiency improvements can't be measured.

---

## 2. Scope

### In Scope

- Refactor cortex-research SKILL.md to use power-search as its search backend
- Build a token ledger (SQLite) that records Claude per-turn usage and Codex per-task usage
- Create a PostToolUse hook that extracts token data from session JSONL transcripts
- Create a Codex execution wrapper that extracts token data from `--json` JSONL output
- Build a task router that classifies GSD plan tasks as codex-safe vs claude-required
- Build a context capsule format and result schema for Codex execution handoff
- Integrate Codex execution into the GSD execute-plan flow with git worktree isolation
- Ship a CLI query script for offline analysis of the token ledger

### Out of Scope

- No budgets, caps, or spend enforcement
- No real-time dashboards or UI
- No inline per-command cost display
- No RTK integration
- No billing/cost-conversion beyond raw token counts and estimated USD
- Codex handoff for planning, clarify, or spec phases (execution and verification only)
- Replacing existing /codex-review or /gsd-codex-verify skills
- Custom tokenizer or token counting library

---

## 3. Architecture Decision

**Chosen approach:** Three independently shippable workstreams — (1) cortex-research refactor to power-search, (2) token ledger with PostToolUse hook, (3) Codex execution handoff with task router and worktree isolation.

**Rationale:** Each workstream delivers value independently. The refactor gives cost tracking for external APIs immediately. The ledger gives Claude token observability without depending on the refactor. The Codex handoff builds on both but can ship last. This avoids a monolithic delivery where nothing works until everything works.

### Alternatives Considered

- **Single unified database extending power-search:** Rejected — different granularity (per-search-query vs per-turn vs per-task), schema coupling risk, migration burden on power-search. `ATTACH DATABASE` at query time gives cross-source joins without coupling.
- **Replace gpt-researcher with Perplexity for --depth deep:** Rejected — gpt-researcher is an autonomous multi-step agent, not a single API call. Perplexity sonar-pro is single-shot. Capability downgrade for the rare deep research case. Keep gpt-researcher with post-hoc cost logging.
- **Dynamic task router (code complexity analysis):** Rejected for v1 — adds language-dependent AST parsing, slow (~seconds), fragile. Static 9-rule decision tree covers 90%+ of cases. Can add dynamic rules later if misclassification is a measured problem.
- **Codex retries on failure:** Rejected — if Codex failed, the task was likely misclassified or has unexpected complexity. Immediate fallback to Claude is simpler and more predictable. Doubles spend on failure for marginal recovery rate.
- **Token tracking via context_window.remaining_percentage only:** Rejected as primary source — percentage only, can't derive absolute counts, no cache hit data, no input/output split. Session JSONL transcripts are richer. Percentage retained as supplementary signal.

---

## 4. Interfaces

- **cortex-research SKILL.md** — Owned by Cortex. This spec rewrites all code blocks to use `power_search.search()`. Read: clarify brief, research dossier template. Write: research dossiers.
- **power-search Python library** (`power_search`) — Owned by user (pip package at `claude-stack-env`). This spec reads: `search()`, `usage`, `Intent`, `SearchResult`. Writes: nothing (library is a dependency, not modified).
- **`~/.power-search/usage.db`** — Owned by power-search. This spec reads via `ATTACH DATABASE` for cross-source queries. Never writes.
- **`~/.cortex/token-ledger.db`** — New. Owned by this spec. Written by: PostToolUse hook, Codex execution wrapper. Read by: CLI query script.
- **Session JSONL transcripts** (`~/.claude/projects/<slug>/<session>.jsonl`) — Owned by Claude Code. This spec reads the tail (last 8KB) via PostToolUse hook. Never writes.
- **`~/.claude/settings.json`** — Owned by user. This spec adds one PostToolUse hook entry.
- **GSD execute-plan.md** — Owned by GSD upstream. This spec modifies to add task classification + Codex execution steps before Claude executor spawn.
- **Codex CLI** (`codex exec --full-auto --json`) — Owned by OpenAI. This spec invokes via subprocess. Reads: stdin (context capsule). Writes: JSONL to stdout, files in worktree.
- **`.planning/config.json`** — Owned by GSD. This spec reads `codex.enabled` and `codex.timeout_seconds`. Writes: nothing.

---

## 5. Dependencies

- **power_search** (Python, pip) — Unified search router with cost tracking. Used for all cortex-research API calls.
- **better-sqlite3** (Node.js, npm) — Synchronous SQLite bindings for the PostToolUse hook. Required for ~0.5ms writes without process spawn overhead.
- **Codex CLI** (v0.106.0+, npm `@openai/codex`) — Autonomous execution via `codex exec --full-auto --json`. Already installed.
- **Claude Code hooks** (built-in) — PostToolUse event with `transcript_path` and `context_window` in stdin JSON.
- **GSD upstream** (`upstream/gsd/commands/gsd/execute-plan.md`) — Integration point for Codex task routing.

---

## 6. Risks

- **Session JSONL format instability** — Claude Code may change the transcript JSONL structure between versions. Mitigation: version-check the JSONL schema on first parse per session; fall back to percentage-only tracking if structure is unrecognized. Log a warning.
- **better-sqlite3 native compilation** — Requires node-gyp and build tools on the host. Mitigation: document prerequisite in install script; fall back to Python subprocess (~50ms) if better-sqlite3 is unavailable.
- **Codex task misclassification** — Static router may classify a complex task as codex-safe, leading to failure and wasted tokens. Mitigation: conservative fallback (all ambiguous tasks → Claude). Track misclassification rate in the ledger. Tighten rules based on data.
- **AGENTS.md / CLAUDE.md conflict** — Codex falls back to reading CLAUDE.md as project docs, which contains Claude-specific instructions. Mitigation: create a minimal `AGENTS.md` in projects where Codex execution is enabled, overriding the CLAUDE.md fallback.
- **Worktree merge conflicts** — Codex writes in a worktree that may conflict with main working tree changes. Mitigation: worktrees are short-lived (single task), merge immediately on completion. Conflicts trigger automatic fallback to Claude with context about the conflict.
- **Token pricing drift** — Hardcoded per-model pricing in the hook will become stale. Mitigation: centralize pricing in a `~/.cortex/pricing.json` config file. Update manually when pricing changes. Stale prices affect USD estimates only, not raw token counts.

---

## 7. Sequencing

1. **Refactor cortex-research SKILL.md** — Replace 8 raw API calls with power-search `search()` calls. Keep gpt-researcher for `--depth deep`. Delete "Available APIs" section. Add post-hoc cost logging for gpt-researcher. Verify: run a concept research pass and confirm power-search usage.db records the queries.

2. **Create token ledger schema** — Write `~/.cortex/token-ledger.db` with 4 tables (claude_turns, codex_tasks, sessions, daily_rollup). Write schema migration script. Verify: `sqlite3 ~/.cortex/token-ledger.db ".tables"` shows all 4 tables.

3. **Build PostToolUse hook** — Create `~/.claude/hooks/token-ledger.js`. Register in `~/.claude/settings.json`. Tail-reads session JSONL, extracts usage, writes to ledger. Verify: run a few tool calls, then `SELECT COUNT(*) FROM claude_turns` returns >0.

4. **Build CLI query script** — Create `scripts/cortex/token-report.sh` with key SQL queries (daily cost, phase cost, skill cost, cache hit ratio, session ranking). Verify: run script, get formatted output.

5. **Build task router** — Create `scripts/cortex/task-router.js` with 9-rule decision tree. Input: PLAN.md XML. Output: per-task classification. Verify: feed sample PLANs, confirm classification matches expected output.

6. **Build context capsule + result schema** — Create `templates/cortex/task-capsule.md` template and `schemas/task-result.schema.json`. Verify: generate a capsule from a sample plan, validate against schema.

7. **Build Codex execution wrapper** — Create `scripts/cortex/codex-exec-wrapper.sh`. Handles worktree creation, capsule generation, Codex invocation, JSONL parsing, result validation, worktree merge/cleanup, token ledger write. Verify: execute a sample codex-safe task, confirm worktree merge and ledger entry.

8. **Integrate into GSD execute-plan** — Modify `execute-plan.md` to add Steps 4.5 (classify) and 5a (Codex execution) before Step 5b (Claude executor). Add `codex` config section to `.planning/config.json` schema. Verify: run `/gsd:execute-phase` on a plan with mixed task types, confirm Codex handles safe tasks and Claude handles the rest.

---

## 8. Tasks

- [ ] Replace cortex-research Quick Path (Perplexity curl) with `search(intent=RESEARCH, provider="perplexity")`
- [ ] Replace cortex-research Standard Path Step 1 (Tavily + Jina) with `search(intent=SEARCH)` + `search(intent=READ_URL)`
- [ ] Replace cortex-research Standard Path Step 4 (Gemini curl) with `search(intent=GENERATE, provider="gemini")`
- [ ] Replace cortex-research YouTube Path with `search(intent=YOUTUBE_VIDEO)`
- [ ] Replace cortex-research URL/Crawl paths with `search(intent=READ_URL)` / `search(intent=CRAWL_SITE)`
- [ ] Add post-hoc `usage.record()` for gpt-researcher deep path
- [ ] Delete "Available APIs" section from cortex-research SKILL.md, add "Search Backend" reference
- [ ] Write SQLite schema migration script for `~/.cortex/token-ledger.db` (4 tables + indexes)
- [ ] Create `~/.claude/hooks/token-ledger.js` PostToolUse hook (tail-read JSONL, extract usage, write to ledger)
- [ ] Register token-ledger hook in `~/.claude/settings.json`
- [ ] Create `~/.cortex/pricing.json` with per-model token pricing
- [ ] Create `scripts/cortex/token-report.sh` CLI query tool
- [ ] Create `scripts/cortex/task-router.js` (9-rule decision tree)
- [ ] Create `templates/cortex/task-capsule.md` context capsule template
- [ ] Create `schemas/task-result.schema.json` result schema
- [ ] Create `scripts/cortex/codex-exec-wrapper.sh` (worktree + codex exec + JSONL parse + merge)
- [ ] Modify `execute-plan.md` to add task classification step (4.5) and Codex execution step (5a)
- [ ] Add `codex` config section to `.planning/config.json` schema documentation
- [ ] Write integration test: run cortex-research with power-search, verify usage.db entries
- [ ] Write integration test: run a session, verify token-ledger.db has claude_turns entries
- [ ] Write integration test: classify a sample PLAN.md, verify router output
- [ ] Write integration test: execute a codex-safe task via wrapper, verify worktree merge + ledger entry

---

## 9. Acceptance Criteria

- [ ] `cortex-research --phase concept` produces a dossier AND `~/.power-search/usage.db` shows new query entries with cost > 0
- [ ] `cortex-research --depth deep` still works via gpt-researcher (backward compat)
- [ ] `~/.cortex/token-ledger.db` exists with 4 tables (claude_turns, codex_tasks, sessions, daily_rollup) after schema migration
- [ ] After 10+ tool calls in a session, `SELECT COUNT(*) FROM claude_turns WHERE session_id = ?` returns >0 with non-zero token counts
- [ ] `scripts/cortex/token-report.sh` produces formatted output for: daily cost, phase cost, session ranking, cache hit ratio
- [ ] Token ledger hook adds <5ms latency per PostToolUse invocation (measured via elapsed_ms delta)
- [ ] `scripts/cortex/task-router.js` correctly classifies: (a) `type="auto"` with `<verify>` as codex-safe, (b) `type="checkpoint:*"` as claude-required, (c) tasks with >8 files as claude-required
- [ ] A codex-safe task executed via `codex-exec-wrapper.sh` produces: committed code in worktree, merged to main branch, `codex_tasks` entry in ledger with token counts
- [ ] Codex failure (timeout or test failure) triggers fallback to Claude executor without manual intervention
- [ ] `codex.enabled: false` in `.planning/config.json` routes all tasks to Claude executor (bypass Codex entirely)
- [ ] `ATTACH '~/.power-search/usage.db' AS ps; SELECT SUM(cost) FROM ps.usage` works from within token-ledger.db queries (cross-DB join)
