# Research Dossier: token-efficiency — implementation

**Slug:** token-efficiency
**Phase:** implementation
**Timestamp:** 20260402T225932Z
**Depth:** standard

---

## Summary

Implementation design is complete across all three workstreams. (1) The cortex-research refactor replaces 8 of 9 raw API calls with `power_search.search()` calls using exact Intent mappings; gpt-researcher stays as-is for `--depth deep` with a post-hoc cost log. (2) The token ledger uses a global SQLite DB at `~/.cortex/token-ledger.db` with separate tables for Claude turns, Codex tasks, and sessions — fed by a PostToolUse hook that tail-reads the session JSONL transcript (~2ms overhead) and a Codex execution wrapper that parses `--json` JSONL output. (3) The Codex handoff uses a task router (9-rule decision tree), context capsule piped via stdin, `--output-schema` for structured results, and git worktree isolation with automatic fallback to Claude executor on any failure.

---

## Findings

### A. cortex-research → power-search Refactor

**Exact replacements for all 9 raw API calls:**

| # | Current Call | Replacement | Intent | Provider |
|---|-------------|-------------|--------|----------|
| 1 | Perplexity curl (Quick) | `search(q, intent=RESEARCH, provider="perplexity")` | RESEARCH | perplexity (forced) |
| 2 | TavilyClient.search (Standard) | `search(q, intent=SEARCH, provider="tavily", depth="advanced", max_results=7)` | SEARCH | tavily (forced) |
| 3 | Jina curl (Standard) | `search(url, intent=READ_URL)` | READ_URL | auto (jina first) |
| 4 | Tavily+Jina gap-fill (Standard) | Loop: `search()` with SEARCH + READ_URL | SEARCH/READ_URL | tavily/auto |
| 5 | Gemini curl cross-ref (Standard) | `search(findings, intent=GENERATE, provider="gemini")` | GENERATE | gemini (forced) |
| 6 | gpt-researcher (Deep) | **Keep as-is** + post-hoc `usage.record()` | N/A | gpt_researcher |
| 7 | Gemini genai (YouTube) | `search(url, intent=YOUTUBE_VIDEO, mode="summary")` | YOUTUBE_VIDEO | auto (gemini_youtube) |
| 8 | Jina curl (URL) | `search(url, intent=READ_URL)` | READ_URL | auto |
| 9 | Crawl4AI (Site crawl) | `search(url, intent=CRAWL_SITE)` | CRAWL_SITE | auto (crawl4ai) |

**Standard Path orchestration loop (5 steps):**
1. `search(query, SEARCH, "tavily")` → get results + source URLs
2. For top 3 URLs: `search(url, READ_URL)` → extract full content
3. Claude identifies gaps, generates follow-up queries
4. For 1-2 follow-ups: repeat steps 1-2 with smaller limits
5. `search(findings, GENERATE, "gemini")` → cross-reference
6. Claude synthesizes into dossier (no API call)

**gpt-researcher decision:** Keep for `--depth deep`. It's an autonomous multi-step agent that can't be meaningfully represented as a single `SearchResult`. Add a post-hoc cost log via `usage.record(provider="gpt_researcher", ...)` after completion.

**SKILL.md changes:** Delete the "Available APIs" section entirely. Replace all code blocks with power-search calls. Add "Search Backend" section pointing to power-search SKILL.md. ~80 lines of raw API calls removed, ~30 lines of power-search calls added.

### B. Token Ledger Design

**Database: `~/.cortex/token-ledger.db` (global)**

Global beats project-scoped because: single query for daily totals across all projects, no `.gitignore` pollution, one backup target, sessions naturally span projects. The `project_slug` column handles project-level filtering.

**Schema (4 tables):**

```sql
-- Per-turn Claude tracking
claude_turns (id, ts, session_id, message_id, model,
  input_tokens, output_tokens, cache_creation_tokens, cache_read_tokens,
  cost_usd, project_slug, cwd, phase, skill, remaining_pct)

-- Per-task Codex tracking
codex_tasks (id, ts, task_id, model,
  input_tokens, output_tokens, cached_tokens, reasoning_tokens,
  cost_usd, session_id, project_slug, phase, task_type, plan_file,
  exit_code, elapsed_ms)

-- Session metadata
sessions (session_id PK, started_at, ended_at, project_slug, model,
  compacted, total_input, total_output, total_cost)

-- Materialized daily rollups
daily_rollup (date, provider, model, project_slug, phase,
  input_tokens, output_tokens, cost_usd, turn_count)
```

Power-search's `~/.power-search/usage.db` stays separate — use `ATTACH DATABASE` at query time for cross-source joins. No migration, no coupling.

**PostToolUse hook (`token-ledger.js`):**
- Fires on every PostToolUse (empty matcher = all tools)
- Reads last 8KB of session JSONL transcript via `fs.readSync` with offset (O(1), ~1ms)
- Extracts last assistant turn's `usage` block (input_tokens, output_tokens, cache_creation, cache_read)
- Deduplicates via `message_id` (stored in `/tmp/ledger-last-{session_id}`)
- Computes `cost_usd` using hardcoded per-model pricing
- Writes to `claude_turns` + upserts `sessions` running totals in a single transaction (~0.5ms)
- Reads `phase` from `.planning/STATE.md` at cwd
- Extracts `project_slug` from `transcript_path` directory name
- **Total overhead: ~2ms per hook invocation** — imperceptible
- **Dependency:** `better-sqlite3` (Node.js, synchronous SQLite bindings)

**Codex integration:**
- The Codex execution wrapper parses `--json` JSONL output post-hoc
- Extracts `turn.completed` events (the only type with token usage)
- Sums across all turns for the task
- Writes one row to `codex_tasks` with total tokens + computed cost
- Parent Claude session passes `session_id`, `phase`, `project_slug` as env vars

**Compaction detection:** If `remaining_pct` jumps >30 points between consecutive turns, set `sessions.compacted = 1`. Heuristic but reliable — no other event causes such a jump.

**Session end:** Lazy detection — mark ended if no turn recorded for >30 minutes (cron or next session start).

### C. Codex Execution Handoff

**Task router (9-rule decision tree, first match wins):**

1. Plan has `autonomous: false` → ALL claude-required
2. Task type is `checkpoint:*` → claude-required
3. Action references auth patterns (login, API key, deploy) → claude-required
4. File count > 8 → claude-required
5. Acceptance criteria has subjective language → claude-required
6. Action references architectural changes (new table, schema change) → claude-required
7. Task is `type="auto"` with `tdd="true"` → **codex-safe**
8. Task is `type="auto"` with automated `<verify>` → **codex-safe**
9. Task is `type="auto"` but no automated verify → claude-required
10. Fallback → claude-required (conservative)

**Context capsule format (`task-capsule.md`):**
- Identity: phase, plan, task number, workspace path
- Task definition: name, action, files, verify command, done criteria
- Deviation rules: Rules 1-3 (auto-fix), Rule 4 (checkpoint + stop)
- Commit instructions: format, staging rules
- File context: existing files truncated to 200 lines (12KB cap)
- Result format: JSON conforming to task-result schema
- **Total size: ~3-15KB** (well under Codex's context capacity)

**Result schema (`task-result.schema.json`):**
```json
{
  "status": "complete" | "failed" | "checkpoint",
  "files_changed": ["path/to/file"],
  "tests_passed": true | false,
  "test_output_summary": "12 tests passed",
  "deviations": ["[Rule 1 - Bug] description"],
  "commit_hash": "a1b2c3d" | null,
  "error_message": null | "description",
  "checkpoint_detail": null | "architectural decision needed"
}
```

**Execution flow (9 steps):**
1. Read PLAN.md, parse task XML
2. Run task router → partition into `codex_tasks[]` + `claude_tasks[]`
3. Create git worktree: `git worktree add /tmp/gsd-codex-{phase}-{plan} -b codex/{phase}-{plan}`
4. For each codex task: generate capsule → write to `/tmp/gsd-capsule-*.md`
5. Run: `cat capsule.md | timeout ${T} codex exec --full-auto --json --output-schema schema.json -C /worktree -`
6. Parse JSONL: extract token usage from `turn.completed` events, extract result JSON from final message
7. Validate result against schema
8. On success: `git merge codex/{phase}-{plan}` → cleanup worktree
9. Update GSD state, hand remaining `claude_tasks[]` to Claude executor with `<completed_tasks>` context

**Failure handling — every failure reclassifies to Claude, no Codex retries:**

| Failure | Detection | Response |
|---------|-----------|----------|
| Timeout | exit 124 | Merge any committed work, reclassify remainder |
| Tests fail | `tests_passed: false` | Delete worktree, pass failure context to Claude |
| Checkpoint hit | `status: "checkpoint"` | Delete worktree, pass `checkpoint_detail` to Claude |
| JSONL parse error | No `turn.completed` | Check for commits in worktree, reclassify |
| Merge conflict | `git merge` non-zero | Delete worktree, Claude implements from scratch |
| Process crash | Non-zero, non-124 exit | Log stderr, delete worktree, reclassify |

**Integration point:** `execute-plan.md` Step 5 (spawn gsd-executor). Insert Steps 4.5 (classify) and 5a (Codex execution) before 5b (Claude executor for remaining tasks). Drive workflow needs no changes — it consumes SUMMARY.md artifacts regardless of execution model.

**Config (`codex` section in `.planning/config.json`):**
```json
{ "codex": { "enabled": true, "timeout_seconds": 300, "max_file_count": 8, "fallback_on_failure": true } }
```

`codex.enabled: false` disables the router entirely — all tasks go to Claude as today.

---

## Trade-offs

### Option: better-sqlite3 vs Python subprocess for hook DB writes
**Pros (better-sqlite3):** ~0.5ms writes, synchronous, no process spawn, hooks already use Node.js
**Cons:** Requires native compilation (node-gyp), adds npm dependency
**Pros (Python subprocess):** No native deps, Python already available
**Cons:** ~50ms overhead per hook call (process spawn), 25x slower
**Verdict:** selected better-sqlite3 — 2ms vs 50ms matters when the hook fires on every tool use

### Option: Codex retries vs immediate fallback to Claude
**Pros (retry):** Some failures are transient (Codex API hiccup, brief timeout)
**Cons:** Doubles token spend on failure, adds complexity, transient failures are rare with --full-auto
**Verdict:** selected immediate fallback — if Codex failed, the task was likely misclassified or has unexpected complexity. Claude handles edge cases better. No retries = simpler, more predictable.

### Option: Static task router (rules-based) vs dynamic (inspect code complexity)
**Pros (static):** Deterministic, fast, debuggable, no false positives from heuristic analysis
**Cons:** May misclassify borderline tasks (simple tasks with many files, complex tasks with few files)
**Pros (dynamic):** Could analyze AST complexity, test coverage, dependency graph
**Cons:** Slow (~seconds to analyze), fragile (language-dependent), over-engineering for v1
**Verdict:** selected static for v1 — the 9-rule decision tree covers 90%+ of cases. Can add dynamic rules later if misclassification is a real problem.

### Option: Unified DB (extend power-search) vs separate token-ledger.db
**Pros (unified):** Single database, simpler queries
**Cons:** Different granularity (per-search-query vs per-turn vs per-task), schema coupling, migration risk to power-search
**Verdict:** selected separate — use `ATTACH DATABASE` at query time for cross-source analysis. Clean separation of concerns, no migration risk, power-search stays independent.

---

## Recommendations

- **Implement in three phases, each independently shippable:**
  1. **cortex-research refactor** — swap API calls to power-search, gain cost tracking immediately. Smallest scope, highest certainty.
  2. **Token ledger + PostToolUse hook** — add the SQLite DB and hook. Starts recording from day one. Independent of Codex handoff.
  3. **Codex execution handoff** — task router, capsule format, execution wrapper. Builds on the ledger (Codex costs go to same DB) but is the most complex piece.

- **For the cortex-research refactor:** Edit SKILL.md only — no new files needed. Replace code blocks, delete "Available APIs" section, add power-search reference. Can be done in a single commit.

- **For the token ledger:** Three files — `~/.claude/hooks/token-ledger.js` (hook), `scripts/cortex/token-report.sh` (CLI query tool), schema migration script. Register hook in settings.json.

- **For the Codex handoff:** Four files — `scripts/cortex/task-router.js` (classifier), `templates/cortex/task-capsule.md` (capsule template), `schemas/task-result.schema.json` (result schema), `scripts/cortex/codex-exec-wrapper.sh` (execution wrapper). Modify `execute-plan.md` to insert classification + Codex steps.

- **Ship a `cortex-token-report` CLI script** that runs the key SQL queries (daily cost, phase cost, skill cost, cache hit ratio) against the ledger. Simple shell script wrapping `sqlite3` commands. Satisfies the "analyze later" requirement without building any UI.

---

## Open Questions

- Should `better-sqlite3` be pre-installed globally or bundled with Cortex? The hook needs it at runtime. Alternative: use Node 22's built-in `node:sqlite` if the environment supports it.
- What's the actual token cost delta between Claude executor and Codex for equivalent tasks? Need a benchmark after v1 ships to validate the handoff ROI.
- Should the `skill` column in `claude_turns` capture the tool name (Bash, Read, Edit) or the GSD skill name (/gsd:execute-phase)? Tool-level is what the hook receives; skill-level requires parsing the transcript.
- How should the daily rollup be maintained — SQLite trigger on INSERT (automatic but hidden) or explicit cron/script (debuggable but requires setup)?
- For the Codex handoff, should capsules include raw file content (Codex doesn't re-read, saves Codex tokens) or just file paths (Codex reads current state, always fresh)? Current design includes content — but large files may blow the 16KB budget.

---

## Sources

- `/home/agent/projects/cortex/skills/cortex-research/SKILL.md` — current research skill (9 raw API calls)
- `/home/agent/projects/cortex/skills/power-search/SKILL.md` — power-search skill definition
- `/home/agent/claude-stack-env/lib/python3.12/site-packages/power_search/base.py` — Intent enum, SearchResult
- `/home/agent/claude-stack-env/lib/python3.12/site-packages/power_search/router.py` — routing logic
- `/home/agent/claude-stack-env/lib/python3.12/site-packages/power_search/tracker.py` — cost tracking
- `/home/agent/.claude/hooks/gsd-context-monitor.js` — existing PostToolUse hook pattern
- `/home/agent/.claude/hooks/gsd-statusline.js` — existing bridge file pattern
- `/home/agent/.claude/skills/codex-review/SKILL.md` — existing Codex review handoff
- `/home/agent/.claude/skills/gsd-codex-verify/SKILL.md` — existing dual-tool verification
- `/home/agent/projects/cortex/upstream/gsd/agents/gsd-executor.md` — executor agent (deviation rules, commit protocol)
- `/home/agent/projects/cortex/upstream/gsd/commands/gsd/execute-plan.md` — plan execution (integration point)
- `/home/agent/projects/cortex/upstream/gsd/commands/gsd/execute-phase.md` — phase execution (wave parallelization)
