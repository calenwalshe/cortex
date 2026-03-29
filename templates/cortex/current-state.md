# Current State

<!-- Template: field-by-field match with docs/CONTINUITY.md current-state.md Schema table -->
<!-- Copy this file to docs/cortex/handoffs/current-state.md and fill in values -->

**slug:** {SLUG}
<!-- string — current active slug, e.g., retry-logic-v2 -->

**mode:** {MODE}
<!-- enum — clarify | research | spec | execute | validate | repair | assure | done -->

**approval_status:** {APPROVAL_STATUS}
<!-- enum — pending | approved | rejected -->

**active_contract_path:** {ACTIVE_CONTRACT_PATH}
<!-- string — relative path to the active contract, e.g., docs/cortex/contracts/retry-logic-v2/contract-001.md -->

**recent_artifacts:**
<!-- array — artifact paths written in current/most recent session -->
{RECENT_ARTIFACTS}

**open_questions:**
<!-- array — questions that must be resolved to advance to the next phase -->
{OPEN_QUESTIONS}

**blockers:**
<!-- array — hard blockers preventing the current phase transition -->
{BLOCKERS}

**next_action:** {NEXT_ACTION}
<!-- string — the single recommended next step -->
