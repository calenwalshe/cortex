# Spec: hitl-gate-briefs

**Slug:** hitl-gate-briefs
**Timestamp:** 20260403T210500Z
**Status:** approved

---

## 1. Problem

Cortex gates that require human approval present procedural output ("edit file X, re-run command Y") instead of decision-framed briefs. The approver must parse implementation details to understand what they're approving. Three gates have no defined output at all. This slows approvals, increases cognitive load, and risks rubber-stamping because the decision isn't clearly framed.

---

## 2. Scope

### In Scope

- Create a gate brief template with three-layer structure (impact → items → details)
- Apply briefs to 5 decision-presenting gates: eval_proposal, contract_approval, slug_conflict, security_verdict, compliance_verdict
- Define output for 3 gates with undefined text: slug_conflict, security_verdict, and ux_taste_eval/human_action stubs
- Convert contract_approval and eval_proposal from "edit file manually" to interactive approve/reject prompts

### Out of Scope

- Changing the autonomy config system or gate resolution logic
- Modifying informational gates (reclarify, critical_uncertainty, evidence_backing, eval_validation) — these already work well
- Implementing the 2 unused gates (spec_approval, eval_approval)
- Adding confidence signals to briefs (deferred)
- Dashboards or UI for approvals

---

## 3. Architecture Decision

**Chosen approach:** Shared gate brief template (`templates/cortex/gate-brief.md`) with conditional sections, applied inline at each gate check point in the 5 affected SKILL.md files. Uses the Pulumi three-option pattern (approve / reject / details).

**Rationale:** Consistent approver experience across all gates. Single template to maintain. Conditional sections handle different gate types (approve/reject vs confirm vs batch review) without per-skill custom formatting.

### Alternatives Considered

- **Per-skill formatting logic:** Rejected — 5 different formats to maintain, inconsistent UX
- **Post-processing overlay:** Rejected — fragile parsing of existing output, breaks when gate output changes
- **Standalone brief command (`/cortex-gate-review`):** Rejected — adds a step to the workflow instead of improving inline experience

---

## 4. Interfaces

- **5 SKILL.md files** — cortex-clarify (slug_conflict), cortex-research (eval_proposal), cortex-spec (contract_approval), cortex-review (compliance_verdict), cortex-audit (security_verdict). Each modified to use gate brief template at blocking points.
- **`templates/cortex/gate-brief.md`** — New. Shared template with placeholders for impact line, item list, details reference, and action prompt.
- **AskUserQuestion tool** — Used for interactive approve/reject/details prompts. Already available in all skills.

---

## 5. Dependencies

- **Cortex autonomy system** (existing) — gate resolution unchanged, briefs are output formatting only
- **AskUserQuestion tool** (Claude Code built-in) — for interactive prompts
- **Existing SKILL.md gate check blocks** — modified in-place, not replaced

---

## 6. Risks

- **Template rigidity** — A shared template may not fit all gate types equally well. Mitigation: conditional sections (`{IF_BATCH}`, `{IF_BINARY}`) in the template handle variation.
- **AskUserQuestion limitations** — Max 4 options, no free-form in the same prompt. Mitigation: "details" option prints the artifact path, user can read it before re-answering.
- **Breaking existing autonomy auto-skip** — Briefs must only render when the gate is active (not auto-skipped). Mitigation: brief generation is inside the existing `if gate is true` block, never outside it.

---

## 7. Sequencing

1. **Create gate brief template** — `templates/cortex/gate-brief.md` with impact/items/details/action sections and conditional markers. Verify: template exists with all required placeholders.

2. **Patch cortex-spec (contract_approval)** — Replace "PENDING HUMAN APPROVAL" status-only output with an interactive AskUserQuestion using the gate brief template. Verify: running `/cortex-spec` presents approve/reject/details prompt.

3. **Patch cortex-research (eval_proposal)** — Replace "edit file and re-run" blocking text with an interactive prompt. Verify: eval proposal approval is inline, not file-edit-based.

4. **Patch cortex-clarify (slug_conflict)** — Define the exact brief text for slug conflict warning. Verify: switching slugs shows a clear brief with current vs new slug.

5. **Patch cortex-review (compliance_verdict)** — Frame the compliance verdict as a brief with finding counts by severity. Verify: NON-COMPLIANT verdict shows impact line + finding summary.

6. **Patch cortex-audit (security_verdict)** — Define brief for security findings with severity counts. Verify: audit findings show impact line + approve/reject prompt.

---

## 8. Tasks

- [ ] Create `templates/cortex/gate-brief.md` with impact line, item list, details reference, and action prompt sections
- [ ] Patch cortex-spec SKILL.md: contract_approval gate uses gate brief template with AskUserQuestion (approve/reject/details)
- [ ] Patch cortex-research SKILL.md: eval_proposal gate uses gate brief template with inline approve/reject
- [ ] Patch cortex-clarify SKILL.md: slug_conflict gate gets defined brief text (current slug → new slug, confirm/cancel)
- [ ] Patch cortex-review SKILL.md: compliance_verdict gate uses brief with finding counts
- [ ] Patch cortex-audit SKILL.md: security_verdict gate uses brief with severity counts
- [ ] Add stub output definitions for ux_taste_eval and human_action mandatory gates in SKILL.md files that reference them

---

## 9. Acceptance Criteria

- [ ] `templates/cortex/gate-brief.md` exists with impact, items, details, and action sections
- [ ] cortex-spec contract_approval gate presents an AskUserQuestion with approve/reject/details options (not "edit file manually")
- [ ] cortex-research eval_proposal gate presents an inline approve/reject prompt (not "edit file and re-run")
- [ ] cortex-clarify slug_conflict gate shows a brief with current slug name and new slug name
- [ ] cortex-review compliance_verdict gate shows an impact line with finding counts by severity before the verdict
- [ ] cortex-audit security_verdict gate shows an impact line with finding counts and an approve/reject prompt
- [ ] All gate briefs use "would" language in impact lines (future conditional tense)
- [ ] All gate briefs include a "details" option that references the full artifact path
- [ ] Gates that are auto-skipped (autonomy config) never render a brief — brief is inside the `if gate is true` block
