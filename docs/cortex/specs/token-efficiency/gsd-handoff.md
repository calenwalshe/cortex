# GSD Handoff: token-efficiency

**Slug:** token-efficiency
**Timestamp:** 20260402T230356Z
**Status:** draft

---

## Objective

Build token observability and efficiency into Cortex and GSD by: (1) refactoring cortex-research to use power-search for unified API routing and cost tracking, (2) creating a token ledger that records Claude and Codex token consumption per turn/task, and (3) enabling Codex CLI as an autonomous execution layer for suitable GSD tasks — with automatic fallback to Claude for tasks requiring interactive context. Success = every API call and Claude/Codex turn is tracked in queryable storage, and 60-70% of GSD auto tasks can run via Codex with zero human intervention.

---

## Deliverables

- Modified `skills/cortex-research/SKILL.md` — all raw API calls replaced with power-search `search()` calls
- `~/.cortex/token-ledger.db` — SQLite database with claude_turns, codex_tasks, sessions, daily_rollup tables
- `~/.claude/hooks/token-ledger.js` — PostToolUse hook that extracts token usage from session JSONL transcripts
- `~/.cortex/pricing.json` — per-model token pricing config
- `scripts/cortex/token-report.sh` — CLI query tool for offline analysis
- `scripts/cortex/task-router.js` — 9-rule decision tree classifying GSD tasks as codex-safe vs claude-required
- `templates/cortex/task-capsule.md` — context capsule template for Codex execution handoff
- `schemas/task-result.schema.json` — JSON Schema for structured Codex execution results
- `scripts/cortex/codex-exec-wrapper.sh` — Codex execution wrapper (worktree + invoke + parse + merge)
- Modified `execute-plan.md` — task classification step (4.5) and Codex execution step (5a) before Claude executor

---

## Requirements

- None formalized

---

## Tasks

- [ ] Replace all 8 raw API calls in cortex-research SKILL.md with power-search `search()` calls (Quick/Perplexity, Standard/Tavily+Jina+Gemini, YouTube, URL, Crawl)
- [ ] Add post-hoc `usage.record()` for gpt-researcher deep path
- [ ] Delete "Available APIs" section, add "Search Backend" reference to power-search
- [ ] Write SQLite schema migration script for `~/.cortex/token-ledger.db`
- [ ] Create PostToolUse hook `token-ledger.js` (tail-read 8KB of session JSONL, extract usage, deduplicate by message_id, compute cost, write to ledger)
- [ ] Register hook in `~/.claude/settings.json`
- [ ] Create `~/.cortex/pricing.json` with Claude and Codex per-model rates
- [ ] Create `scripts/cortex/token-report.sh` (daily cost, phase cost, skill cost, cache hit ratio, session ranking queries)
- [ ] Create `scripts/cortex/task-router.js` implementing 9-rule decision tree
- [ ] Create `templates/cortex/task-capsule.md` (identity, task definition, deviation rules, commit instructions, file context, result format)
- [ ] Create `schemas/task-result.schema.json` (status, files_changed, tests_passed, deviations, commit_hash, error_message, checkpoint_detail)
- [ ] Create `scripts/cortex/codex-exec-wrapper.sh` (worktree create, capsule generate, codex exec with timeout, JSONL parse for tokens, result validate, worktree merge or cleanup, ledger write)
- [ ] Modify `execute-plan.md` Step 4.5: read plan, run task router, partition tasks
- [ ] Modify `execute-plan.md` Step 5a: execute codex-safe tasks via wrapper, merge results
- [ ] Modify `execute-plan.md` Step 5b: spawn Claude executor for remaining tasks with `<completed_tasks>` context
- [ ] Add `codex` config section to `.planning/config.json` docs (`enabled`, `timeout_seconds`, `max_file_count`, `fallback_on_failure`)
- [ ] Write integration tests for: power-search research pass, token ledger recording, task router classification, Codex execution + merge

---

## Acceptance Criteria

- [ ] `cortex-research --phase concept` produces a dossier AND `~/.power-search/usage.db` shows new query entries with cost > 0
- [ ] `cortex-research --depth deep` still works via gpt-researcher (backward compat)
- [ ] `~/.cortex/token-ledger.db` exists with 4 tables after schema migration
- [ ] After 10+ tool calls, `claude_turns` has entries with non-zero token counts for the session
- [ ] `token-report.sh` produces formatted output for daily cost, phase cost, session ranking, cache hit ratio
- [ ] Token ledger hook adds <5ms latency per PostToolUse invocation
- [ ] Task router correctly classifies: auto+verify as codex-safe, checkpoint as claude-required, >8 files as claude-required
- [ ] Codex-safe task via wrapper: committed code merged to main, `codex_tasks` entry in ledger with token counts
- [ ] Codex failure triggers automatic fallback to Claude executor
- [ ] `codex.enabled: false` bypasses Codex entirely (all tasks to Claude)
- [ ] Cross-DB query (`ATTACH power-search usage.db`) works from token-ledger.db

---

## Contract Link

docs/cortex/contracts/token-efficiency/contract-001.md
