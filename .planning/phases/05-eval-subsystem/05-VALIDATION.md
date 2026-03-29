---
phase: 5
slug: eval-subsystem
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-29
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | File existence + grep assertions (skill files are markdown — no test runner needed) |
| **Config file** | none |
| **Quick run command** | `grep -c "Functional correctness" skills/cortex-research/SKILL.md` |
| **Estimated runtime** | ~3 seconds |

---

## Sampling Rate

- **After every task commit:** grep assertions for that task's modified skill file
- **After each plan wave:** Run all automated commands for completed tasks
- **Before `/gsd:verify-work`:** All phase gate checks must pass

---

## Per-Task Verification Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? | Status |
|--------|----------|-----------|-------------------|-------------|--------|
| EVAL-01 | cortex-research SKILL.md enumerates all 8 dimensions in `--phase evals` section | grep | `grep -cE "Functional correctness\|Regression\|Integration\|Safety\|Performance\|Resilience\|Style\|UX" skills/cortex-research/SKILL.md` (expect >= 8) | ❌ Wave 0 | pending |
| EVAL-02 | cortex-research SKILL.md contains BLOCKED output for unapproved proposals | grep | `grep -l "BLOCKED" skills/cortex-research/SKILL.md` | ❌ Wave 0 | pending |
| EVAL-02 | cortex-research SKILL.md reads Approval Status before writing eval-plan | grep | `grep -c "Approval Status" skills/cortex-research/SKILL.md` (expect >= 2) | ❌ Wave 0 | pending |
| EVAL-03 | cortex-review SKILL.md checks eval_plan field for "pending" or missing | grep | `grep -c "eval_plan" skills/cortex-review/SKILL.md` (expect >= 1) | ❌ Wave 0 | pending |
| EVAL-03 | cortex-status SKILL.md flags pending eval_plan as blocker | grep | `grep -c "eval_plan" skills/cortex-status/SKILL.md` (expect >= 1) | ❌ Wave 0 | pending |
| EVAL-04 | cortex-review SKILL.md defines repair-rec artifact path | grep | `grep -l "repair-rec" skills/cortex-review/SKILL.md` | ❌ Wave 0 | pending |
| EVAL-04 | cortex-review SKILL.md reads eval-plan.md Results section | grep | `grep -l "eval-plan" skills/cortex-review/SKILL.md` | ❌ Wave 0 | pending |
| EVAL-05 | eval-proposal.md template contains all 8 dimension names | grep | `grep -cE "Functional correctness\|Regression\|Integration\|Safety\|Performance\|Resilience\|Style\|UX" templates/cortex/eval-proposal.md` (expect >= 8) | ✅ exists | pre-pass |

---

## Wave 0 Gaps

The following currently fail (pre-Phase 5 state):
- EVAL-01: `skills/cortex-research/SKILL.md` does not enumerate 8 dimensions explicitly in `--phase evals` branch
- EVAL-02: No "BLOCKED" output or "Approval Status" gating in `skills/cortex-research/SKILL.md`
- EVAL-03: `skills/cortex-review/SKILL.md` and `skills/cortex-status/SKILL.md` have no `eval_plan` checks
- EVAL-04: `skills/cortex-review/SKILL.md` has no `repair-rec` artifact or Results parsing step

Pre-passing (already satisfied):
- EVAL-05: `templates/cortex/eval-proposal.md` already lists all 8 dimensions

---

## Phase Gate

All of the following must be true before phase is considered complete:

- [ ] `grep -cE "Functional correctness|Regression|Integration|Safety|Performance|Resilience|Style|UX" skills/cortex-research/SKILL.md` ≥ 8 — all 8 eval dimensions enumerated
- [ ] `grep -l "BLOCKED" skills/cortex-research/SKILL.md` — approval gate outputs BLOCKED
- [ ] `grep -c "Approval Status" skills/cortex-research/SKILL.md` ≥ 2 — reads approval status
- [ ] `grep -c "eval_plan" skills/cortex-review/SKILL.md` ≥ 1 — contract eval_plan checked
- [ ] `grep -c "eval_plan" skills/cortex-status/SKILL.md` ≥ 1 — pending eval flagged in status
- [ ] `grep -l "repair-rec" skills/cortex-review/SKILL.md` — repair recommendation path defined
- [ ] `grep -l "eval-plan" skills/cortex-review/SKILL.md` — eval-plan Results section read
- [ ] `grep -cE "Functional correctness|Regression|Integration|Safety|Performance|Resilience|Style|UX" templates/cortex/eval-proposal.md` ≥ 8 — (pre-passing)
