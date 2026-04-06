#!/usr/bin/env bash
# cortex-context-capacity.sh — PostToolUse hook for context window monitoring
#
# Reads context window data from the statusline bridge file written by
# gsd-statusline.js (/tmp/claude-ctx-{session_id}.json). Falls back to
# PostToolUse stdin context_window field if bridge file is unavailable.
#
# Warns at 75-85% used (15-25% remaining), blocks at >85% used (<15% remaining).
#
# Exit codes:
#   0 — context OK or data unavailable (never blocks on missing data)
#   2 — context capacity exceeded (>85% used), blocks tool execution
#
# Thresholds are configurable via .cortex/autonomy.json:
#   { "context_capacity": { "warn_pct": 25, "block_pct": 15 } }
# Defaults: warn at 25% remaining, block at 15% remaining.

set -euo pipefail

# Read stdin JSON
INPUT=$(cat)

# Extract session_id for bridge file lookup
SESSION_ID=$(echo "$INPUT" | node -e "
  let d='';
  process.stdin.on('data',c=>d+=c);
  process.stdin.on('end',()=>{
    try {
      const j=JSON.parse(d);
      console.log(j.session_id||'');
    } catch(e) { console.log(''); }
  });
" 2>/dev/null)

# Try bridge file first (written by gsd-statusline.js), then fall back to stdin
REMAINING=""

if [ -n "$SESSION_ID" ]; then
  BRIDGE="/tmp/claude-ctx-${SESSION_ID}.json"
  if [ -f "$BRIDGE" ]; then
    # Staleness check: ignore bridge file older than 60s
    BRIDGE_AGE=$(( $(date +%s) - $(stat -c %Y "$BRIDGE" 2>/dev/null || echo 0) ))
    if [ "$BRIDGE_AGE" -lt 60 ]; then
      REMAINING=$(node -e "
        try {
          const d=JSON.parse(require('fs').readFileSync('$BRIDGE','utf8'));
          console.log(d.remaining_percentage!=null?d.remaining_percentage:'');
        } catch(e) { console.log(''); }
      " 2>/dev/null)
    fi
  fi
fi

# Fallback: try stdin context_window (may not be available in all Claude Code versions)
if [ -z "$REMAINING" ]; then
  REMAINING=$(echo "$INPUT" | node -e "
    let d='';
    process.stdin.on('data',c=>d+=c);
    process.stdin.on('end',()=>{
      try {
        const j=JSON.parse(d);
        const r=j.context_window&&j.context_window.remaining_percentage;
        console.log(r!=null?r:'');
      } catch(e) { console.log(''); }
    });
  " 2>/dev/null)
fi

if [ -z "$REMAINING" ]; then
  exit 0
fi

# Load thresholds from .cortex/autonomy.json or use defaults
WARN_PCT=25
BLOCK_PCT=15

if [ -f ".cortex/autonomy.json" ]; then
  CUSTOM_WARN=$(node -e "
    try {
      const c=JSON.parse(require('fs').readFileSync('.cortex/autonomy.json','utf8'));
      console.log(c.context_capacity&&c.context_capacity.warn_pct||'');
    } catch(e) { console.log(''); }
  " 2>/dev/null)
  CUSTOM_BLOCK=$(node -e "
    try {
      const c=JSON.parse(require('fs').readFileSync('.cortex/autonomy.json','utf8'));
      console.log(c.context_capacity&&c.context_capacity.block_pct||'');
    } catch(e) { console.log(''); }
  " 2>/dev/null)
  [ -n "$CUSTOM_WARN" ] && WARN_PCT="$CUSTOM_WARN"
  [ -n "$CUSTOM_BLOCK" ] && BLOCK_PCT="$CUSTOM_BLOCK"
fi

# Compare remaining percentage against thresholds
VERDICT=$(node -e "
  const r=parseFloat('${REMAINING}');
  const w=parseFloat('${WARN_PCT}');
  const b=parseFloat('${BLOCK_PCT}');
  if(isNaN(r)){console.log('ok');process.exit(0);}
  if(r<b){console.log('block');}
  else if(r<w){console.log('warn');}
  else{console.log('ok');}
" 2>/dev/null)

case "$VERDICT" in
  block)
    echo "CONTEXT CAPACITY EXCEEDED" >&2
    echo "Context window: $(node -e "console.log((100-${REMAINING}).toFixed(1))")% used (${REMAINING}% remaining)" >&2
    echo "Threshold: >${BLOCK_PCT}% remaining required to continue" >&2
    echo "Action: Run /clear or /compact to free context before continuing" >&2
    exit 2
    ;;
  warn)
    # Use JSON stdout for in-conversation warning
    USED=$(node -e "console.log((100-${REMAINING}).toFixed(1))" 2>/dev/null)
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":\"CONTEXT CAPACITY WARNING: ${USED}% used (${REMAINING}% remaining). Consider running /compact soon to preserve context quality.\"}}"
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
