---
phase: 11-discovery-loop-update-existing-skills-and-docs
plan: 01
subsystem: skills
tags: [cortex-research, cortex-spec, discovery-loop, spec-readiness-gate, reclarify]

# Dependency graph
requires:
  - phase: 10-discovery-loop-cortex-experiment-skill
    provides: cortex-experiment SKILL.md with open/run/close lifecycle; DISC-07 satisfied
provides:
  - reclarify_required write + WARNING block in cortex-research/SKILL.md
  - three spec-readiness blockers (items 6, 7, 8) in cortex-spec/SKILL.md Phase 1
affects: [cortex-research, cortex-spec, INTELLIGENCE_FLOW.md, COMMANDS.md, CORTEX.md]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Conditional state.json write with visible warning block for backtrack detection
    - Numbered prerequisite items (6/7/8) as extension pattern for Phase 1 gatekeeping

key-files:
  created: []
  modified:
    - skills/cortex-research/SKILL.md
    - skills/cortex-spec/SKILL.md

key-decisions:
  - "reclarify_required row added to state.json table in Phase 4 of cortex-research — conditional write, not unconditional"
  - "Three spec-readiness blockers appended as items 6/7/8 — all edits additive, no existing items removed"
  - "Backward-compat default documented inline in item 7: flat open-questions.md entries treated as severity: noncritical"

patterns-established:
  - "Conditional state field: write only when condition is true; omit otherwise"
  - "Spec gate enforcement: numbered prerequisite checks in Phase 1, before Phase 2 heading"

requirements-completed: [DISC-08, DISC-09]

# Metrics
duration: ~10min
completed: 2026-04-01
---

# Phase 11-01: Discovery Loop — Skill Updates Summary

**reclarify_required backtrack write and three spec-readiness gate blockers added to cortex-research and cortex-spec SKILL.md files**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-01T19:30:00Z
- **Completed:** 2026-04-01T19:40:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- `skills/cortex-research/SKILL.md`: Phase 4 state.json table now includes a conditional `reclarify_required: true` row; a **Conditional: reclarify_required** block immediately after the table specifies when to write it and emits the `⚠ RECLARIFY REQUIRED` warning block (DISC-08)
- `skills/cortex-spec/SKILL.md`: Phase 1 now has items 6, 7, and 8 — three spec-readiness blockers matching DISCOVERY_LOOP.md §4 verbatim: reclarify_required gate, critical open uncertainties gate, unbacked core assumptions gate (DISC-09)
- No existing content removed from either file — all edits are purely additive

## Task Commits

1. **Task 1: Add reclarify_required write and warning to cortex-research/SKILL.md** - `6b39d10` (feat)
2. **Task 2: Add three spec-readiness blockers to cortex-spec/SKILL.md Phase 1** - `a3d002d` (feat)

## Files Created/Modified
- `skills/cortex-research/SKILL.md` — Added conditional `reclarify_required` state.json row and `⚠ RECLARIFY REQUIRED` warning block after Phase 4 table
- `skills/cortex-spec/SKILL.md` — Added prerequisite checks 6, 7, 8 (spec-readiness blockers) after item 5, before Phase 2 heading

## Decisions Made
- None — plan executed exactly as written; block messages taken verbatim from DISCOVERY_LOOP.md §4

## Deviations from Plan
None — plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- DISC-08 and DISC-09 satisfied
- Plan 11-01 complete; remaining Phase 11 plans cover DISC-10 (CORTEX.md), DISC-11 (INTELLIGENCE_FLOW.md), DISC-12 (COMMANDS.md)

---
*Phase: 11-discovery-loop-update-existing-skills-and-docs*
*Completed: 2026-04-01*
