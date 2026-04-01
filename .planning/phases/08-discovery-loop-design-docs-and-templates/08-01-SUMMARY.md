---
phase: 08-discovery-loop-design-docs-and-templates
plan: "08-01"
subsystem: docs
tags: [discovery-loop, experiment, learning-contract, experiment-result, uncertainty-register]

# Dependency graph
requires:
  - phase: 07-idea-stash
    provides: Phase 7 complete; cortex-stash skill, template, and worked example delivered

provides:
  - docs/DISCOVERY_LOOP.md — 6-section authoritative design reference for the discovery loop
  - templates/cortex/learning-contract.md — 12-field pre-experiment planning template
  - templates/cortex/experiment-result.md — 8-field close artifact template

affects:
  - 08-02 and later plans that implement phase guard patches, scaffold patches, cortex-experiment skill, cortex-spec/research updates, CORTEX.md/COMMANDS.md/INTELLIGENCE_FLOW.md updates

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Discovery loop modeled as hypothesis iteration (HDD + Lean Startup + Shape Up)
    - Backward-compat defaults for flat uncertainty register entries
    - Conditional experiment_complete gate (only checked when uncertainty register requires it)

key-files:
  created:
    - docs/DISCOVERY_LOOP.md
    - templates/cortex/learning-contract.md
    - templates/cortex/experiment-result.md
  modified: []

key-decisions:
  - "experiment_complete gate is conditional — only applies when critical uncertainties have resolution_path: experiment; research-only slugs are unaffected"
  - "Backward-compatibility for flat open-questions.md entries: structured fields are additive with documented defaults"
  - "Appetite/Timebox is REQUIRED in learning-contract — a contract without it is incomplete by definition"
  - "Decision outcomes are an exhaustive enum: promote | iterate | re-clarify | abandon — no other values valid"

patterns-established:
  - "Pre-experiment and post-experiment portions of learning-contract are visually distinct (separated by horizontal rule and Results heading)"
  - "experiment-result is a minimal close artifact — not a planning doc; 8 fields only"
  - "All uncertainty register field defaults documented inline so backward compat is explicit, not implicit"

requirements-completed: [DISC-01, DISC-02, DISC-03]

# Metrics
duration: ~10min
completed: 2026-04-01
---

# Plan 08-01: Discovery Loop Design Doc and Two Artifact Templates

**Authoritative design reference (DISCOVERY_LOOP.md) and two artifact templates (learning-contract, experiment-result) written — all DISC requirements satisfied, all validators passing**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-04-01
- **Completed:** 2026-04-01
- **Tasks:** 3
- **Files modified:** 3 created

## Accomplishments

- `docs/DISCOVERY_LOOP.md` written with all 6 required sections: mode transitions (8 modes, all trigger/state-field pairs), artifact schemas (learning-contract and experiment-result with file paths and lifecycle events), uncertainty register schema (5 fields with backward-compat defaults), spec-readiness gate (3 blockers plus conditional experiment_complete gate with state.json extensions), write-root policy (experiment mode permitted roots, product-path guard preserved), convergence guardrails (6 guardrails from HDD/Lean Startup/Shape Up synthesis)
- `templates/cortex/learning-contract.md` written with YAML front matter (id, status, owner, slug, created), 10 pre-experiment body sections, Appetite/Timebox marked REQUIRED, and a visually distinct Results section with 5 post-experiment fields including Decision with all four valid values in an inline comment
- `templates/cortex/experiment-result.md` written as a minimal 8-field close artifact with Linked Contract field, Decision with inline comment, and usage note that it is written by `/cortex-experiment close`

## Task Commits

Each task was committed atomically:

1. **Task 08-01-01: docs/DISCOVERY_LOOP.md** - `807b62d` (docs)
2. **Task 08-01-02: templates/cortex/learning-contract.md** - `318eb5c` (feat)
3. **Task 08-01-03: templates/cortex/experiment-result.md** - `80642ad` (feat)

## Files Created/Modified

- `docs/DISCOVERY_LOOP.md` — 6-section design reference; all subsequent implementation phases reference this
- `templates/cortex/learning-contract.md` — pre-experiment planning artifact; 12 fields total (5 YAML front matter + 10 body + 5 post-experiment Results block, with Timebox as REQUIRED)
- `templates/cortex/experiment-result.md` — close artifact; 8 fields including Linked Contract back-pointer and Decision enum comment

## Decisions Made

- `experiment_complete` gate is conditional: only checked by `/cortex-spec` when the uncertainty register has a critical entry with `resolution_path: experiment`. Research-only slugs are unaffected.
- Backward-compatibility for flat `open-questions.md` entries is explicit — defaults documented inline, not implicit.
- `Appetite / Timebox` is REQUIRED in learning-contract — marked both in body section heading and in an introductory note at the top of the template.
- Decision outcomes are an exhaustive enum (`promote | iterate | re-clarify | abandon`), documented in both templates with an HTML comment on the Decision field.

## Deviations from Plan

None — plan executed exactly as written. All 14 verification criteria pass.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

All three DISC deliverables are in place. Subsequent tasks in Phase 8 (phase guard patch, scaffold patch, cortex-experiment SKILL.md, cortex-spec/research updates, CORTEX.md/COMMANDS.md/INTELLIGENCE_FLOW.md updates) can proceed — they all reference `docs/DISCOVERY_LOOP.md` as the authoritative source.

---
*Phase: 08-discovery-loop-design-docs-and-templates*
*Completed: 2026-04-01*
