# GSD Handoff: {SLUG}

<!-- ART-04: GSD Handoff Template — produced by /cortex-spec -->
<!-- Copy this template to docs/cortex/specs/{SLUG}/gsd-handoff.md in the target project repo -->
<!-- This is a GSD-ready work order. The human imports this into GSD explicitly. -->
<!-- Cortex NEVER calls GSD commands — that is always a human step. -->

**Slug:** {SLUG} <!-- lowercase-hyphenated identifier matching the active spec and contract -->
**Timestamp:** {TIMESTAMP} <!-- ISO 8601 UTC timestamp when this handoff was produced -->
**Status:** {STATUS} <!-- draft | ready | imported -->

---

## Objective

{OBJECTIVE}

<!-- What must be built and why — single clear statement -->
<!-- Distilled from the spec's Problem and Architecture Decision sections -->
<!-- A GSD executor reading only this section should understand what success looks like -->

---

## Deliverables

{DELIVERABLES}

<!-- List of artifacts to produce during this GSD execution -->
<!-- Each deliverable on its own line starting with "- " -->
<!-- Include: artifact type, file path (relative to target repo), brief description -->

---

## Requirements

{REQUIREMENTS}

<!-- Requirement IDs from the project's REQUIREMENTS.md that this work satisfies -->
<!-- Each ID on its own line starting with "- " -->
<!-- Example: - AUTH-01, - AUTH-02 -->
<!-- If no formal requirements exist, write: - None formalized -->

---

## Tasks

{TASKS}

<!-- Ordered implementation tasks with checkboxes — GSD executor works through these in order -->
<!-- Format: - [ ] {task description} -->
<!-- Each task should be atomic enough to commit independently -->
<!-- Tasks must be concrete enough that a stateless executor can follow them without guessing -->

---

## Acceptance Criteria

{ACCEPTANCE_CRITERIA}

<!-- Measurable done criteria — must match the active contract's done_criteria exactly -->
<!-- Format: - [ ] {criterion — must be objectively verifiable} -->
<!-- These criteria gate completion — all must pass before marking done -->

---

## Contract Link

{CONTRACT_LINK}

<!-- Relative path to the active contract for this work -->
<!-- Format: docs/cortex/contracts/{SLUG}/contract-001.md -->
<!-- The executor must check this contract before starting — it defines scope boundaries and write roots -->
