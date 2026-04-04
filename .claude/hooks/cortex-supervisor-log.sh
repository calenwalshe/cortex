#!/usr/bin/env bash
# cortex-supervisor-log.sh — Shared logging function for Cortex hooks
# Source this file from any hook: . "$(dirname "$0")/cortex-supervisor-log.sh"
# Then call: supervisor_log "hook_name" ["event_type"] ["extra_json_fields"]

supervisor_log() {
  local hook="${1:-unknown}"
  local event="${2:-hook_fire}"
  local extra="${3:-}"
  local logfile="${CLAUDE_PROJECT_DIR:-.}/.cortex/supervisor.jsonl"
  local ts
  ts=$(date -u +"%Y%m%dT%H%M%SZ")
  local slug
  slug=$(jq -r '.slug // ""' "${CLAUDE_PROJECT_DIR:-.}/.cortex/state.json" 2>/dev/null || echo "")
  local mode
  mode=$(jq -r '.mode // ""' "${CLAUDE_PROJECT_DIR:-.}/.cortex/state.json" 2>/dev/null || echo "")

  local entry="{\"ts\":\"$ts\",\"event\":\"$event\",\"hook\":\"$hook\",\"slug\":\"$slug\",\"mode\":\"$mode\"${extra:+,$extra}}"
  echo "$entry" >> "$logfile" 2>/dev/null || true
}
