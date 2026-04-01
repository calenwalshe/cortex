# Current State

**slug:** auto-doc-sync

**mode:** clarify

**approval_status:** pending

**active_contract_path:** (none)

**recent_artifacts:**
- docs/cortex/clarify/auto-doc-sync/20260401T200000Z-clarify-brief.md

**open_questions:**
- What is the complete source-to-doc mapping table?
- Does the generated update auto-commit or stage for human review?
- How does the hook distinguish minor fixes from architectural changes requiring human review?
- What is the LLM invocation mechanism from a git pre-commit hook?
- What is the failure mode when the API is unavailable?
- Does the hook scope updates to the directly changed section or scan downstream dependencies?
- How are multi-file commits handled — batched or sequential LLM calls?

**blockers:**
- (none)

**next_action:** Run /cortex-research --phase concept to begin concept research
