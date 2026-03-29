---
phase: 5
plan: 2
subsystem: eval-subsystem
tags: [cortex-review, cortex-status, eval, repair]
requirements: [EVAL-03, EVAL-04]
dependency_graph:
  requires: []
  provides: [eval_plan validation in cortex-review, eval failure repair path, eval_plan blocker in cortex-status]
  affects: [skills/cortex-review/SKILL.md, skills/cortex-status/SKILL.md]
tech_stack:
  added: []
  patterns: [eval_plan field validation, repair-rec artifact generation, blocker surfacing]
key_files:
  created: []
  modified:
    - skills/cortex-review/SKILL.md
    - skills/cortex-status/SKILL.md
decisions:
  - cortex-review Contract Compliance section validates eval_plan field inline (P1 BLOCK for pending/missing)
  - Eval Failure Check section placed before Store Results to allow repair artifacts before final write
  - Phase 3a in cortex-status covers all unresolved eval_plan states (pending, TBD, empty, missing file)
metrics:
  duration: 1min
  completed: "2026-03-29"
  tasks_completed: 2
  files_modified: 2
---

# Phase 5 Plan 2: Contract Eval Validation and Repair-on-Failure Summary

**One-liner:** cortex-review now validates eval_plan field (P1 BLOCK for pending/missing), detects eval-plan.md failures and writes timestamped repair-rec artifacts, opens repair contracts on P0 failures; cortex-status surfaces pending eval_plan as a blocker.

## What Was Built

### Task T1 — cortex-review: eval_plan validation + repair path (commit 94d8f03)

Two additions to `skills/cortex-review/SKILL.md`:

**Contract Compliance — Eval Plan Validation block** (inserted before `CONTRACT COMPLIANCE:` verdict):
- Reads `eval_plan:` field from active contract
- `pending`, `TBD`, or empty → `[BLOCK] contract eval_plan — P1 gap`
- File path that does not exist on disk → `[BLOCK] contract eval_plan path — P1 gap`
- File exists → `[PASS] eval_plan — {path} exists`

**New `### Eval Failure Check` section** (before `## Store Results`):
- Reads `docs/cortex/evals/{slug}/eval-plan.md` Results section
- Detects unchecked `- [ ]` items and explicit `FAIL`/`failed`/`❌` markers
- On failures: writes `repair-rec-{timestamp}.md`, updates `current-state.md` blockers/next_action
- P0 failures additionally: opens new repair contract in `docs/cortex/contracts/{slug}/`, sets `.cortex/state.json` `mode` to `repair`
- Appends `EVAL FAILURE REPAIR` block to review artifact
- On no failures: updates `eval-status.md`, appends `EVAL STATUS: PASS` block

### Task T2 — cortex-status: eval_plan pending detection (commit 0e6963a)

One addition to `skills/cortex-status/SKILL.md`:

**Phase 3a** (inserted after existing Step 3 in `### Phase 3`):
- Reads active contract's `eval_plan:` field
- `pending`, `TBD`, empty, or non-existent file path → records blocker: `eval_plan is pending — run /cortex-research --phase evals and /cortex-research --write-plan`
- Existing file → no blocker recorded
- Existing `{blocker | (none)}` placeholder in Phase 5 output template surfaces it automatically

## Verification Results

| Check | Result |
|-------|--------|
| `eval_plan` occurrences in cortex-review | 4 (>= 1) |
| `repair-rec` in cortex-review | FOUND |
| `eval-plan` in cortex-review | FOUND |
| `eval_plan` occurrences in cortex-status | 4 (>= 1) |

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `skills/cortex-review/SKILL.md` — exists, contains `eval_plan`, `repair-rec`, `eval-plan`
- `skills/cortex-status/SKILL.md` — exists, contains `eval_plan`
- Commit 94d8f03 — T1 cortex-review changes
- Commit 0e6963a — T2 cortex-status changes
