# Spec: {SLUG}

<!-- ART-03: Spec Template — produced by /cortex-spec -->
<!-- Copy this template to docs/cortex/specs/{SLUG}/spec.md in the target project repo -->
<!-- All 9 sections are mandatory — omitting any section is an error -->

**Slug:** {SLUG} <!-- lowercase-hyphenated identifier matching the active clarify brief -->
**Timestamp:** {TIMESTAMP} <!-- ISO 8601 UTC timestamp when this spec was created -->
**Status:** {STATUS} <!-- draft | approved | superseded -->

---

## 1. Problem

{PROBLEM}

<!-- What is being built and why — one paragraph -->
<!-- Answers: what problem does this solve, for whom, and why now? -->
<!-- Do not describe the solution here — describe the problem -->

---

## 2. Scope

### In Scope

{IN_SCOPE}

<!-- List of what this spec covers — each item on its own line starting with "- " -->

### Out of Scope

{OUT_OF_SCOPE}

<!-- Explicit exclusions — each item on its own line starting with "- " -->
<!-- Being explicit here prevents scope creep during implementation -->

---

## 3. Architecture Decision

{ARCHITECTURE_DECISION}

<!-- The chosen approach and why — includes alternatives considered and why they were rejected -->
<!-- Format:
**Chosen approach:** {description}
**Rationale:** {why this over alternatives}

### Alternatives Considered
- **{Alternative 1}:** {why rejected}
- **{Alternative 2}:** {why rejected}
-->

---

## 4. Interfaces

{INTERFACES}

<!-- External interfaces this spec touches: APIs, contracts, module boundaries, file paths -->
<!-- Each interface on its own line starting with "- " -->
<!-- Include: what the interface is, who owns it, what this spec reads vs writes -->

---

## 5. Dependencies

{DEPENDENCIES}

<!-- Libraries, services, or other Cortex artifacts this spec depends on -->
<!-- Each dependency on its own line starting with "- " -->
<!-- Include: name, version (if applicable), what this spec uses it for -->

---

## 6. Risks

{RISKS}

<!-- List of risks with mitigation per risk -->
<!-- Format per risk:
- **{Risk description}** — Mitigation: {how to address or accept this risk}
-->

---

## 7. Sequencing

{SEQUENCING}

<!-- Order of implementation steps — numbered list -->
<!-- Each step should produce a verifiable checkpoint or artifact -->
<!-- 1. First step, 2. Second step, etc. -->

---

## 8. Tasks

{TASKS}

<!-- Discrete implementation tasks — each gets a checkbox -->
<!-- Format: - [ ] {task description} -->
<!-- Tasks should be small enough to commit atomically -->

---

## 9. Acceptance Criteria

{ACCEPTANCE_CRITERIA}

<!-- Measurable, testable criteria — each gets a checkbox -->
<!-- Format: - [ ] {criterion — must be objectively verifiable} -->
<!-- Every criterion must have a clear pass/fail definition -->
<!-- These criteria are the source of truth for the contract's done_criteria -->
