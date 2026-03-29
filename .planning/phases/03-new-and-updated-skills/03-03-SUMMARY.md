---
phase: 03-new-and-updated-skills
plan: "03"
subsystem: skills
tags: [cortex-investigate, cortex-review, cortex-audit, artifact-writing, contract-compliance, slug-resolution]

# Dependency graph
requires:
  - phase: 02-artifact-scaffolding-and-templates
    provides: docs/cortex/ directory structure, current-state.md template, state.json schema, contract.md template
provides:
  - "cortex-investigate writes investigation artifact to docs/cortex/investigations/<slug>/<timestamp>.md"
  - "cortex-investigate optionally writes repair contract to docs/cortex/contracts/<slug>/contract-NNN.md"
  - "cortex-review writes review artifact to docs/cortex/reviews/<slug>/<timestamp>.md with contract compliance section"
  - "cortex-audit writes security posture report to docs/cortex/audits/<slug>/<timestamp>.md"
  - "All three skills update current-state.md and state.json after writing artifacts"
  - "All three skills resolve slug from state.json or argument slugification"
affects: [04-cortex-status-and-handoff, any phase invoking post-execution skill commands]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Slug resolution: state.json first, then argument slugification (lowercase+hyphens), fallback to block or 'unknown'"
    - "Artifact write pattern: mkdir -p, write full report, update current-state.md, update state.json artifacts array"
    - "Contract compliance: PASS/FAIL/PARTIAL per done_criteria, COMPLIANT/NON-COMPLIANT/PARTIALLY COMPLIANT overall verdict"
    - "7-lens verification: silence on any lens is not acceptable — explicit no-issues note required"

key-files:
  created: []
  modified:
    - "skills/cortex-investigate/SKILL.md"
    - "skills/cortex-review/SKILL.md"
    - "skills/cortex-audit/SKILL.md"

key-decisions:
  - "Store Results section added as terminal section after all existing protocol content — no existing content trimmed or rephrased"
  - "cortex-investigate blocks on null-slug with no argument; cortex-review and cortex-audit fall back to 'unknown' slug"
  - "cortex-review Contract Compliance is required in every review — cannot be omitted"
  - "cortex-audit 7-lens verification enforced before write — silence on any lens requires explicit no-issues note"
  - "Repair contract in cortex-investigate is optional (only for DONE_WITH_CONCERNS/BLOCKED status)"
  - "GSD prohibition note explicit: human imports repair contract — command does not call GSD"

patterns-established:
  - "Phase 0 / Phase -1 prepended to all post-execution skills for slug resolution before protocol execution"
  - "All post-execution commands terminate with artifact write + current-state.md update + state.json update + confirmation line"

requirements-completed: [CMD-04, CMD-05, CMD-06]

# Metrics
duration: 18min
completed: 2026-03-28
---

# Phase 03 Plan 03: New and Updated Skills (Artifact Writing) Summary

**All three post-execution skills (investigate, review, audit) extended with repo-local artifact writing, slug resolution, and state update — existing protocols 100% preserved.**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-03-28T~T14:30Z
- **Completed:** 2026-03-28
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- cortex-investigate gains Phase 0 slug resolution, Store Results section with investigation artifact write and optional repair contract, current-state.md and state.json updates
- cortex-review gains Phase 0 slug/contract loading, new Contract Compliance section (PASS/FAIL/PARTIAL per criterion, COMPLIANT/NON-COMPLIANT overall verdict), Store Results section with artifact write
- cortex-audit gains Phase -1 slug resolution, Store Results section with mandatory 7-lens verification (no-silence rule), artifact write, current-state.md and state.json updates

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend cortex-investigate with artifact writing** - `c232722` (feat)
2. **Task 2: Extend cortex-review with artifact writing and contract compliance** - `6f8c704` (feat)
3. **Task 3: Extend cortex-audit with artifact writing** - `f0670a0` (feat)

**Plan metadata:** (see final commit below)

## Files Created/Modified
- `skills/cortex-investigate/SKILL.md` - Added Phase 0 slug resolution, Store Results section (investigation artifact + optional repair contract + current-state.md + state.json updates)
- `skills/cortex-review/SKILL.md` - Added Phase 0 slug/contract loading, Contract Compliance section, Store Results section, chat-only prohibition note
- `skills/cortex-audit/SKILL.md` - Added Phase -1 slug resolution, Store Results section with 7-lens verification and no-silence rule

## Decisions Made
- cortex-investigate blocks on null-slug/no-argument (hard gate); cortex-review and cortex-audit fall back to "unknown" slug to avoid blocking a running review/audit
- Contract Compliance section in cortex-review is mandatory — cannot be omitted (per COMMANDS.md)
- 7-lens verification in cortex-audit enforced at write time, not just during audit phases
- Repair contract in cortex-investigate is optional, gated on DONE_WITH_CONCERNS or BLOCKED status
- No changes to Mode field on any current-state.md update — post-execution tools leave mode as-is per plan interface note

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

All three post-execution skill files now satisfy vNext artifact-writing requirements. Phase 03 plan 04 (if any) or Phase 04 can proceed. The docs/cortex/ directory structure required by these skills was scaffolded in Phase 02.

## Self-Check: PASSED

- FOUND: skills/cortex-investigate/SKILL.md
- FOUND: skills/cortex-review/SKILL.md
- FOUND: skills/cortex-audit/SKILL.md
- FOUND: .planning/phases/03-new-and-updated-skills/03-03-SUMMARY.md
- FOUND commit: c232722 (cortex-investigate artifact writing)
- FOUND commit: 6f8c704 (cortex-review artifact writing + contract compliance)
- FOUND commit: f0670a0 (cortex-audit artifact writing + 7-lens verification)

---
*Phase: 03-new-and-updated-skills*
*Completed: 2026-03-28*
