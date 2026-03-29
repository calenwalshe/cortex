# Next Prompt

<!-- Template: paste-ready restart prompt after /clear or /compact -->
<!-- Copy to docs/cortex/handoffs/next-prompt.md and fill in values -->
<!-- Refreshed by /cortex-status and by the cortex-postcompact hook (Phase 4) -->

We are working on {SLUG} in {MODE} mode. The last completed action was {LAST_ACTION}.
The next step is {NEXT_ACTION}. The active contract is at {ACTIVE_CONTRACT_PATH}.
Run /cortex-status to see the full current state.

<!-- Field reference:
  {SLUG}                 — current active slug, e.g., retry-logic-v2
  {MODE}                 — current phase enum: clarify | research | spec | execute | validate | repair | assure | done
  {LAST_ACTION}          — summary of what was last accomplished (free text)
  {NEXT_ACTION}          — single recommended next step (matches next_action in current-state.md)
  {ACTIVE_CONTRACT_PATH} — relative path to active contract file
-->
