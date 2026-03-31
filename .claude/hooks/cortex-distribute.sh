#!/usr/bin/env bash
# cortex-distribute.sh — PostToolUse hook dispatcher for Cortex artifact distribution
# Reads stdin JSON, matches path patterns, delegates to Python distributor.
# Always exits 0 — never blocks Claude.
set -euo pipefail

DISTRIBUTE_PY="$HOME/.claude/hooks/cortex-distribute.py"
LOG="$HOME/.claude/hooks/logs/cortex-distribute.log"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

log() {
  echo "[$TIMESTAMP] $*" >> "$LOG"
}

# Read stdin; bail silently on empty input
STDIN_DATA=$(cat)
if [ -z "$STDIN_DATA" ]; then
  exit 0
fi

# Extract file_path and content; bail silently on parse failure
FILE_PATH=$(echo "$STDIN_DATA" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

CONTENT=$(echo "$STDIN_DATA" | jq -r '.tool_input.content // empty' 2>/dev/null || true)
if [ -z "$CONTENT" ]; then
  exit 0
fi

# Match path patterns — determine surfaces
SURFACES=""
if echo "$FILE_PATH" | grep -q "docs/cortex/recipes/"; then
  SURFACES="email,notebooklm"
elif echo "$FILE_PATH" | grep -q "docs/cortex/research/"; then
  SURFACES="notebooklm"
fi

# No match — exit immediately (< 5ms overhead)
if [ -z "$SURFACES" ]; then
  log "early-exit: no match for $FILE_PATH"
  exit 0
fi

# Derive human-readable title from filename
BASENAME=$(basename "$FILE_PATH" .md)
# Strip leading timestamp prefix (e.g. 20260331T063000Z- or YYYYMMDDTHHMMSSZ-)
STRIPPED="${BASENAME#[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z-}"
# Replace hyphens/underscores with spaces, title-case each word
TITLE=$(echo "$STRIPPED" | tr '-' ' ' | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')

# Write content to tmpfile for Python (avoids arg length limits)
TMPFILE=$(mktemp /tmp/cortex-distribute-XXXXXX)
printf '%s' "$CONTENT" > "$TMPFILE"

log "dispatch: file=$FILE_PATH surfaces=$SURFACES title=$TITLE"

# Delegate to Python distributor (async-safe — this script is called async:true)
python3 "$DISTRIBUTE_PY" \
  --file-path "$FILE_PATH" \
  --tmpfile "$TMPFILE" \
  --surfaces "$SURFACES" \
  --title "$TITLE" \
  2>> "$LOG" || log "error: python distributor failed (see above)"

exit 0
