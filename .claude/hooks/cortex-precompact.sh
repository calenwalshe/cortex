#!/usr/bin/env bash
# cortex-precompact.sh
# PreCompact hook — write snapshot before context compaction
# Cannot block compaction. Runs synchronously before /compact executes.

set -uo pipefail

CORTEX_DIR="${CLAUDE_PROJECT_DIR}/.cortex"
COMPACTION_DIR="$CORTEX_DIR/compaction"
CURRENT_STATE="${CLAUDE_PROJECT_DIR}/docs/cortex/handoffs/current-state.md"
STATE_JSON="$CORTEX_DIR/state.json"

mkdir -p "$COMPACTION_DIR" 2>/dev/null || exit 0

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
SNAPSHOT="$COMPACTION_DIR/precompact-$TIMESTAMP.md"

# Write snapshot combining current-state.md and state.json
{
  echo "# Pre-Compaction Snapshot: $TIMESTAMP"
  echo ""
  if [[ -f "$CURRENT_STATE" ]]; then
    cat "$CURRENT_STATE"
  else
    echo "(no current-state.md at compaction time)"
  fi
  echo ""
  echo "## state.json"
  echo '```json'
  if [[ -f "$STATE_JSON" ]]; then
    cat "$STATE_JSON"
  else
    echo '{}'
  fi
  echo '```'
} > "$SNAPSHOT" 2>/dev/null || exit 0

exit 0
