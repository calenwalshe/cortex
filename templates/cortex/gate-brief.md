# Gate Brief Template

<!-- ART-08: Gate Brief Template — used by Cortex skills at human-approval gates -->
<!-- Renders inline when a gate blocks. Three-layer structure: impact → items → details -->
<!-- Conditional sections: include only sections relevant to the gate type -->

## Brief Structure

When a gate blocks and requires human input, render this brief BEFORE the AskUserQuestion prompt:

```
════════════════════════════════════════
GATE: {GATE_NAME}
════════════════════════════════════════

{IMPACT_LINE}

{IF_ITEMS}
What would be approved:
{ITEM_LIST}
{END_IF_ITEMS}

Details: {ARTIFACT_PATH}
════════════════════════════════════════
```

## Field Definitions

| Field | What to write |
|-------|---------------|
| `{GATE_NAME}` | Human-readable gate name (e.g., "Contract Approval", "Eval Proposal", "Slug Conflict") |
| `{IMPACT_LINE}` | One sentence using "would" language describing what approving does. Example: "Would approve contract token-efficiency-001 with 11 done criteria and 8 write roots." |
| `{ITEM_LIST}` | Bulleted list of items being approved, with state transitions where applicable. Each item: `- {item name}: {current state} → {new state}` or `- {item name}: {description}`. Max 8 items — if more, show top 8 and note "(+N more in details)". |
| `{ARTIFACT_PATH}` | Relative path to the full artifact for drill-down. |

## Action Prompt

After the brief, present an AskUserQuestion with these options (adapt labels to gate type):

**For approve/reject gates** (contract_approval, eval_proposal):
- "Approve" — proceed with the action described in the impact line
- "Reject" — block and explain why (user provides feedback)
- "Show details" — print the full artifact path content, then re-prompt

**For confirm/cancel gates** (slug_conflict):
- "Confirm" — proceed with the change
- "Cancel" — keep current state
- "Show details" — print relevant context, then re-prompt

**For review/proceed gates** (compliance_verdict, security_verdict):
- "Proceed" — acknowledge findings and continue
- "Stop" — halt pipeline to investigate
- "Show details" — print full findings, then re-prompt

## Language Rules

- Impact lines MUST use "would" (future conditional): "Would approve...", "Would switch...", "Would proceed with..."
- Never use imperative: NOT "Approve this contract" but "Would approve contract X"
- Item lists show state transitions where meaningful: "pending → approved", "cortex-research → hitl-gate-briefs"
- Finding counts use severity: "3 findings (1 critical, 2 warnings)" not "3 findings"
