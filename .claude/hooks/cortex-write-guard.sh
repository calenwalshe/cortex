#!/usr/bin/env bash
# cortex-write-guard.sh
# PreToolUse on Write|Edit — enforces per-agent write path restrictions
# Used by: cortex-specifier, cortex-scribe, cortex-eval-designer

set -uo pipefail
# NOTE: No -e flag — hook must soft-fail, not crash

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // ""' 2>/dev/null)

# No file path — nothing to guard
[[ -z "$FILE_PATH" ]] && exit 0

# Resolve absolute permitted roots
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
DOCS_SPECS="$PROJECT_DIR/docs/cortex/specs"
DOCS_CONTRACTS="$PROJECT_DIR/docs/cortex/contracts"
DOCS_HANDOFFS="$PROJECT_DIR/docs/cortex/handoffs"
DOCS_EVALS="$PROJECT_DIR/docs/cortex/evals"
CORTEX_DIR="$PROJECT_DIR/.cortex"

# Determine which agent is calling based on AGENT_NAME or fall through to
# a broad docs/cortex + .cortex check as the default safe zone
case "$AGENT_NAME" in
  cortex-specifier)
    ALLOWED=("$DOCS_SPECS" "$DOCS_CONTRACTS")
    ;;
  cortex-scribe)
    ALLOWED=("$DOCS_HANDOFFS" "$CORTEX_DIR")
    ;;
  cortex-eval-designer)
    ALLOWED=("$DOCS_EVALS")
    ;;
  *)
    # Unknown agent — allow writes within docs/cortex/ and .cortex/ broadly
    ALLOWED=("$PROJECT_DIR/docs/cortex" "$CORTEX_DIR")
    ;;
esac

# Check if FILE_PATH is within any allowed root
for ROOT in "${ALLOWED[@]}"; do
  if [[ "$FILE_PATH" == "$ROOT"* ]]; then
    exit 0  # Allowed
  fi
done

# Block the write
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Write blocked: ${AGENT_NAME:-agent} may only write to designated paths. Attempted: $FILE_PATH"
  }
}
EOF
exit 0
