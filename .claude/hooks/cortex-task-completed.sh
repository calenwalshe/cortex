#!/usr/bin/env bash
# cortex-task-completed.sh
# TaskCompleted hook — blocks completion if contract validators have not passed
# Reads eval-status.md to check pass/fail state per validator

set -uo pipefail
. "$(dirname "$0")/cortex-supervisor-log.sh"
supervisor_log "cortex-task-completed"

STATE_JSON="${CLAUDE_PROJECT_DIR}/.cortex/state.json"
EVAL_STATUS="${CLAUDE_PROJECT_DIR}/docs/cortex/handoffs/eval-status.md"

# Soft-fail guards
[[ ! -f "$STATE_JSON" ]] && exit 0

ACTIVE_CONTRACT=$(jq -r '.active_contract // ""' "$STATE_JSON" 2>/dev/null || echo "")

# No active contract — no enforcement possible
[[ -z "$ACTIVE_CONTRACT" ]] && exit 0

# EVAL-SPECIFIC: non-blocking eval gate
# If eval plan exists but results haven't run yet, write pending status and allow completion.
# The blocking behaviour is reserved for FAIL verdicts in populated eval-status.md.
if [[ ! -f "$EVAL_STATUS" ]]; then
  # Check if the active contract has an eval_plan field (non-pending)
  EVAL_PLAN_FIELD=$(grep -m1 'eval_plan:' "${CLAUDE_PROJECT_DIR}/${ACTIVE_CONTRACT}" 2>/dev/null | sed 's/.*eval_plan: *//' | tr -d '[:space:]' || echo "")
  SLUG=$(jq -r '.slug // ""' "$STATE_JSON" 2>/dev/null || echo "")
  EVALS_DIR="${CLAUDE_PROJECT_DIR}/docs/cortex/evals/${SLUG}"
  RESULTS_EXIST=$(ls "${EVALS_DIR}"/results-*.md 2>/dev/null | head -1 || echo "")

  if [[ -n "$EVAL_PLAN_FIELD" && "$EVAL_PLAN_FIELD" != "(pending)" && -z "$RESULTS_EXIST" ]]; then
    # Eval plan configured but evals not yet run — write pending notice, exit 0 (non-blocking)
    mkdir -p "$(dirname "$EVAL_STATUS")"
    echo "evals pending — run /cortex-eval-run to execute" > "$EVAL_STATUS"
    echo "[cortex-task-completed] Evals pending for ${SLUG} — non-blocking (run /cortex-eval-run)" >&2
    exit 0
  fi

  # No eval plan and no eval-status — block (old behaviour preserved)
  python3 -c "
import json
print(json.dumps({
  'continue': False,
  'stopReason': 'Task completion blocked: no eval-status.md found. Run validators against the active contract before marking complete.'
}))
"
  exit 0
fi

# Check for CORTEX_PROMISE completion signal
# The executor must emit "CORTEX_PROMISE: <contract-id> COMPLETE" to signal done
CONTRACT_ID=$(jq -r '.slug // ""' "$STATE_JSON" 2>/dev/null || echo "")
if [[ -n "$CONTRACT_ID" ]]; then
  # Check recent git log for the promise signal
  PROMISE_FOUND=$(git log --oneline -20 --grep="CORTEX_PROMISE.*COMPLETE" 2>/dev/null | head -1 || echo "")
  # Also check if the signal was written to a known location
  PROMISE_FILE="${CLAUDE_PROJECT_DIR}/.cortex/promise-${CONTRACT_ID}.signal"
  if [[ -z "$PROMISE_FOUND" ]] && [[ ! -f "$PROMISE_FILE" ]]; then
    # Promise not found — warn but don't block (signal may come via different channel)
    echo "[cortex-task-completed] Warning: CORTEX_PROMISE signal not detected for ${CONTRACT_ID}" >&2
  fi
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
