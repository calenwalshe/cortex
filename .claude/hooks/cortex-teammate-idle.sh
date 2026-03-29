#!/usr/bin/env bash
# cortex-teammate-idle.sh
# TeammateIdle hook — feeds actionable next step to idle agent team members

set -uo pipefail

CURRENT_STATE="${CLAUDE_PROJECT_DIR}/docs/cortex/handoffs/current-state.md"
STATE_JSON="${CLAUDE_PROJECT_DIR}/.cortex/state.json"

# Read next action from current-state.md
NEXT_ACTION=""
if [[ -f "$CURRENT_STATE" ]]; then
  NEXT_ACTION=$(grep -A1 "^\*\*next_action\*\*:" "$CURRENT_STATE" 2>/dev/null | tail -1 | sed 's/^\*\*next_action\*\*: //' || echo "")
fi

MODE=$(jq -r '.mode // "clarify"' "$STATE_JSON" 2>/dev/null || echo "clarify")
SLUG=$(jq -r '.slug // ""' "$STATE_JSON" 2>/dev/null || echo "")

if [[ -n "$NEXT_ACTION" ]]; then
  echo "Cortex: You are idle. Current work item: ${SLUG:-(none)}, mode: $MODE. Next recommended action: $NEXT_ACTION. Run /cortex-status for full context." >&2
else
  echo "Cortex: You are idle. Run /cortex-status to see the current work item and recommended next action." >&2
fi

exit 2  # Keep the teammate working
