---
phase: 14-gate-patches
plan: "02"
subsystem: cortex-skills
tags: [autonomy, gate-patches, cortex-spec, cortex-review, conditional-gates]
dependency_graph:
  requires: [scripts/cortex/resolve-autonomy.js, templates/cortex/autonomy.json]
  provides: [skills/cortex-spec/SKILL.md, skills/cortex-review/SKILL.md]
  affects: [AUTON-01, AUTON-02]
tech_stack:
  added: []
  patterns: [gate-wrapper, autonomy-conditional, skip-logging]
key_files:
  created: []
  modified:
    - skills/cortex-spec/SKILL.md
    - skills/cortex-review/SKILL.md
decisions:
  - reclarify gate in cortex-spec is mandatory (always enforced) — annotated explicitly to prevent misconfiguration
  - Skip logging writes to docs/cortex/handoffs/decisions.md with ISO timestamp, gate name, and preset
  - contract_approval auto-approve path sets approval_status=approved (not pending) when gate is disabled
  - compliance_verdict gate still produces the verdict line even when auto-proceeding — for audit trail
metrics:
  duration: "~5 minutes"
  completed: "2026-04-02"
  tasks_completed: 2
  files_modified: 2
---

# Phase 14 Plan 02: cortex-spec and cortex-review Gate Patches Summary

Patched cortex-spec and cortex-review SKILL.md files with conditional autonomy gate wrappers. cortex-spec gets 4 gates (reclarify mandatory + critical_uncertainty, evidence_backing, contract_approval conditional); cortex-review gets 2 gates (eval_validation, compliance_verdict conditional).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Patch cortex-spec with 4 gate wrappers | 41e4d62 | skills/cortex-spec/SKILL.md |
| 2 | Patch cortex-review with 2 gate wrappers | b780a24 | skills/cortex-review/SKILL.md |

## What Was Built

### cortex-spec/SKILL.md (Task 1)

Added an autonomy config resolution block at the top of Phase 1 that instructs the skill to read `.cortex/autonomy.json` and `~/.claude/cortex-autonomy.json`, resolve the active preset, and determine gate values using 4-layer precedence.

Four gate annotations added:

1. **`reclarify` (MANDATORY)** — step 6, annotated as always-enforced regardless of autonomy preset. The block behavior is unchanged.
2. **`critical_uncertainty` (conditional)** — step 7, wrapped with: skip + log to decisions.md if `gates.critical_uncertainty` is false; evaluate as before if true.
3. **`evidence_backing` (conditional)** — step 8, wrapped with: skip + log to decisions.md if `gates.evidence_backing` is false; evaluate as before if true.
4. **`contract_approval` (conditional)** — Phase 5, wrapped with: auto-approve (set approval_status=approved) + log if gate is false; set to pending (existing behavior) if gate is true.

The Rules section was updated to reflect that the hard gate is conditional on the `contract_approval` gate being active.

### cortex-review/SKILL.md (Task 2)

Added an autonomy config resolution block at the top of the Contract Compliance section.

Two gate annotations added:

1. **`eval_validation` (conditional)** — eval plan validation block wrapped with: skip + produce [NOTE] + log to decisions.md if gate is false; evaluate as before if true (BLOCK messages preserved for gate-active path).
2. **`compliance_verdict` (conditional)** — compliance verdict wrapped with: auto-proceed (still produce verdict line, but don't block pipeline) + log if gate is false; full enforcement (existing behavior) if gate is true.

All other sections (Phase 0, Engineering Lens, Security Lens, YAGNI Lens, Output Format, Handling Pushback, Eval Failure Check, Store Results) are unchanged.

## Verification Results

| Check | Result |
|-------|--------|
| cortex-spec gate count (`Gate:`) | 4 |
| cortex-review gate count (`Gate:`) | 2 |
| cortex-spec decisions.md references | 3 |
| cortex-review decisions.md references | 2 |
| Both files have autonomy references | PASS |
| reclarify_required: true still present | PASS |
| BLOCKED: messages preserved (cortex-spec) | 3 |
| CONTRACT COMPLIANCE: preserved (cortex-review) | PASS |
| Anti-Sycophancy section unchanged | PASS |
| Engineering Lens unchanged | PASS |
| Eval Failure Check unchanged | PASS |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. Both patched files contain complete conditional logic with no placeholder text or deferred implementation.

## Self-Check: PASSED

- `skills/cortex-spec/SKILL.md` — exists and contains 4 gate annotations
- `skills/cortex-review/SKILL.md` — exists and contains 2 gate annotations
- Commit `41e4d62` — verified in git log
- Commit `b780a24` — verified in git log
