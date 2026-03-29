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
<!-- Format: - [ ] {validation check or command} -->

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

## Rollback Hints

{ROLLBACK_HINTS}

<!-- Steps to reverse this contract's changes if needed -->
<!-- Each step on its own line starting with "- " -->
<!-- Be specific: file paths to delete, commands to run, state to restore -->
