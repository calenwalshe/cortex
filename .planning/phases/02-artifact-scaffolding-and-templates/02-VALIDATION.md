---
phase: 2
slug: artifact-scaffolding-and-templates
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-29
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash + manual schema inspection |
| **Config file** | none |
| **Quick run command** | `bash -n scripts/cortex/scaffold_runtime.sh` |
| **Full suite command** | `bash scripts/cortex/scaffold_runtime.sh /tmp/cortex-test && ls /tmp/cortex-test/docs/cortex/ && ls /tmp/cortex-test/.cortex/` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run file-existence check for that task's output files
- **After Wave 1:** Run template content checks (grep for required fields in each template)
- **After Wave 2:** Run scaffold_runtime.sh dry-run + state.json schema check
- **Before `/gsd:verify-work`:** Full suite must pass
- **Max feedback latency:** ~5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| T1 | 02-01 | 1 | ART-01–04 | automated | `ls docs/cortex/clarify/ docs/cortex/research/ docs/cortex/specs/ docs/cortex/contracts/` (all must exist) | ❌ | pending |
| T2 | 02-01 | 1 | ART-05–08 | automated | `ls docs/cortex/evals/ docs/cortex/investigations/ docs/cortex/reviews/ docs/cortex/audits/ docs/cortex/handoffs/` | ❌ | pending |
| T1 | 02-02 | 1 | ART-01–04 | automated | `cat templates/cortex/clarify-brief.md templates/cortex/research-dossier.md templates/cortex/spec.md templates/cortex/gsd-handoff.md` (all must exist) | ❌ | pending |
| T2 | 02-02 | 1 | ART-05–07 | automated | `grep -l "eval_plan" templates/cortex/contract.md && grep -l "approval_required" templates/cortex/eval-proposal.md && test -f templates/cortex/eval-plan.md` | ❌ | pending |
| T1 | 02-03 | 1 | ART-08 | automated | `ls docs/cortex/handoffs/current-state.md docs/cortex/handoffs/open-questions.md docs/cortex/handoffs/next-prompt.md docs/cortex/handoffs/decisions.md docs/cortex/handoffs/eval-status.md docs/cortex/handoffs/last-compact-summary.md` | ❌ | pending |
| T2 | 02-03 | 1 | CONT-04 | automated | `python3 -c "import json,sys; d=json.load(open('.cortex/state.json')); assert 'mode' in d and 'slug' in d and 'approved' in d; print('state.json schema OK')"` | ❌ | pending |
| T1 | 02-04 | 2 | ART-01–08,CONT-04 | automated | `bash -n scripts/cortex/scaffold_runtime.sh && echo "syntax OK"` | ❌ | pending |
| T2 | 02-04 | 2 | ART-01–08,CONT-04 | automated | `bash scripts/cortex/scaffold_runtime.sh /tmp/cortex-test && ls /tmp/cortex-test/docs/cortex/ && ls /tmp/cortex-test/.cortex/ && echo "scaffold OK"` | ❌ | pending |

---

## Wave 0 Gaps

None — this phase requires no test infrastructure setup. All validation is file inspection and bash syntax checking. No pre-existing infrastructure needed.

---

## Phase Gate

All of the following must be true before phase is considered complete:

- [ ] `ls docs/cortex/clarify/ docs/cortex/research/ docs/cortex/specs/ docs/cortex/contracts/ docs/cortex/evals/ docs/cortex/investigations/ docs/cortex/reviews/ docs/cortex/audits/ docs/cortex/handoffs/` — all exist
- [ ] `ls templates/cortex/clarify-brief.md templates/cortex/research-dossier.md templates/cortex/spec.md templates/cortex/gsd-handoff.md templates/cortex/contract.md templates/cortex/eval-proposal.md templates/cortex/eval-plan.md` — all exist
- [ ] `grep eval_plan templates/cortex/contract.md` — match found
- [ ] `grep approval_required templates/cortex/eval-proposal.md` — match found
- [ ] `ls docs/cortex/handoffs/current-state.md docs/cortex/handoffs/next-prompt.md docs/cortex/handoffs/decisions.md docs/cortex/handoffs/eval-status.md docs/cortex/handoffs/last-compact-summary.md` — all exist
- [ ] `python3 -c "import json; d=json.load(open('.cortex/state.json')); assert 'mode' in d and 'slug' in d and 'approved' in d"` — passes
- [ ] `bash -n scripts/cortex/scaffold_runtime.sh` — syntax OK
- [ ] `bash scripts/cortex/scaffold_runtime.sh /tmp/cortex-test && ls /tmp/cortex-test/docs/cortex/ && ls /tmp/cortex-test/.cortex/` — scaffold runs clean
