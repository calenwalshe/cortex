# Contract: {SLUG} — {PHASE}

<!-- ART-05: Contract Template — produced by /cortex-spec -->
<!-- Copy this template to docs/cortex/contracts/{SLUG}/contract-001.md in the target project repo -->
<!-- Contract numbering starts at contract-001.md. Repair contracts increment the counter. -->
<!-- IMPORTANT: A contract without the eval_plan field is incomplete and must not advance past spec state. -->

**ID:** {CONTRACT_ID} <!-- Unique contract identifier, e.g. cortex-{SLUG}-001 -->
**Slug:** {SLUG} <!-- lowercase-hyphenated identifier matching the active spec -->
**Phase:** {PHASE} <!-- concept | implementation | evals | repair -->
**Created:** {TIMESTAMP} <!-- ISO 8601 UTC timestamp when this contract was created -->
**Status:** {STATUS} <!-- draft | approved | closed -->
**Repair Budget:** {REPAIR_BUDGET} <!-- max_repair_contracts: 3 (default), cooldown_between_repairs: 1 (phases) -->

---

## Objective

{OBJECTIVE}

<!-- Single clear statement of what this contract delivers -->
<!-- One sentence: "Build X so that Y" -->

---

## Deliverables

{DELIVERABLES}

<!-- List of artifacts to be produced under this contract -->
<!-- Each deliverable on its own line starting with "- " -->
<!-- Include: artifact type, file path (relative to target repo) -->

---

## Scope

### In Scope

{IN_SCOPE}

<!-- List of what this contract covers — each item on its own line starting with "- " -->

### Out of Scope

{OUT_OF_SCOPE}

<!-- Explicit exclusions — each item on its own line starting with "- " -->

---

## Write Roots

{WRITE_ROOTS}

<!-- Paths that the executing agent is allowed to write to -->
<!-- Any write outside these roots is a contract violation -->
<!-- Each path on its own line starting with "- " -->
<!-- Example: - docs/cortex/specs/{SLUG}/ -->

---

## Done Criteria

{DONE_CRITERIA}

<!-- Measurable, testable criteria — each gets a checkbox -->
<!-- Format: - [ ] {criterion — must be objectively verifiable} -->
<!-- All criteria must pass before contract advances to done -->

---

## Validators

{VALIDATORS}

<!-- List of validation commands or checks to run -->
<!-- Each gets a checkbox — all must pass -->
<!-- Annotate each validator with [external] or [judgment]: -->
<!--   [external] — deterministic, mechanically verifiable (grep, test, lint). Eligible for auto-repair. -->
<!--   [judgment] — requires human judgment or taste evaluation. NOT eligible for auto-repair. -->
<!-- Format: - [ ] [external] {validation command} -->
<!-- Format: - [ ] [judgment] {validation description requiring human review} -->

---

## Eval Plan

{EVAL_PLAN}

<!-- Required. Contract is incomplete without this field. -->
<!-- Path to the eval plan for this contract -->
<!-- Format: docs/cortex/evals/{SLUG}/eval-plan.md -->
<!-- Set to "pending" until the eval plan is written; contracts cannot advance to done with "pending" -->

---

## Approvals

- [ ] Contract approval <!-- Human has reviewed and approved this contract's scope and criteria -->
- [ ] Evals approval <!-- Human has reviewed and approved the associated eval plan -->

---

## Completion Promise

<!-- The executing agent MUST emit this signal when all done criteria are satisfied: -->
<!-- CORTEX_PROMISE: {CONTRACT_ID} COMPLETE -->
<!-- The cortex-task-completed.sh hook checks for this signal. -->
<!-- If the signal is not emitted, the contract is not considered complete even if all validators pass. -->

---

## Failed Approaches

<!-- Carried forward from prior repair contracts. Each entry records an approach that was tried and why it failed. -->
<!-- For initial contracts (contract-001.md), this section is empty. -->
<!-- For repair contracts (contract-002.md+), this section MUST be populated from prior contract history. -->
<!-- Format: -->
<!-- ### Attempt N (contract-NNN.md) -->
<!-- **Approach:** {what was tried} -->
<!-- **Result:** {what happened} -->
<!-- **Root cause:** {why it failed} -->

{FAILED_APPROACHES}

---

## Why Previous Approach Failed

<!-- REQUIRED for repair contracts (contract-002.md+). cortex-spec blocks repair contract creation without this section. -->
<!-- For initial contracts (contract-001.md), this section should contain "N/A — initial contract". -->
<!-- The repairing agent must explain why the previous approach failed before proposing a new one. -->

{WHY_PREVIOUS_FAILED}

---

## Rollback Hints

{ROLLBACK_HINTS}

<!-- Steps to reverse this contract's changes if needed -->
<!-- Each step on its own line starting with "- " -->
<!-- Be specific: file paths to delete, commands to run, state to restore -->

---

## Repair Budget

<!-- Limits on repair contract creation for this slug -->
<!-- max_repair_contracts: maximum number of repair contracts allowed (default: 3) -->
<!-- cooldown_between_repairs: minimum phases between repair attempts (default: 1) -->

**max_repair_contracts:** {MAX_REPAIR_CONTRACTS} <!-- default: 3 -->
**cooldown_between_repairs:** {COOLDOWN} <!-- default: 1 -->
