# Eval Plan: {SLUG}

<!-- ART-07: Eval Plan Template — written after human approval of the eval proposal -->
<!-- Copy this template to docs/cortex/evals/{SLUG}/eval-plan.md in the target project repo -->
<!-- This is the authoritative record of which evals will run, what fixtures will be used, -->
<!-- and what thresholds must be met. The contract's eval_plan field points to this file. -->

**Slug:** {SLUG} <!-- lowercase-hyphenated identifier matching the active contract -->
**Timestamp:** {TIMESTAMP} <!-- ISO 8601 UTC timestamp when this plan was written -->
**Approved By:** {APPROVED_BY} <!-- Human name or role who approved the eval proposal -->
**Approved At:** {APPROVED_AT} <!-- ISO 8601 UTC timestamp of approval -->

---

## Approved Dimensions

{APPROVED_DIMENSIONS}

<!-- Subset of proposed dimensions that were approved by the human reviewer -->
<!-- Each dimension on its own line starting with "- " -->
<!-- Only dimensions listed here will be executed — unapproved dimensions are not run -->

---

## Fixtures Per Dimension

{FIXTURES_PER_DIMENSION}

<!-- Fixtures for each approved dimension -->
<!-- Format per dimension:
### Fixtures: {Dimension Name}
- {fixture: what data, files, or setup is needed}
- {fixture: ...}
-->

---

## Thresholds Per Dimension

{THRESHOLDS_PER_DIMENSION}

<!-- Pass/fail threshold per approved dimension -->
<!-- Format per dimension:
### Threshold: {Dimension Name}
**Pass:** {specific measurable condition}
**Fail:** {what constitutes a blocking failure}
-->

---

## Run Instructions

{RUN_INSTRUCTIONS}

<!-- How to execute this eval plan — ordered steps -->
<!-- Steps must be specific enough that a stateless executor can follow them -->
<!-- 1. First step, 2. Second step, etc. -->

---

## Results

<!-- Populated after running — initially all checkboxes unchecked -->
<!-- Each approved dimension gets one result entry -->
<!-- Update after each eval run: check the box and record the outcome -->

{RESULTS}

<!-- Format per dimension:
- [ ] {Dimension Name} — {outcome when checked: "passed" or "failed: {reason}"}
-->

<!-- All dimensions must show "passed" before the contract can advance to assure state -->
