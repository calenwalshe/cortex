# Eval Proposal: {SLUG}

<!-- ART-06: Eval Proposal Template — produced by /cortex-research --phase evals -->
<!-- Copy this template to docs/cortex/evals/{SLUG}/eval-proposal.md in the target project repo -->
<!-- The proposal is reviewed by a human before the eval plan is written -->

**Slug:** {SLUG} <!-- lowercase-hyphenated identifier matching the active contract -->
**Timestamp:** {TIMESTAMP} <!-- ISO 8601 UTC timestamp when this proposal was produced -->
**Status:** {STATUS} <!-- draft | approved | rejected -->

---

## Proposed Dimensions

{PROPOSED_DIMENSIONS}

<!-- Select applicable dimensions from the 8-candidate matrix below -->
<!-- For each selected dimension, note whether approval_required: true -->
<!--
Available dimensions (from docs/EVALS.md candidate matrix):
- Functional correctness (always mandatory)
- Regression (mandatory when existing code is modified)
- Integration (mandatory when multiple components interact)
- Safety/security (mandatory for auth, data handling, input validation, secrets)
- Performance (when contract specifies perf thresholds)
- Resilience (for networked systems, external dependencies)
- Style (all code and doc deliverables)
- UX/taste (user-facing output, generated content — ALWAYS requires human approval)
-->

<!-- Format per dimension:
### {Dimension Name}
**Applies because:** {why this dimension is relevant to the contract}
**approval_required:** true | false
-->

---

## Fixtures

{FIXTURES}

<!-- Test fixtures or data needed for each proposed dimension -->
<!-- Format per dimension:
### Fixtures: {Dimension Name}
- {fixture description — what data or setup is needed}
-->

---

## Rubrics

{RUBRICS}

<!-- Scoring criteria per dimension — how to evaluate pass vs fail -->
<!-- Format per dimension:
### Rubric: {Dimension Name}
{description of what passing looks like, what failing looks like}
-->

---

## Thresholds

{THRESHOLDS}

<!-- Pass/fail thresholds per dimension -->
<!-- Format per dimension:
### Threshold: {Dimension Name}
**Pass:** {specific measurable condition, e.g. "all assertions pass", ">95% coverage", "no P0 findings"}
**Fail:** {what constitutes a failure that blocks progression}
-->

---

## Failure Taxonomy

{FAILURE_TAXONOMY}

<!-- Categories of failures and their severity -->
<!-- Format:
| Failure Category | Severity | Description | Repair Path |
|-----------------|----------|-------------|-------------|
| {category} | P0 | {description} | {what to do if this fails} |
| {category} | P1 | {description} | {what to do if this fails} |
| {category} | P2 | {description} | {what to do if this fails} |
| {category} | P3 | {description} | {what to do if this fails} |
-->
<!-- P0 = blocking, contract cannot advance; P1 = serious, repair required; P2 = moderate, addressed in next iteration; P3 = minor, logged and deferred -->

---

## Document-Level Approval Flag

**approval_required:** {APPROVAL_REQUIRED}

<!-- true if ANY selected dimension requires human approval -->
<!-- UX/taste always sets this to true -->
<!-- High-stakes or ambiguous evals also set this to true -->
<!-- false only if all dimensions are mechanical and unambiguous -->

**Reviewer:** {REVIEWER}

<!-- Who must approve this proposal before the eval plan is written -->
<!-- Human name or role, e.g. "project lead", "security reviewer" -->

**Approval Status:** {APPROVAL_STATUS}

<!-- pending | approved | rejected -->
<!-- Contract stays in spec state until this is approved (when approval_required: true) -->
