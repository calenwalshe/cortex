#!/usr/bin/env bash
# cortex-session-start.sh
# SessionStart hook — hydrates Claude with current-state.md context
# Fires on: startup, resume, clear, compact

set -uo pipefail

CURRENT_STATE="${CLAUDE_PROJECT_DIR}/docs/cortex/handoffs/current-state.md"

# No state yet — fresh project, nothing to inject
if [[ ! -f "$CURRENT_STATE" ]]; then
  exit 0
fi

CONTENT=$(cat "$CURRENT_STATE")

python3 -c "
import json, sys
content = sys.stdin.read()
output = {
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': 'CORTEX STATE RESTORED\n\n' + content
    }
}
print(json.dumps(output))
" <<< "$CONTENT"

exit 0
