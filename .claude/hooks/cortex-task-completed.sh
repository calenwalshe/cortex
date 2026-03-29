#!/usr/bin/env bash
# cortex-task-completed.sh
# TaskCompleted hook — blocks completion if contract validators have not passed
# Reads eval-status.md to check pass/fail state per validator

set -uo pipefail

STATE_JSON="${CLAUDE_PROJECT_DIR}/.cortex/state.json"
EVAL_STATUS="${CLAUDE_PROJECT_DIR}/docs/cortex/handoffs/eval-status.md"

# Soft-fail guards
[[ ! -f "$STATE_JSON" ]] && exit 0

ACTIVE_CONTRACT=$(jq -r '.active_contract // ""' "$STATE_JSON" 2>/dev/null || echo "")

# No active contract — no enforcement possible
[[ -z "$ACTIVE_CONTRACT" ]] && exit 0

# No eval-status.md — evals haven't run yet
if [[ ! -f "$EVAL_STATUS" ]]; then
  python3 -c "
import json
print(json.dumps({
  'continue': False,
  'stopReason': 'Task completion blocked: no eval-status.md found. Run validators against the active contract before marking complete.'
}))
"
  exit 0
fi

# Check for any FAIL lines in eval-status.md
if grep -qiE "^.*\|.*FAIL" "$EVAL_STATUS" 2>/dev/null; then
  FAILING=$(grep -iE "^.*\|.*FAIL" "$EVAL_STATUS" | head -5)
  python3 -c "
import json, sys
failing = sys.argv[1]
print(json.dumps({
  'continue': False,
  'stopReason': f'Task completion blocked: failing validators detected in eval-status.md. Repair these before marking complete:\n{failing}'
}))
" "$FAILING"
  exit 0
fi

exit 0
