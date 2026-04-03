# Contract: token-efficiency — execute

**ID:** token-efficiency-001
**Slug:** token-efficiency
**Phase:** execute
**Created:** 20260402T230356Z
**Status:** approved

---

## Objective

Build token observability, cost tracking, and Codex execution handoff into Cortex and GSD so that every API call and LLM turn is recorded in a queryable ledger, and suitable GSD tasks can be offloaded to Codex autonomously.

---

## Deliverables

- `skills/cortex-research/SKILL.md` — refactored to use power-search backend
- `~/.cortex/token-ledger.db` — SQLite database (4 tables)
- `~/.claude/hooks/token-ledger.js` — PostToolUse token tracking hook
- `~/.cortex/pricing.json` — per-model token pricing config
- `scripts/cortex/token-report.sh` — CLI query tool
- `scripts/cortex/task-router.js` — task classification decision tree
- `templates/cortex/task-capsule.md` — Codex context capsule template
- `schemas/task-result.schema.json` — Codex result schema
- `scripts/cortex/codex-exec-wrapper.sh` — Codex execution wrapper
- Modified `execute-plan.md` — Codex integration steps

---

## Scope

### In Scope

- cortex-research power-search refactor (8 API call replacements + gpt-researcher cost log)
- Token ledger schema, PostToolUse hook, Codex wrapper token extraction
- Task router (9-rule static classifier)
- Context capsule format and result schema
- Codex execution via git worktree with auto-merge/cleanup
- GSD execute-plan integration (Steps 4.5, 5a, 5b)
- CLI query script for offline analysis
- Integration tests for each workstream

### Out of Scope

- Budgets, caps, or spend enforcement
- Real-time dashboards or UI
- Inline per-command cost display
- RTK integration
- Codex for planning/clarify/spec phases
- Replacing /codex-review or /gsd-codex-verify
- Dynamic task router (AST/complexity analysis)
- Codex retry logic on failure

---

## Write Roots

- `skills/cortex-research/` — SKILL.md refactor
- `~/.cortex/` — token-ledger.db, pricing.json
- `~/.claude/hooks/` — token-ledger.js
- `~/.claude/settings.json` — hook registration (append only)
- `scripts/cortex/` — token-report.sh, task-router.js, codex-exec-wrapper.sh
- `templates/cortex/` — task-capsule.md
- `schemas/` — task-result.schema.json
- `upstream/gsd/commands/gsd/` — execute-plan.md modification

---

## Done Criteria

- [ ] `cortex-research --phase concept` produces a dossier AND `~/.power-search/usage.db` shows new query entries with cost > 0
- [ ] `cortex-research --depth deep` still works via gpt-researcher (backward compat)
- [ ] `~/.cortex/token-ledger.db` exists with 4 tables (claude_turns, codex_tasks, sessions, daily_rollup)
- [ ] After 10+ tool calls, `claude_turns` has entries with non-zero token counts
- [ ] `token-report.sh` produces formatted output for daily cost, phase cost, session ranking, cache hit ratio
- [ ] Token ledger hook adds <5ms latency per PostToolUse invocation
- [ ] Task router correctly classifies auto+verify as codex-safe, checkpoint as claude-required, >8 files as claude-required
- [ ] Codex-safe task via wrapper: committed code merged, `codex_tasks` entry in ledger with token counts
- [ ] Codex failure triggers automatic fallback to Claude executor
- [ ] `codex.enabled: false` bypasses Codex entirely
- [ ] Cross-DB query (`ATTACH power-search usage.db`) works from token-ledger.db

---

## Validators

- [ ] `sqlite3 ~/.cortex/token-ledger.db ".tables"` returns: `claude_turns codex_tasks daily_rollup sessions`
- [ ] `sqlite3 ~/.cortex/token-ledger.db "SELECT COUNT(*) FROM claude_turns"` returns > 0 after a test session
- [ ] `sqlite3 ~/.power-search/usage.db "SELECT COUNT(*) FROM usage WHERE ts > datetime('now', '-1 hour')"` returns > 0 after a cortex-research run
- [ ] `node -e "require('better-sqlite3')"` exits 0 (dependency available)
- [ ] `bash scripts/cortex/token-report.sh` exits 0 and produces non-empty output
- [ ] `node scripts/cortex/task-router.js < test-plan.xml` outputs valid JSON with per-task classification
- [ ] `codex exec --full-auto --json --output-schema schemas/task-result.schema.json -C /tmp/test-worktree - < /tmp/test-capsule.md` exits 0 and produces valid result JSON
- [ ] `grep "token-ledger" ~/.claude/settings.json` returns a match (hook registered)

---

## Eval Plan

docs/cortex/evals/token-efficiency/eval-plan.md (pending)

---

## Approvals

- [x] Contract approval
- [ ] Evals approval

---

## Rollback Hints

- Delete `~/.cortex/token-ledger.db` to remove all token tracking data
- Delete `~/.cortex/pricing.json` to remove pricing config
- Remove the `token-ledger` hook entry from `~/.claude/settings.json`
- Delete `~/.claude/hooks/token-ledger.js`
- Revert `skills/cortex-research/SKILL.md` to pre-refactor state via `git checkout HEAD~N -- skills/cortex-research/SKILL.md`
- Delete `scripts/cortex/task-router.js`, `scripts/cortex/codex-exec-wrapper.sh`, `scripts/cortex/token-report.sh`
- Delete `templates/cortex/task-capsule.md`, `schemas/task-result.schema.json`
- Revert `execute-plan.md` modifications via git
- Remove `codex` section from `.planning/config.json` if added
