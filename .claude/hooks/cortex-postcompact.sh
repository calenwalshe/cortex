#!/usr/bin/env bash
# cortex-postcompact.sh
# PostCompact hook — write compact summary and refresh next-prompt.md

set -uo pipefail

CORTEX_DIR="${CLAUDE_PROJECT_DIR}/.cortex"
COMPACTION_DIR="$CORTEX_DIR/compaction"
HANDOFFS_DIR="${CLAUDE_PROJECT_DIR}/docs/cortex/handoffs"
STATE_JSON="$CORTEX_DIR/state.json"

mkdir -p "$HANDOFFS_DIR" 2>/dev/null || exit 0

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
SUMMARY="$HANDOFFS_DIR/last-compact-summary.md"
NEXT_PROMPT="$HANDOFFS_DIR/next-prompt.md"

# Read state for summary generation
MODE=$(jq -r '.mode // "clarify"' "$STATE_JSON" 2>/dev/null || echo "clarify")
SLUG=$(jq -r '.slug // ""' "$STATE_JSON" 2>/dev/null || echo "")
CONTRACT=$(jq -r '.active_contract // ""' "$STATE_JSON" 2>/dev/null || echo "")

# Find most recent precompact snapshot for reference
LATEST_SNAPSHOT=$(ls -t "$COMPACTION_DIR"/precompact-*.md 2>/dev/null | head -1 || echo "")

# Write last-compact-summary.md
{
  echo "# Last Compact Summary: $TIMESTAMP"
  echo ""
  echo "**Compaction occurred at:** $TIMESTAMP"
  echo "**Active slug:** ${SLUG:-(none)}"
  echo "**Mode at compaction:** $MODE"
  echo "**Active contract:** ${CONTRACT:-(none)}"
  echo ""
  if [[ -n "$LATEST_SNAPSHOT" ]]; then
    echo "**Pre-compaction snapshot:** $LATEST_SNAPSHOT"
  fi
  echo ""
  echo "Run /cortex-status to reconstruct full working state."
} > "$SUMMARY" 2>/dev/null || exit 0

# Refresh next-prompt.md
{
  echo "We are working on ${SLUG:-(unknown slug)} in $MODE mode."
  if [[ -n "$CONTRACT" ]]; then
    echo "The active contract is at $CONTRACT."
  fi
  echo "Context was compacted at $TIMESTAMP."
  echo "Run /cortex-status to see the full current state and next recommended action."
} > "$NEXT_PROMPT" 2>/dev/null || exit 0

exit 0
