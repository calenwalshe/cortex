# Contract: hitl-gate-briefs — execute

**ID:** hitl-gate-briefs-001
**Slug:** hitl-gate-briefs
**Phase:** execute
**Created:** 20260403T210500Z
**Status:** approved

---

## Objective

Replace procedural gate blocking output with decision-framed gate briefs so every human approval point presents what would happen, not how to manually edit files.

---

## Deliverables

- `templates/cortex/gate-brief.md` — shared gate brief template
- Modified `skills/cortex-spec/SKILL.md` — contract_approval
- Modified `skills/cortex-research/SKILL.md` — eval_proposal
- Modified `skills/cortex-clarify/SKILL.md` — slug_conflict
- Modified `skills/cortex-review/SKILL.md` — compliance_verdict
- Modified `skills/cortex-audit/SKILL.md` — security_verdict

---

## Scope

### In Scope

- Gate brief template with three-layer structure
- 5 SKILL.md patches for decision-presenting gates
- Stub output for ux_taste_eval and human_action mandatory gates
- Interactive approve/reject/details prompts via AskUserQuestion

### Out of Scope

- Autonomy config changes
- Informational gate modifications (reclarify, critical_uncertainty, evidence_backing, eval_validation)
- Implementing unused gates (spec_approval, eval_approval)
- Confidence signals in briefs

---

## Write Roots

- `templates/cortex/` — gate-brief.md
- `skills/cortex-spec/` — SKILL.md
- `skills/cortex-research/` — SKILL.md
- `skills/cortex-clarify/` — SKILL.md
- `skills/cortex-review/` — SKILL.md
- `skills/cortex-audit/` — SKILL.md

---

## Done Criteria

- [ ] `templates/cortex/gate-brief.md` exists with impact, items, details, and action sections
- [ ] cortex-spec contract_approval gate presents an AskUserQuestion with approve/reject/details options (not "edit file manually")
- [ ] cortex-research eval_proposal gate presents an inline approve/reject prompt (not "edit file and re-run")
- [ ] cortex-clarify slug_conflict gate shows a brief with current slug name and new slug name
- [ ] cortex-review compliance_verdict gate shows an impact line with finding counts by severity before the verdict
- [ ] cortex-audit security_verdict gate shows an impact line with finding counts and an approve/reject prompt
- [ ] All gate briefs use "would" language in impact lines (future conditional tense)
- [ ] All gate briefs include a "details" option that references the full artifact path
- [ ] Gates that are auto-skipped (autonomy config) never render a brief — brief is inside the `if gate is true` block

---

## Validators

- [ ] `test -f templates/cortex/gate-brief.md` exits 0
- [ ] `grep "AskUserQuestion" skills/cortex-spec/SKILL.md | grep -q "approve"` (contract_approval)
- [ ] `grep "AskUserQuestion" skills/cortex-research/SKILL.md | grep -q "approve"` (eval_proposal)
- [ ] `grep "would" skills/cortex-clarify/SKILL.md | grep -q "slug"` (slug_conflict brief)
- [ ] `grep "finding" skills/cortex-review/SKILL.md | grep -qi "count\|severity"` (compliance_verdict)
- [ ] `grep "finding" skills/cortex-audit/SKILL.md | grep -qi "count\|severity"` (security_verdict)

---

## Eval Plan

docs/cortex/evals/hitl-gate-briefs/eval-plan.md (pending)

---

## Approvals

- [x] Contract approval
- [ ] Evals approval

---

## Rollback Hints

- Revert each SKILL.md via `git checkout HEAD~N -- skills/cortex-{name}/SKILL.md`
- Delete `templates/cortex/gate-brief.md`
- Gate logic is unchanged — only output formatting is modified, so rollback restores previous output without affecting gate behavior
