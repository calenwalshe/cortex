#!/usr/bin/env bash
# cortex-precompact.sh
# PreCompact hook — write enriched snapshot before context compaction
# Captures metadata + session intelligence from Cortex artifacts for fact extraction.

set -uo pipefail

CORTEX_DIR="${CLAUDE_PROJECT_DIR}/.cortex"
COMPACTION_DIR="$CORTEX_DIR/compaction"
CURRENT_STATE="${CLAUDE_PROJECT_DIR}/docs/cortex/handoffs/current-state.md"
STATE_JSON="$CORTEX_DIR/state.json"
DECISIONS_MD="${CLAUDE_PROJECT_DIR}/docs/cortex/handoffs/decisions.md"
PLANNING_STATE="${CLAUDE_PROJECT_DIR}/.planning/STATE.md"

mkdir -p "$COMPACTION_DIR" 2>/dev/null || exit 0

TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
SNAPSHOT="$COMPACTION_DIR/precompact-$TIMESTAMP.md"

SLUG=$(jq -r '.slug // ""' "$STATE_JSON" 2>/dev/null || echo "")

{
  echo "# Pre-Compaction Snapshot: $TIMESTAMP"
  echo ""

  # ── Section 1: Cortex metadata ──────────────────────────────────────────
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
  echo ""

  # ── Section 2: Decisions log ────────────────────────────────────────────
  echo "## Decisions"
  if [[ -f "$DECISIONS_MD" ]]; then
    cat "$DECISIONS_MD"
  else
    echo "(no decisions.md)"
  fi
  echo ""

  # ── Section 3: GSD accumulated context ──────────────────────────────────
  echo "## GSD Accumulated Context"
  if [[ -f "$PLANNING_STATE" ]]; then
    # Extract Accumulated Context section from STATE.md
    sed -n '/^## Accumulated Context/,/^## [^A]/p' "$PLANNING_STATE" | head -60
  else
    echo "(no .planning/STATE.md)"
  fi
  echo ""

  # ── Section 4: Recent CONTEXT.md decisions ──────────────────────────────
  echo "## Phase Context Decisions"
  for ctx_file in $(find "${CLAUDE_PROJECT_DIR}/.planning/phases" -name "*-CONTEXT.md" 2>/dev/null | sort -r | head -3); do
    echo "### $(basename "$ctx_file")"
    # Extract decisions section only
    sed -n '/<decisions>/,/<\/decisions>/p' "$ctx_file" 2>/dev/null | head -40
    echo ""
  done

  # ── Section 5: Recent git history ───────────────────────────────────────
  echo "## Recent Git History"
  git -C "$CLAUDE_PROJECT_DIR" log --oneline -20 2>/dev/null || echo "(no git history)"
  echo ""

} > "$SNAPSHOT" 2>/dev/null || exit 0

exit 0
