---
phase: "23"
plan: "01"
subsystem: token-efficiency
tags: [codex, execution-wrapper, worktree, lifecycle, ledger]
dependency_graph:
  requires: [task-router.js, task-capsule.md, task-result.schema.json, create-token-ledger.sh]
  provides: [codex-exec-wrapper.sh]
  affects: [execute-plan.md]
tech_stack:
  added: []
  patterns: [git-worktree-isolation, jsonl-parsing, structured-json-output]
key_files:
  created:
    - scripts/cortex/codex-exec-wrapper.sh
    - test/codex-exec-wrapper.test.sh
  modified: []
decisions:
  - "node -e used for JSON output construction instead of bash heredoc — avoids JSON escaping bugs with embedded result objects"
  - "All git worktree/merge/branch commands redirect stdout to /dev/null — wrapper output is exclusively structured JSON on stdout, diagnostics on stderr"
  - "write_ledger soft-fails if DB or sqlite3 missing — wrapper never crashes due to ledger unavailability"
  - "extract_result searches JSONL backwards for last turn.completed with parseable JSON content — handles both raw JSON and fenced code blocks"
metrics:
  duration: "12min"
  completed: "2026-04-03"
---

# Phase 23 Plan 01: Codex Execution Wrapper Summary

Full lifecycle Codex execution wrapper with 9-step flow (worktree, capsule, invoke, parse, validate, merge/cleanup, ledger write), 6 failure modes, timeout tiers, and structured JSON output.

## What Was Built

### scripts/cortex/codex-exec-wrapper.sh (524 lines)
- **9-step lifecycle:** parse args, create git worktree, generate capsule from template, invoke Codex with timeout, parse JSONL for token usage, extract result JSON, validate status, merge on success / cleanup on failure, write to token ledger
- **6 failure modes** all reclassify to `claude-required` (no Codex retries):
  - Timeout (exit 124): merges any committed partial work, falls back
  - Test failure (tests_passed:false): deletes worktree, passes failure context
  - Checkpoint (status:checkpoint): deletes worktree, passes checkpoint_detail
  - JSONL parse error: checks for commits, falls back
  - Merge conflict: aborts merge, falls back
  - Process crash (non-zero exit): logs stderr, falls back
- **Timeout tiers:** TDD=180s, auto <5 files=300s, auto 5-8 files=450s
- **Token tracking:** extracts usage from `turn.completed` JSONL events, sums across all turns, computes cost at o4-mini pricing
- **Ledger write:** INSERT into `codex_tasks` table with task_id, model, tokens, cost, session_id, phase, plan_file, exit_code, elapsed_ms
- **Structured output:** JSON on stdout with status, task_id, result, tokens, cost_usd, elapsed_ms, fallback_reason
- **Dry run mode:** `CODEX_DRY_RUN=1` skips Codex invocation, outputs mock success

### test/codex-exec-wrapper.test.sh (16 tests)
Tests cover: script existence, usage display, missing PLAN file, timeout tier calculation (TDD=180s, auto=300s), success path (dry run), JSONL token parsing (multi-event summation), result JSON extraction, test failure fallback, checkpoint fallback, crash fallback, parse error fallback, ledger write verification, capsule generation, worktree cleanup, output JSON structure validation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed stdout pollution from git commands**
- **Found during:** Task 2 (tests)
- **Issue:** `git worktree add`, `git merge`, `git branch -D` output ("HEAD is now at...", "Already up to date.", "Deleted branch...") was mixing with wrapper JSON on stdout
- **Fix:** Changed all git commands from `2>/dev/null` to `>/dev/null 2>&1`
- **Files modified:** scripts/cortex/codex-exec-wrapper.sh
- **Commit:** e7c4c9d

**2. [Rule 1 - Bug] Fixed JSON output construction using node instead of heredoc**
- **Found during:** Task 2 (tests)
- **Issue:** Bash heredoc for JSON output broke when embedding multi-line result JSON objects (unescaped newlines)
- **Fix:** Replaced heredoc `output_result` with `node -e` that uses `JSON.stringify` for proper escaping
- **Files modified:** scripts/cortex/codex-exec-wrapper.sh
- **Commit:** e7c4c9d

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| `node -e` for JSON output | Avoids bash heredoc escaping issues with nested JSON objects |
| Git commands suppress stdout | Wrapper output must be clean JSON only — diagnostics go to stderr |
| Soft-fail on missing ledger | Wrapper should never crash due to missing infrastructure |
| Backward search for result in JSONL | Last `turn.completed` is most likely to contain the final result |

## Known Stubs

None — all functionality is fully wired.

## Self-Check: PASSED

- [x] scripts/cortex/codex-exec-wrapper.sh exists and is executable
- [x] test/codex-exec-wrapper.test.sh exists and is executable
- [x] 23-01-PLAN.md exists
- [x] 23-01-SUMMARY.md exists
- [x] Commit 8285767 found (wrapper script)
- [x] Commit e7c4c9d found (tests + fixes)
