#!/usr/bin/env bash
# cortex-session-end.sh
# Stop hook (async) — writes continuity state after each agent response turn
# NOTE: Stop fires after EVERY agent response. This hook is registered async
# so it does not delay the response. It soft-fails silently on any error.

set -uo pipefail

STATE_JSON="${CLAUDE_PROJECT_DIR}/.cortex/state.json"
CURRENT_STATE="${CLAUDE_PROJECT_DIR}/docs/cortex/handoffs/current-state.md"

# No state.json — nothing to write
[[ ! -f "$STATE_JSON" ]] && exit 0

MODE=$(jq -r '.mode // "clarify"' "$STATE_JSON" 2>/dev/null || echo "clarify")
SLUG=$(jq -r '.slug // ""' "$STATE_JSON" 2>/dev/null || echo "")
APPROVAL=$(jq -r '.approval_status // "pending"' "$STATE_JSON" 2>/dev/null || echo "pending")
CONTRACT=$(jq -r '.active_contract // ""' "$STATE_JSON" 2>/dev/null || echo "")
ARTIFACTS=$(jq -r '.artifacts // [] | join("\n- ")' "$STATE_JSON" 2>/dev/null || echo "")

# Build updated current-state.md content
{
  echo "# Current State"
  echo ""
  echo "**slug:** ${SLUG:-(none)}"
  echo ""
  echo "**mode:** $MODE"
  echo ""
  echo "**approval_status:** $APPROVAL"
  echo ""
  echo "**active_contract_path:** ${CONTRACT:-(none)}"
  echo ""
  echo "**recent_artifacts:**"
  if [[ -n "$ARTIFACTS" ]]; then
    echo "- $ARTIFACTS"
  else
    echo "- (none)"
  fi
  echo ""
  echo "**open_questions:**"
  echo "- (see docs/cortex/handoffs/open-questions.md)"
  echo ""
  echo "**blockers:**"
  echo "- (none)"
  echo ""
  echo "**next_action:** Run /cortex-status for full reconstruction"
} > "$CURRENT_STATE" 2>/dev/null || exit 0

exit 0
