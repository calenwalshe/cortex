---
phase: 21-codex-task-router
plan: "01"
subsystem: tooling
tags: [codex, task-routing, classification, decision-tree, cli]

requires:
  - phase: none
    provides: standalone utility
provides:
  - "9-rule static task classifier (codex-safe vs claude-required)"
  - "JSON array output for machine consumption by Phase 23 codex-exec-wrapper"
affects: [23-codex-exec-wrapper, codex-handoff-pipeline]

tech-stack:
  added: []
  patterns: [first-match decision tree, regex-based XML parsing, zero-dep Node CLI]

key-files:
  created:
    - scripts/cortex/task-router.js
    - test/task-router.test.sh
  modified: []

key-decisions:
  - "Regex-based XML parsing (not a full XML parser) — sufficient for well-structured GSD task XML"
  - "Conservative fallback: unmatched tasks default to claude-required (Rule 10)"
  - "Older PLAN.md formats (different XML tags) gracefully degrade to claude-required via fallback rules"

patterns-established:
  - "9-rule first-match decision tree: plan-level override, type checks, pattern matching, structural checks, fallback"
  - "Dual-output pattern: JSON to stdout (machine), traceability log to stderr (human)"

requirements-completed: [TE-07]

duration: 3min
completed: 2026-04-03
---

# Phase 21 Plan 01: Codex Task Router Summary

**9-rule static decision tree classifier that partitions PLAN.md tasks into codex-safe vs claude-required, outputting JSON for the Codex execution wrapper**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-03T03:40:19Z
- **Completed:** 2026-04-03T03:43:42Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Built task-router.js with 9-rule first-match decision tree covering autonomous override, checkpoint types, auth/deploy patterns, file count, subjective criteria, architectural patterns, TDD, verify presence, and conservative fallback
- 30 passing tests: 24 synthetic fixture tests (one per rule + edge cases) + 4 real PLAN.md integration tests + 2 script convention checks
- Validated against real plans: 20-01-PLAN.md (3 codex-safe tasks) and 08-01-PLAN.md (older format gracefully classified as claude-required)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create task-router.js with 9-rule decision tree** - `76991b7` (test + feat, TDD)
2. **Task 2: Validate router against real PLAN.md files** - `5e7e807` (feat)

## Files Created/Modified

- `scripts/cortex/task-router.js` - 9-rule static decision tree classifier, reads PLAN.md, outputs JSON array to stdout
- `test/task-router.test.sh` - 30 integration tests covering all rules, edge cases, real plans, and conventions

## Decisions Made

- Used regex-based XML parsing instead of a full XML parser -- GSD task XML is well-structured and predictable, a parser would add unnecessary complexity
- Conservative fallback (Rule 10): any unmatched task defaults to claude-required -- safety over throughput
- Older PLAN.md formats (e.g., `<objective>` instead of `<name>`) gracefully fall to fallback rules rather than erroring

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- task-router.js is ready for consumption by Phase 23 codex-exec-wrapper
- JSON output format is stable and documented in the plan interfaces section
- Real-plan validation confirms the router works on actual GSD plans from this project

---
*Phase: 21-codex-task-router*
*Completed: 2026-04-03*
