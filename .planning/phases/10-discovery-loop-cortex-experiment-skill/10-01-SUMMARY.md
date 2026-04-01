---
plan: 10-01
phase: 10 — Discovery Loop — /cortex-experiment Skill
status: complete
completed: 2026-04-01
commits:
  - 3d63e32 — feat(requirements): define DISC-07
  - 30818e7 — feat(skill): add /cortex-experiment skill (DISC-07)
---

# Summary: Plan 10-01

## What Was Done

Two tasks executed, each committed atomically.

### T1: Define DISC-07 in REQUIREMENTS.md

Added DISC-07 to `.planning/REQUIREMENTS.md` under a new "Discovery Loop Skill" subsection within v1.2. Added traceability row (Phase 10, Complete). Updated v1.2 coverage count from 6 to 7.

### T2: Write skills/cortex-experiment/SKILL.md

Created `skills/cortex-experiment/` directory and wrote `SKILL.md` — the 8th Cortex command — with the full `/cortex-experiment open/run/close` lifecycle.

**Open** (8 phases):
- Reads slug from state.json; blocks if null
- WIP limit check: warns loudly if open contract exists (does not block)
- Auto-increments experiment ID from existing contracts (EXP-001, EXP-002, ...)
- Validates Core Hypothesis format, Learning Threshold, and Appetite/Timebox (REQUIRED gate — blocks)
- Writes `learning-contract-{id}.md` to `docs/cortex/experiments/{slug}/`
- Writes `mode: experiment` to state.json, appends artifact path
- Updates current-state.md

**Run** (4 phases):
- Mode guard blocks if not in experiment mode
- Locates open contract; blocks if none found
- Prints active contract summary (ID, hypothesis, threshold, timebox)
- Guidance-only reminder — no state.json changes, no artifact written

**Close** (8 phases):
- Mode guard blocks if not in experiment mode
- Locates open contract; records experiment ID
- Collects all 5 result fields interactively; decision enum validated (promote/iterate/re-clarify/abandon — blocks on invalid value)
- Writes `experiment-result-{id}.md` to `docs/cortex/experiments/{slug}/`
- Updates learning contract: `status: closed` + Results section filled
- Writes `experiment_complete: true` always; transitions `mode` and writes `reclarify_required: true` if decision is `re-clarify`
- Updates current-state.md with decision-driven next_action
- Outputs close summary with decision-specific guidance

## Verification Results

All criteria from the plan pass:

| Check | Result |
|-------|--------|
| `ls skills/cortex-experiment/SKILL.md` | PASS |
| `grep -n "open"` | PASS |
| `grep -n "run"` | PASS |
| `grep -n "close"` | PASS |
| `grep -n "experiment_complete"` | PASS — 4 occurrences |
| `grep -n "promote\|iterate\|re-clarify\|abandon"` | PASS — all 4 outcomes present |
| `grep -n "docs/cortex/experiments"` | PASS — artifact write paths documented |
| `grep -n "DISC-07" .planning/REQUIREMENTS.md` | PASS — 3 occurrences |

## Must-Haves Satisfied

- [x] `skills/cortex-experiment/SKILL.md` exists with open/run/close lifecycle fully documented
- [x] Artifact write paths `docs/cortex/experiments/{slug}/learning-contract-{id}.md` and `docs/cortex/experiments/{slug}/experiment-result-{id}.md` are explicit in the skill
- [x] state.json writes documented: `mode: experiment` (open), `experiment_complete: true` (close), `reclarify_required: true` (close when decision is re-clarify)
- [x] All four decision outcomes (promote/iterate/re-clarify/abandon) documented with their next-mode transitions
- [x] Convergence guardrails enforced: Appetite/Timebox validation at open, decision enum validation at close, WIP limit warning at open
- [x] DISC-07 defined in REQUIREMENTS.md with traceability to Phase 10

## Requirements Satisfied

| Requirement | Status |
|-------------|--------|
| DISC-07 | Complete |

## Decisions Made

None — all design decisions were specified in the plan and DISCOVERY_LOOP.md.

## Next Phase

Phase 11: Discovery Loop — Update Existing Skills and Docs (DISC-08 through DISC-12)
- Update `skills/cortex-research/SKILL.md` — add `reclarify_required: true` signal
- Update `skills/cortex-spec/SKILL.md` — add 3 new spec-readiness blockers
- Update `CORTEX.md` — 8-command surface, include /cortex-experiment
- Update `docs/INTELLIGENCE_FLOW.md` — discovery loop with backtracking paths
- Update `docs/COMMANDS.md` — /cortex-experiment entry
