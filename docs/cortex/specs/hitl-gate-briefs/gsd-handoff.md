# GSD Handoff: hitl-gate-briefs

**Slug:** hitl-gate-briefs
**Timestamp:** 20260403T210500Z
**Status:** draft

---

## Objective

Replace procedural gate output ("edit file X, re-run Y") with decision-framed gate briefs across 5 Cortex approval gates. Each brief uses a three-layer structure (impact → items → details) and Pulumi-style interactive prompts (approve/reject/details). Success = every gate that blocks for human input presents a concise brief telling the approver what would happen, not how the system works.

---

## Deliverables

- `templates/cortex/gate-brief.md` — shared gate brief template
- Modified `skills/cortex-spec/SKILL.md` — contract_approval interactive prompt
- Modified `skills/cortex-research/SKILL.md` — eval_proposal interactive prompt
- Modified `skills/cortex-clarify/SKILL.md` — slug_conflict defined brief
- Modified `skills/cortex-review/SKILL.md` — compliance_verdict brief with finding counts
- Modified `skills/cortex-audit/SKILL.md` — security_verdict brief with severity counts

---

## Requirements

- None formalized

---

## Tasks

- [ ] Create `templates/cortex/gate-brief.md` with impact/items/details/action sections and conditional markers for gate types
- [ ] Patch cortex-spec SKILL.md: contract_approval uses gate brief + AskUserQuestion (approve/reject/details)
- [ ] Patch cortex-research SKILL.md: eval_proposal uses gate brief + inline approve/reject
- [ ] Patch cortex-clarify SKILL.md: slug_conflict gets defined brief (current → new slug, confirm/cancel)
- [ ] Patch cortex-review SKILL.md: compliance_verdict uses brief with finding counts by severity
- [ ] Patch cortex-audit SKILL.md: security_verdict uses brief with severity counts + approve/reject
- [ ] Add stub output definitions for ux_taste_eval and human_action mandatory gates

---

## Acceptance Criteria

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

## Contract Link

docs/cortex/contracts/hitl-gate-briefs/contract-001.md
