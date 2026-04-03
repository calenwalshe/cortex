#!/usr/bin/env bash
# token-report.sh — CLI query tool for the Cortex token ledger
#
# Runs formatted SQL reports against ~/.cortex/token-ledger.db.
# Optionally ATTACHes ~/.power-search/usage.db for cross-source joins.
#
# Usage:
#   token-report.sh [OPTIONS]
#
# Options:
#   --today           Show today's data only
#   --phase PHASE     Filter by GSD phase (e.g. "20")
#   --session ID      Filter by session ID
#   --report NAME     Run a single report (daily|phase|skill|cache|sessions|burndown|provider)
#   --help            Show this help
#
# Environment:
#   TOKEN_LEDGER_DB   Override DB path (default: ~/.cortex/token-ledger.db)

set -euo pipefail

DB_PATH="${TOKEN_LEDGER_DB:-$HOME/.cortex/token-ledger.db}"
PS_DB="$HOME/.power-search/usage.db"

# ── argument parsing ─────────────────────────────────────────────────────────
FILTER_TODAY=""
FILTER_PHASE=""
FILTER_SESSION=""
REPORT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --today)    FILTER_TODAY=1; shift ;;
    --phase)    FILTER_PHASE="$2"; shift 2 ;;
    --session)  FILTER_SESSION="$2"; shift 2 ;;
    --report)   REPORT="$2"; shift 2 ;;
    --help|-h)
      sed -n '2,/^[^#]/{ /^#/s/^# \?//p }' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

# ── DB existence check ───────────────────────────────────────────────────────
if [[ ! -f "$DB_PATH" ]]; then
  echo "Error: Token ledger not found at $DB_PATH" >&2
  echo "" >&2
  echo "Create it with:" >&2
  echo "  bash scripts/cortex/create-token-ledger.sh" >&2
  exit 1
fi

# ── ATTACH power-search DB if available ──────────────────────────────────────
ATTACH_PS=""
if [[ -f "$PS_DB" ]]; then
  ATTACH_PS="ATTACH DATABASE '$PS_DB' AS ps;"
fi

# ── filter helpers ───────────────────────────────────────────────────────────
where_date() {
  local col="${1:-ts}"
  if [[ -n "$FILTER_TODAY" ]]; then
    echo "AND date($col) = date('now')"
  fi
}

where_phase() {
  local col="${1:-phase}"
  if [[ -n "$FILTER_PHASE" ]]; then
    echo "AND $col = '$FILTER_PHASE'"
  fi
}

where_session() {
  local col="${1:-session_id}"
  if [[ -n "$FILTER_SESSION" ]]; then
    echo "AND $col = '$FILTER_SESSION'"
  fi
}

# ── report functions ─────────────────────────────────────────────────────────

report_daily() {
  echo "═══ Daily Cost Summary ═══"
  echo ""
  sqlite3 -header -column "$DB_PATH" <<SQL
${ATTACH_PS}
SELECT
  date(ts) AS date,
  COUNT(*) AS turns,
  SUM(input_tokens) AS input_tok,
  SUM(output_tokens) AS output_tok,
  printf('%.4f', SUM(cost_usd)) AS cost_usd
FROM claude_turns
WHERE 1=1
  $(where_date ts)
  $(where_phase)
  $(where_session)
GROUP BY date(ts)
ORDER BY date DESC
LIMIT 30;
SQL
  echo ""
}

report_phase() {
  echo "═══ Cost by Phase ═══"
  echo ""
  sqlite3 -header -column "$DB_PATH" <<SQL
SELECT
  COALESCE(phase, '(none)') AS phase,
  COUNT(*) AS turns,
  SUM(input_tokens) AS input_tok,
  SUM(output_tokens) AS output_tok,
  SUM(cache_read_tokens) AS cache_read,
  printf('%.4f', SUM(cost_usd)) AS cost_usd
FROM claude_turns
WHERE 1=1
  $(where_date ts)
  $(where_phase)
  $(where_session)
GROUP BY phase
ORDER BY SUM(cost_usd) DESC;
SQL
  echo ""
}

report_skill() {
  echo "═══ Cost by Skill ═══"
  echo ""
  sqlite3 -header -column "$DB_PATH" <<SQL
SELECT
  COALESCE(skill, '(none)') AS skill,
  COUNT(*) AS turns,
  SUM(input_tokens) AS input_tok,
  SUM(output_tokens) AS output_tok,
  printf('%.4f', SUM(cost_usd)) AS cost_usd
FROM claude_turns
WHERE 1=1
  $(where_date ts)
  $(where_phase)
  $(where_session)
GROUP BY skill
ORDER BY SUM(cost_usd) DESC
LIMIT 20;
SQL
  echo ""
}

report_cache() {
  echo "═══ Cache Hit Ratio ═══"
  echo ""
  sqlite3 -header -column "$DB_PATH" <<SQL
SELECT
  date(ts) AS date,
  SUM(cache_read_tokens) AS cache_read,
  SUM(cache_creation_tokens) AS cache_write,
  SUM(input_tokens) AS total_input,
  CASE WHEN SUM(input_tokens) > 0
    THEN printf('%.1f%%', 100.0 * SUM(cache_read_tokens) / SUM(input_tokens))
    ELSE '0.0%'
  END AS hit_ratio
FROM claude_turns
WHERE 1=1
  $(where_date ts)
  $(where_phase)
  $(where_session)
GROUP BY date(ts)
ORDER BY date DESC
LIMIT 30;
SQL
  echo ""
}

report_sessions() {
  echo "═══ Session Ranking (by cost) ═══"
  echo ""
  sqlite3 -header -column "$DB_PATH" <<SQL
SELECT
  session_id,
  COUNT(*) AS turns,
  SUM(input_tokens) AS input_tok,
  SUM(output_tokens) AS output_tok,
  printf('%.4f', SUM(cost_usd)) AS cost_usd,
  MIN(ts) AS started,
  MAX(ts) AS last_turn
FROM claude_turns
WHERE 1=1
  $(where_date ts)
  $(where_phase)
  $(where_session)
GROUP BY session_id
ORDER BY SUM(cost_usd) DESC
LIMIT 20;
SQL
  echo ""
}

report_burndown() {
  echo "═══ Context Burndown ═══"
  echo ""
  sqlite3 -header -column "$DB_PATH" <<SQL
SELECT
  ts,
  session_id,
  remaining_pct,
  SUM(input_tokens + output_tokens) AS total_tokens,
  printf('%.4f', cost_usd) AS cost_usd
FROM claude_turns
WHERE remaining_pct IS NOT NULL
  $(where_date ts)
  $(where_phase)
  $(where_session)
ORDER BY ts DESC
LIMIT 50;
SQL
  echo ""
}

report_provider() {
  echo "═══ Cost by Provider/Model ═══"
  echo ""
  sqlite3 -header -column "$DB_PATH" <<SQL
SELECT
  model,
  COUNT(*) AS turns,
  SUM(input_tokens) AS input_tok,
  SUM(output_tokens) AS output_tok,
  printf('%.4f', SUM(cost_usd)) AS cost_usd
FROM claude_turns
WHERE 1=1
  $(where_date ts)
  $(where_phase)
  $(where_session)
GROUP BY model
ORDER BY SUM(cost_usd) DESC;
SQL
  -- Cross-source: power-search costs if available
  if [[ -f "$PS_DB" ]]; then
    echo ""
    echo "── Power-Search Costs ──"
    echo ""
    sqlite3 -header -column "$DB_PATH" <<SQL
${ATTACH_PS}
SELECT
  ps.provider,
  COUNT(*) AS calls,
  printf('%.4f', SUM(ps.cost_usd)) AS cost_usd
FROM ps.usage ps
GROUP BY ps.provider
ORDER BY SUM(ps.cost_usd) DESC;
SQL
  fi
  echo ""
}

# ── main ─────────────────────────────────────────────────────────────────────

run_report() {
  case "$1" in
    daily)    report_daily ;;
    phase)    report_phase ;;
    skill)    report_skill ;;
    cache)    report_cache ;;
    sessions) report_sessions ;;
    burndown) report_burndown ;;
    provider) report_provider ;;
    *)
      echo "Unknown report: $1" >&2
      echo "Available: daily, phase, skill, cache, sessions, burndown, provider" >&2
      exit 1
      ;;
  esac
}

if [[ -n "$REPORT" ]]; then
  run_report "$REPORT"
else
  echo "╔══════════════════════════════════════════╗"
  echo "║       Cortex Token Ledger Report         ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  if [[ -n "$FILTER_TODAY" ]]; then echo "Filter: today only"; fi
  if [[ -n "$FILTER_PHASE" ]]; then echo "Filter: phase=$FILTER_PHASE"; fi
  if [[ -n "$FILTER_SESSION" ]]; then echo "Filter: session=$FILTER_SESSION"; fi
  if [[ -n "$FILTER_TODAY$FILTER_PHASE$FILTER_SESSION" ]]; then echo ""; fi

  report_daily
  report_phase
  report_skill
  report_cache
  report_sessions
  report_burndown
  report_provider
fi
