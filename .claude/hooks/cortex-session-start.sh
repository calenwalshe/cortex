#!/usr/bin/env bash
# cortex-session-start.sh
# SessionStart hook — hydrates Claude with current-state.md context
# Fires on: startup, resume, clear, compact

set -uo pipefail
. "$(dirname "$0")/cortex-supervisor-log.sh"
supervisor_log "cortex-session-start"

CURRENT_STATE="${CLAUDE_PROJECT_DIR}/docs/cortex/handoffs/current-state.md"

# No state yet — fresh project, nothing to inject
if [[ ! -f "$CURRENT_STATE" ]]; then
  exit 0
fi

CONTENT=$(cat "$CURRENT_STATE")

# Retrieve relevant facts for current slug (if facts exist)
FACTS=""
FACTS_FILE="${CLAUDE_PROJECT_DIR}/.cortex/facts.jsonl"
STATE_FILE="${CLAUDE_PROJECT_DIR}/.cortex/state.json"

if [[ -f "$FACTS_FILE" && -f "$STATE_FILE" ]]; then
  SLUG=$(python3 -c "import json; print(json.load(open('$STATE_FILE')).get('slug',''))" 2>/dev/null)
  if [[ -n "$SLUG" ]]; then
    # Try semantic retrieval first (if embeddings exist)
    RETRIEVE_SCRIPT="${CLAUDE_PROJECT_DIR}/scripts/cortex/cortex-retrieve.py"
    if [[ -f "$RETRIEVE_SCRIPT" && -f "${CLAUDE_PROJECT_DIR}/.cortex/fact-embeddings.npy" ]]; then
      FACTS=$(cd "$CLAUDE_PROJECT_DIR" && python3 "$RETRIEVE_SCRIPT" "$SLUG" --top-k 10 --format text 2>/dev/null | head -30)
    fi
    # Fallback: grep for slug-tagged facts, prioritize lessons and procedures
    if [[ -z "$FACTS" ]]; then
      FACTS=$(grep "\"slug\":\"$SLUG\"" "$FACTS_FILE" 2>/dev/null \
        | grep -E '"type":"(lesson|procedure|decision|pattern|observation)"' \
        | tail -10 \
        | python3 -c "import sys,json; [print(json.loads(l)['text']) for l in sys.stdin]" 2>/dev/null \
        | head -20)
    fi
  fi
fi

# Run quick coherence check (non-blocking)
HEALTH=""
HEALTH_SCRIPT="${CLAUDE_PROJECT_DIR}/scripts/cortex/cortex-health.py"
if [[ -f "$HEALTH_SCRIPT" ]]; then
  HEALTH_ISSUES=$(cd "$CLAUDE_PROJECT_DIR" && python3 "$HEALTH_SCRIPT" --json 2>/dev/null \
    | python3 -c "import sys,json; d=json.load(sys.stdin); issues=[i for n,c in d.get('coherence',{}).items() for i in c.get('issues',[])]; print('\n'.join(issues[:3]) if issues else '')" 2>/dev/null)
  if [[ -n "$HEALTH_ISSUES" ]]; then
    HEALTH="\n\nCOHERENCE WARNINGS:\n${HEALTH_ISSUES}"
  fi
fi

# Build context with optional facts and health
EXTRA=""
if [[ -n "$FACTS" ]]; then
  EXTRA="\n\nRELEVANT FACTS FROM PRIOR WORK:\n${FACTS}"
fi
if [[ -n "$HEALTH" ]]; then
  EXTRA="${EXTRA}${HEALTH}"
fi

python3 -c "
import json, sys
content = sys.stdin.read()
extra = '''$EXTRA'''
output = {
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': 'CORTEX STATE RESTORED\n\n' + content + extra
    }
}
print(json.dumps(output))
" <<< "$CONTENT"

exit 0
