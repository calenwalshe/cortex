---
phase: 20-token-report-cli
plan: "01"
subsystem: infra
tags: [sqlite3, token-tracking, cli, reporting]

requires:
  - phase: 18-token-ledger-schema
    provides: ~/.cortex/token-ledger.db with 4 tables (claude_turns, codex_tasks, sessions, daily_rollup)
  - phase: 19-posttooluse-hook
    provides: PostToolUse hook that populates the ledger from session transcripts
provides:
  - token-report.sh CLI for formatted SQL queries against the token ledger
  - Cross-DB ATTACH support for power-search usage.db joins
  - 7 report types with filter flags (--today, --phase, --session, --report)
affects: [codex-task-router, token-dashboard]

tech-stack:
  added: []
  patterns: [sqlite3 CLI formatted queries, heredoc SQL with shell variable interpolation, ATTACH DATABASE for cross-source analysis]

key-files:
  created:
    - scripts/cortex/token-report.sh
    - test/token-report.test.sh
  modified: []

key-decisions:
  - "Shell script wrapping sqlite3 CLI — no runtime dependencies beyond sqlite3"
  - "ATTACH power-search usage.db at query time rather than unified DB"
  - "7 reports covering daily/phase/skill/cache/sessions/burndown/provider dimensions"
  - "Task 3 (manifest registration) skipped — runtime-manifest.json tracks skills/agents/hooks only, not scripts"

patterns-established:
  - "token-report query pattern: heredoc SQL with shell function filter injection"
  - "cross-DB ATTACH pattern for power-search joins"

requirements-completed: [TE-06]

duration: 4min
completed: 2026-04-03
---

# Phase 20 Plan 01: Token Report CLI Summary

**Shell CLI query tool with 7 formatted SQL reports against the token ledger, cross-DB power-search joins, and filter flags**

## Performance

- **Duration:** 4 min
- **Started:** 2026-04-03T03:17:51Z
- **Completed:** 2026-04-03T03:21:47Z
- **Tasks:** 2 completed (1 skipped — not applicable)
- **Files created:** 2

## Accomplishments
- Created token-report.sh with 7 formatted SQL reports: daily cost, phase cost, skill cost, cache hit ratio, session ranking, context burndown, cost by provider/model
- Flag interface: --today, --phase, --session, --report for filtering; --help for usage
- Cross-DB ATTACH for power-search usage.db when available
- 15 integration tests covering all reports, filters, and error handling

## Task Commits

Each task was committed atomically:

1. **Task 1: Create token-report.sh** - `e4bcba5` (feat) + `e9316aa` (fix — Rule 1 bash comment syntax)
2. **Task 2: Add integration tests** - `8b6dde2` (test)
3. **Task 3: Register in manifest** - SKIPPED (not applicable — manifest tracks skills/agents/hooks only)

## Files Created/Modified
- `scripts/cortex/token-report.sh` - CLI query tool with 7 SQL reports, filter flags, cross-DB ATTACH
- `test/token-report.test.sh` - 15 integration tests with isolated temp DB and synthetic data

## Decisions Made
- Shell script wrapping sqlite3 CLI chosen over Node.js — zero runtime dependencies beyond sqlite3
- ATTACH power-search usage.db conditionally at query time rather than merging into a unified DB
- Manifest registration skipped — runtime-manifest.json only tracks skills, agents, hooks, and hook_events; scripts in scripts/cortex/ are standalone

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed bash comment syntax in provider report**
- **Found during:** Task 2 (test execution)
- **Issue:** SQL-style comment (`-- Cross-source:`) outside heredoc was interpreted as bash command `--`
- **Fix:** Changed to bash-style comment (`# Cross-source:`)
- **Files modified:** scripts/cortex/token-report.sh
- **Verification:** All 15 tests pass
- **Committed in:** e9316aa

---

**Total deviations:** 1 auto-fixed (1 bug), 1 task skipped (manifest not applicable)
**Impact on plan:** Bug fix was trivial syntax error caught by tests. Task 3 skip is correct — no scripts section exists in the manifest.

## Issues Encountered
None.

## User Setup Required
None - token-report.sh uses the same TOKEN_LEDGER_DB env var as create-token-ledger.sh.

## Next Phase Readiness
- Token ledger query interface is complete (TE-06 satisfied)
- Ready for Phase 21 (Codex Task Router) — independent of this phase
- Future enhancement: interactive TUI dashboard (deferred per 20-CONTEXT.md)

---
*Phase: 20-token-report-cli*
*Completed: 2026-04-03*
