---
phase: 02-artifact-scaffolding-and-templates
plan: 01
subsystem: docs
tags: [cortex, artifact-schema, docs-cortex, directory-structure]

# Dependency graph
requires:
  - phase: 01-core-docs-and-architecture-alignment
    provides: COMMANDS.md, CONTINUITY.md, EVALS.md — the references all READMEs link to
provides:
  - 9 docs/cortex/ subdirectory READMEs with naming patterns, required fields, and creating commands
  - Schema documentation for clarify, research, specs, contracts, evals, investigations, reviews, audits, handoffs
  - eval_plan field documented as mandatory on every contract
  - 6 continuity file schemas documented in handoffs/README.md
affects:
  - 02-02-artifact-templates (reads these READMEs to produce matching template files)
  - 03-new-and-updated-skills (reads these READMEs as the authoritative spec for where each command writes)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "docs/cortex/<subdir>/README.md pattern: naming convention + required fields + creating command"
    - "Handoffs directory is flat (no slug-subdirs) — exception to the slug-subdirectory pattern"

key-files:
  created:
    - docs/cortex/clarify/README.md
    - docs/cortex/research/README.md
    - docs/cortex/specs/README.md
    - docs/cortex/contracts/README.md
    - docs/cortex/evals/README.md
    - docs/cortex/investigations/README.md
    - docs/cortex/reviews/README.md
    - docs/cortex/audits/README.md
    - docs/cortex/handoffs/README.md
  modified: []

key-decisions:
  - "eval_plan field is mandatory on every contract — contracts without it are incomplete and must not be approved"
  - "Handoffs directory is flat (not slug-subdirectories) — 6 named files live directly in docs/cortex/handoffs/"
  - "audits/README.md encodes the not-applicable protocol: silence on a lens is not acceptable"

patterns-established:
  - "Every docs/cortex/<subdir>/README.md answers: (1) naming pattern, (2) required fields/schema, (3) which command creates artifacts"
  - "handoffs/ is the exception to the slug-subdir pattern — files are per-project, not per-slug"

requirements-completed: [ART-01, ART-02, ART-03, ART-04, ART-05, ART-06, ART-07]

# Metrics
duration: 16min
completed: 2026-03-29
---

# Phase 2 Plan 01: Artifact Scaffolding and Templates Summary

**9 docs/cortex/ subdirectory READMEs establishing naming patterns, required fields, and creating commands for all Cortex artifact types**

## Performance

- **Duration:** 16 min
- **Started:** 2026-03-29T02:27:00Z
- **Completed:** 2026-03-29T02:43:19Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Created all 9 `docs/cortex/` subdirectories with schema-documenting READMEs
- Documented the mandatory `eval_plan` field in contracts/README.md with full lifecycle context
- Documented all 6 continuity files in handoffs/README.md with field schemas and recovery protocol
- Established the 7-lens requirement for audits with the explicit not-applicable documentation protocol

## Task Commits

Each task was committed atomically:

1. **Task 1: Create artifact subdirectory READMEs (clarify, research, specs, contracts, evals)** - `3afb249` (feat)
2. **Task 2: Create operational subdirectory READMEs (investigations, reviews, audits, handoffs)** - `bc078a5` (feat)

**Plan metadata:** (final commit below)

## Files Created/Modified

- `docs/cortex/clarify/README.md` - Naming pattern, required fields (goal, non-goals, constraints, assumptions, open questions, next research steps), /cortex-clarify command
- `docs/cortex/research/README.md` - Naming pattern, phase semantics (concept/implementation/evals), required sections, /cortex-research flags
- `docs/cortex/specs/README.md` - Naming pattern, spec.md and gsd-handoff.md required fields, /cortex-spec prerequisites
- `docs/cortex/contracts/README.md` - All required fields including mandatory eval_plan, status values (draft/approved/closed), /cortex-spec and /cortex-investigate creation
- `docs/cortex/evals/README.md` - Proposal/plan lifecycle, 8-dimension candidate matrix, human approval gate requirement
- `docs/cortex/investigations/README.md` - Naming pattern, required sections, repair contract production protocol
- `docs/cortex/reviews/README.md` - Naming pattern, contract compliance section as hard requirement (cannot be omitted)
- `docs/cortex/audits/README.md` - Naming pattern, all 7 required lenses, not-applicable documentation protocol
- `docs/cortex/handoffs/README.md` - Flat directory (not slug-subdirs), all 6 continuity files with schemas, recovery protocol

## Decisions Made

- `eval_plan` field documented as mandatory on contracts — contracts without it are incomplete. This directly supports the eval subsystem enforcement in Phase 5.
- Handoffs directory is flat — 6 named files per project, not per-slug. This matches the CONTINUITY.md design established in Phase 1.
- audits/README.md encodes explicit not-applicable protocol — silence on a lens is not acceptable. This prevents partial audits from passing undetected.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 9 `docs/cortex/` subdirectory READMEs are in place — Phase 3 command implementors can read any README and know exactly where to write and what fields to include
- Phase 2 Plan 02 (artifact templates) can proceed immediately — templates should match the schemas documented in these READMEs
- Blocker: none

---
*Phase: 02-artifact-scaffolding-and-templates*
*Completed: 2026-03-29*
