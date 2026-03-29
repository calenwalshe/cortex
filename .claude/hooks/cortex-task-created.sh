#!/usr/bin/env bash
# cortex-task-created.sh
# TaskCreated hook — rejects tasks missing required Cortex fields
# Required: objective, deliverable, validator reference, contract link

set -uo pipefail

INPUT=$(cat)

SUBJECT=$(echo "$INPUT" | jq -r '.task_subject // ""' 2>/dev/null)
DESCRIPTION=$(echo "$INPUT" | jq -r '.task_description // ""' 2>/dev/null)

# Combine subject + description for field checking
FULL_TEXT="$SUBJECT $DESCRIPTION"

# Soft-fail if we can't read the task
[[ -z "$SUBJECT" ]] && [[ -z "$DESCRIPTION" ]] && exit 0

MISSING=()

# Check for deliverable signal (must name a file or artifact)
if ! echo "$FULL_TEXT" | grep -qiE "deliverable|produces|output|creates|writes|artifact"; then
  MISSING+=("deliverable")
fi

# Check for validator reference
if ! echo "$FULL_TEXT" | grep -qiE "validator|eval|test|verify|assertion|check"; then
  MISSING+=("validator")
fi

# Check for contract link
if ! echo "$FULL_TEXT" | grep -qiE "contract|contract-[0-9]|docs/cortex/contracts"; then
  MISSING+=("contract link")
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
  MISSING_STR=$(IFS=", "; echo "${MISSING[*]}")
  python3 -c "
import json, sys
missing = sys.argv[1]
print(json.dumps({
  'continue': False,
  'stopReason': f'Task rejected: missing required fields: {missing}. Every Cortex task must include a deliverable, at least one validator reference, and a contract link.'
}))
" "$MISSING_STR"
  exit 0
fi

exit 0
