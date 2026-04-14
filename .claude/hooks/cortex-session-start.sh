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
# Lock prevents multiple concurrent sessions from each spawning a heavy FAISS+LLM process.
# DISABLED: vault recall injection — was spawning concurrent FAISS+Claude subprocesses
VAULT_FACTS=""

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

# Read system-map.md staleness anchor (soft-fail if absent)
MAP_ANCHOR=""
MAP_FILE="${CLAUDE_PROJECT_DIR}/docs/cortex/system-map.md"
if [[ -f "$MAP_FILE" ]]; then
  VALID_UNTIL=$(grep "^valid_until:" "$MAP_FILE" | awk '{print $2}' | tr -d '"' | head -1)
  CONFIDENCE=$(grep "^confidence:" "$MAP_FILE" | awk '{print $2}' | tr -d '"' | head -1)
  if [[ -n "$VALID_UNTIL" ]]; then
    TODAY=$(date +%Y-%m-%d)
    if [[ "$TODAY" > "$VALID_UNTIL" ]]; then
      MAP_ANCHOR="system-map valid_until:${VALID_UNTIL} confidence:${CONFIDENCE} [STALE — refresh with /cortex-map]"
    else
      MAP_ANCHOR="system-map valid_until:${VALID_UNTIL} confidence:${CONFIDENCE}"
    fi
  fi
fi

# Build context with optional facts and health
EXTRA=""
if [[ -n "$FACTS" ]]; then
  EXTRA="\n\nRELEVANT FACTS FROM PRIOR WORK:\n${FACTS}"
fi
if [[ -n "$MAP_ANCHOR" ]]; then
  EXTRA="${EXTRA}\n\nSYSTEM MAP: ${MAP_ANCHOR}"
fi

# Structural graph staleness anchor (≤50 chars)
STRUCT_DIR="${CLAUDE_PROJECT_DIR}/.cortex/structural"
if [[ -d "$STRUCT_DIR" ]]; then
  STRUCT_COUNT=$(ls "${STRUCT_DIR}"/*.json 2>/dev/null | wc -l | tr -d ' ')
  STRUCT_DATE=$(ls -t "${STRUCT_DIR}"/*.json 2>/dev/null | head -1 | xargs -I{} python3 -c "import json,sys; d=json.load(open('{}'));print(d.get('indexed_at','')[:10])" 2>/dev/null || echo "")
  if [[ -n "$STRUCT_COUNT" && "$STRUCT_COUNT" -gt 0 ]]; then
    STRUCT_ANCHOR="struct-graph: ${STRUCT_COUNT} files, ${STRUCT_DATE}"
    EXTRA="${EXTRA}\nSTRUCT: ${STRUCT_ANCHOR}"
  fi
fi

# Operational ledger staleness anchor (≤50 chars)
OP_LEDGER="${CLAUDE_PROJECT_DIR}/.cortex/edit-ledger.jsonl"
if [[ -f "$OP_LEDGER" ]]; then
  OP_COUNT=$(wc -l < "$OP_LEDGER" | tr -d ' ')
  OP_DATE=$(tail -1 "$OP_LEDGER" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('timestamp','')[:10])" 2>/dev/null || echo "")
  if [[ -n "$OP_DATE" ]]; then
    OP_ANCHOR="OP-LEDGER: ${OP_COUNT} entries, ${OP_DATE}"
  else
    OP_ANCHOR="OP-LEDGER: ${OP_COUNT} entries"
  fi
else
  OP_ANCHOR="OP-LEDGER: absent"
fi
EXTRA="${EXTRA}\nOP: ${OP_ANCHOR}"

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
