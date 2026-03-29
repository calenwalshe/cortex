#!/usr/bin/env bash
# cortex-validator-trigger.sh
# PostToolUse on Write|Edit (async) — appends written file to dirty-files.json
# Only fires during execute/repair mode. Does NOT run validators inline.
#
# NOTE: PostToolUse cannot block — the write has already happened.
# This hook is for side effects only.

set -uo pipefail

CORTEX_STATE="${CLAUDE_PROJECT_DIR}/.cortex/state.json"
DIRTY_FILES="${CLAUDE_PROJECT_DIR}/.cortex/dirty-files.json"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_response.filePath // .tool_input.file_path // ""' 2>/dev/null)

# Soft-fail guards
[[ ! -f "$CORTEX_STATE" ]] && exit 0
[[ -z "$FILE_PATH" ]] && exit 0

MODE=$(jq -r '.mode // "clarify"' "$CORTEX_STATE" 2>/dev/null || echo "clarify")

# Only track dirty files during active execution phases
case "$MODE" in
  execute|repair)
    ;;
  *)
    exit 0
    ;;
esac

# Initialize dirty-files.json if it doesn't exist
if [[ ! -f "$DIRTY_FILES" ]]; then
  echo '{"dirty": []}' > "$DIRTY_FILES" 2>/dev/null || exit 0
fi

# Append file path to dirty list (using python3 for safe JSON manipulation)
python3 -c "
import json, sys
path = sys.argv[1]
dirty_file = sys.argv[2]
try:
    with open(dirty_file) as f:
        data = json.load(f)
except (json.JSONDecodeError, FileNotFoundError):
    data = {'dirty': []}
if path not in data['dirty']:
    data['dirty'].append(path)
with open(dirty_file, 'w') as f:
    json.dump(data, f, indent=2)
" "$FILE_PATH" "$DIRTY_FILES" 2>/dev/null || exit 0

exit 0
