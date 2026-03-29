---
phase: 3
slug: new-and-updated-skills
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-29
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — SKILL.md files only (prompt instructions, no runnable code) |
| **Config file** | N/A |
| **Quick run command** | `ls skills/cortex-clarify/SKILL.md skills/cortex-spec/SKILL.md` |
| **Full suite command** | See per-task verification map below |
| **Estimated runtime** | ~5 seconds (grep/test only) |

---

## Sampling Rate

- **After every task commit:** File-existence + content-grep for that task's output
- **After all skills written:** Run full grep suite across all 7 SKILL.md files
- **Before `/gsd:verify-work`:** All checks in phase gate must pass
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| T1 | 03-01 | 1 | CMD-01 | automated | `test -f skills/cortex-clarify/SKILL.md && grep -c "clarify-brief" skills/cortex-clarify/SKILL.md` (expect ≥1) | ❌ | pending |
| T2 | 03-01 | 1 | CMD-02 | automated | `grep -cE "\-\-phase concept\|\-\-phase implementation\|\-\-phase evals" skills/cortex-research/SKILL.md` (expect ≥3) | ❌ | pending |
| T1 | 03-02 | 1 | CMD-03 | automated | `test -f skills/cortex-spec/SKILL.md && grep -c "gsd-handoff" skills/cortex-spec/SKILL.md` (expect ≥1) | ❌ | pending |
| T2 | 03-02 | 1 | CMD-07 | automated | `grep -c "current-state.md" skills/cortex-status/SKILL.md && grep -c "state.json" skills/cortex-status/SKILL.md` (each expect ≥1) | ❌ | pending |
| T1 | 03-03 | 1 | CMD-04 | automated | `grep -c "docs/cortex/investigations" skills/cortex-investigate/SKILL.md` (expect ≥1) | ❌ | pending |
| T2 | 03-03 | 1 | CMD-05,CMD-06 | automated | `grep -c "docs/cortex/reviews" skills/cortex-review/SKILL.md && grep -c "docs/cortex/audits" skills/cortex-audit/SKILL.md` (each expect ≥1) | ❌ | pending |

---

## Wave 0 Gaps

None — SKILL.md files are pure markdown prompt instructions. No test infrastructure needed. All validation is content-grep on the output files.

---

## Phase Gate

All of the following must be true before phase is considered complete:

- [ ] `test -f skills/cortex-clarify/SKILL.md` → exists
- [ ] `grep -c "clarify-brief" skills/cortex-clarify/SKILL.md` → ≥ 1
- [ ] `grep -cE -- "--phase concept|--phase implementation|--phase evals" skills/cortex-research/SKILL.md` → ≥ 3
- [ ] `grep -c "docs/cortex/research" skills/cortex-research/SKILL.md` → ≥ 1
- [ ] `test -f skills/cortex-spec/SKILL.md` → exists
- [ ] `grep -c "gsd-handoff" skills/cortex-spec/SKILL.md` → ≥ 1
- [ ] `grep -c "contract" skills/cortex-spec/SKILL.md` → ≥ 1
- [ ] `grep -c "docs/cortex/investigations" skills/cortex-investigate/SKILL.md` → ≥ 1
- [ ] `grep -c "docs/cortex/reviews" skills/cortex-review/SKILL.md` → ≥ 1
- [ ] `grep -c "docs/cortex/audits" skills/cortex-audit/SKILL.md` → ≥ 1
- [ ] `grep -c "current-state.md" skills/cortex-status/SKILL.md` → ≥ 1
- [ ] `grep -c "state.json" skills/cortex-status/SKILL.md` → ≥ 1
