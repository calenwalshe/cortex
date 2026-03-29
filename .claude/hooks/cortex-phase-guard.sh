#!/usr/bin/env bash
# cortex-phase-guard.sh
# PreToolUse on Write|Edit — blocks writes outside permitted roots
# during clarify/research/spec phases.
#
# Does NOT block during execute/validate/repair/assure/done.
# Soft-fails (exit 0 allow) if state.json missing or unreadable.

set -uo pipefail

CORTEX_STATE="${CLAUDE_PROJECT_DIR}/.cortex/state.json"
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)

# Soft-fail guards
[[ ! -f "$CORTEX_STATE" ]] && exit 0
[[ -z "$FILE_PATH" ]] && exit 0

MODE=$(jq -r '.mode // "clarify"' "$CORTEX_STATE" 2>/dev/null || echo "clarify")

# Phase guard only applies to pre-execution phases
case "$MODE" in
  clarify|research|spec)
    ;;
  *)
    exit 0  # execute/validate/repair/assure/done — no restriction
    ;;
esac

# Permitted write roots during pre-execution phases
DOCS_ROOT="${CLAUDE_PROJECT_DIR}/docs/cortex"
CORTEX_ROOT="${CLAUDE_PROJECT_DIR}/.cortex"

if [[ "$FILE_PATH" == "$DOCS_ROOT"* ]] || [[ "$FILE_PATH" == "$CORTEX_ROOT"* ]]; then
  exit 0  # Within permitted roots
fi

# Block with actionable reason (JSON deny, not exit 2)
python3 -c "
import json, sys
reason = sys.argv[1]
mode = sys.argv[2]
print(json.dumps({
  'hookSpecificOutput': {
    'hookEventName': 'PreToolUse',
    'permissionDecision': 'deny',
    'permissionDecisionReason': reason
  }
}))
" "Phase guard: writes outside docs/cortex/ and .cortex/ are blocked while in $MODE mode. Advance to execute mode before writing product code." "$MODE"

exit 0
