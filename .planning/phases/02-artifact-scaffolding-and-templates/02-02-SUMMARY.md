---
phase: 02-artifact-scaffolding-and-templates
plan: "02"
subsystem: templates
tags: [cortex, templates, artifacts, markdown, schema]

# Dependency graph
requires:
  - phase: 01-core-docs-and-architecture-alignment
    provides: COMMANDS.md and EVALS.md defining artifact schemas and eval lifecycle
provides:
  - 7 markdown template files in templates/cortex/ covering ART-01 through ART-07
  - eval_plan field schema in contract.md (mandatory per EVALS.md)
  - 9-section spec schema (PROBLEM through ACCEPTANCE_CRITERIA)
  - approval_required gate in eval-proposal.md matching EVALS.md logic
affects:
  - 03-command-scaffolding (Phase 3 commands copy these templates when writing artifacts)
  - 05-evals-subsystem (eval-proposal and eval-plan templates are the eval schema)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "{FIELD_NAME} placeholder convention for all template fields (upper-snake-case)"
    - "Inline <!-- comment --> per field explaining purpose and valid values"
    - "Checkbox format (- [ ]) for actionable criteria and results"

key-files:
  created:
    - templates/cortex/clarify-brief.md
    - templates/cortex/research-dossier.md
    - templates/cortex/spec.md
    - templates/cortex/gsd-handoff.md
    - templates/cortex/contract.md
    - templates/cortex/eval-proposal.md
    - templates/cortex/eval-plan.md
  modified: []

key-decisions:
  - "contract.md eval_plan field marked Required with comment — contracts without it are incomplete per EVALS.md"
  - "spec.md has all 9 mandatory sections — omitting any section is an error by design"
  - "gsd-handoff.md includes CONTRACT_LINK field — executor must check contract before starting"
  - "eval-proposal.md APPROVAL_REQUIRED is document-level flag, not per-dimension — simplifies human approval flow"
  - "RESULTS section in eval-plan.md ships with all checkboxes unchecked — populated after execution"

patterns-established:
  - "Template field convention: {FIELD_NAME} placeholders with inline <!-- comment --> per field"
  - "All status fields use consistent enum pattern: draft | approved | [state3]"
  - "Criteria and tasks always use checkbox format (- [ ]) for traceability"

requirements-completed: [ART-01, ART-02, ART-03, ART-04, ART-05, ART-06, ART-07]

# Metrics
duration: 3min
completed: "2026-03-29"
---

# Phase 02 Plan 02: Artifact Scaffolding and Templates Summary

**7 Markdown artifact schema templates in `templates/cortex/` covering the full Cortex artifact lifecycle from clarify brief through eval plan, with `{FIELD_NAME}` placeholder convention and inline field documentation.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-03-29T02:40:17Z
- **Completed:** 2026-03-29T02:42:31Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Created 4 primary artifact templates (ART-01 through ART-04): clarify-brief, research-dossier, spec, gsd-handoff
- Created 3 contract and eval templates (ART-05 through ART-07): contract, eval-proposal, eval-plan
- contract.md includes `eval_plan` field with "Required. Contract is incomplete without this field." comment, satisfying EVALS.md hard requirement
- spec.md has all 9 mandatory sections (PROBLEM through ACCEPTANCE_CRITERIA) — omitting any is an error
- gsd-handoff.md includes CONTRACT_LINK field enforcing executor reads contract before starting
- eval-proposal.md includes FAILURE_TAXONOMY section with P0/P1/P2/P3 severity structure and document-level APPROVAL_REQUIRED flag

## Task Commits

1. **Task 1: Create primary artifact templates (clarify-brief, research-dossier, spec, gsd-handoff)** - `d37f97b` (feat)
2. **Task 2: Create contract and eval templates (contract, eval-proposal, eval-plan)** - `c971188` (feat)

## Files Created/Modified

- `templates/cortex/clarify-brief.md` - ART-01 template with SLUG, GOAL, NON_GOALS, CONSTRAINTS, ASSUMPTIONS, OPEN_QUESTIONS, NEXT_RESEARCH_STEPS
- `templates/cortex/research-dossier.md` - ART-02 template with PHASE, DEPTH, SUMMARY, FINDINGS, TRADE_OFFS, RECOMMENDATIONS, OPEN_QUESTIONS, SOURCES
- `templates/cortex/spec.md` - ART-03 template with all 9 required sections
- `templates/cortex/gsd-handoff.md` - ART-04 GSD-ready work order with CONTRACT_LINK field
- `templates/cortex/contract.md` - ART-05 template with eval_plan as mandatory field (Required comment)
- `templates/cortex/eval-proposal.md` - ART-06 template with 8-dimension matrix, FAILURE_TAXONOMY, approval_required flag
- `templates/cortex/eval-plan.md` - ART-07 template with APPROVED_DIMENSIONS, thresholds, RUN_INSTRUCTIONS, RESULTS

## Decisions Made

- contract.md `eval_plan` field explicitly marked Required with inline comment — making it structurally impossible to miss
- spec.md 9-section structure is rigid by design (comment: "omitting any section is an error") — prevents incomplete specs
- eval-proposal.md uses a document-level `approval_required` flag rather than per-dimension flag — simpler human review flow
- RESULTS section in eval-plan.md ships empty (all unchecked) so it can be populated in place after execution

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 7 artifact schema templates ready for use by Phase 3 command scaffolding
- Phase 3 commands will copy these templates when writing artifacts to `docs/cortex/`
- Templates define the schema source of truth for all artifact types ART-01 through ART-07

---
*Phase: 02-artifact-scaffolding-and-templates*
*Completed: 2026-03-29*
