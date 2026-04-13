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

# Inject cross-session vault facts (non-blocking, budget-guarded)
VAULT_FACTS=""
VAULT_SCRIPT="${HOME}/memory/vault/scripts/recall_query.py"
if [[ -f "$VAULT_SCRIPT" ]]; then
  VAULT_QUERY="cortex intelligence architecture decisions lessons learned"
  VAULT_FACTS=$(python3 "$VAULT_SCRIPT" "$VAULT_QUERY" --top-k 5 --project cortex-memory-platform 2>/dev/null || true)
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
vault_facts = '''$VAULT_FACTS'''

base = 'CORTEX STATE RESTORED\n\n' + content + extra
existing_len = len(base)

# Budget guard: cap at 9500 chars to stay under 10K total additionalContext
vault_budget = max(0, 9500 - existing_len)
if vault_facts.strip() and vault_budget > 0:
    vault_section = '\n\nVAULT MEMORY (cross-session):\n' + vault_facts.strip()
    vault_section = vault_section[:vault_budget]
    base = base + vault_section

output = {
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': base
    }
}
print(json.dumps(output))
" <<< "$CONTENT"

exit 0
