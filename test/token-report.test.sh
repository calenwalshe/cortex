#!/usr/bin/env bash
# token-report.test.sh — integration tests for token-report.sh CLI
#
# Creates a temp token ledger DB with synthetic data and validates
# all 7 reports, filter flags, and error handling.
# Requires: sqlite3, bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORT="$REPO_ROOT/scripts/cortex/token-report.sh"
CREATE_SCRIPT="$REPO_ROOT/scripts/cortex/create-token-ledger.sh"

PASS_COUNT=0
FAIL_COUNT=0
TESTS=()

# ── isolated test environment ────────────────────────────────────────────────
TEST_HOME=$(mktemp -d)
export HOME="$TEST_HOME"
export TOKEN_LEDGER_DB="$TEST_HOME/test-ledger.db"

cleanup() {
  rm -rf "$TEST_HOME"
}
trap cleanup EXIT

# ── helpers ──────────────────────────────────────────────────────────────────
pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  TESTS+=("  PASS: $1")
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  TESTS+=("  FAIL: $1  ($2)")
}

# ── create schema + seed data ────────────────────────────────────────────────
bash "$CREATE_SCRIPT" > /dev/null

sqlite3 "$TOKEN_LEDGER_DB" <<'SQL'
INSERT INTO claude_turns (ts, session_id, message_id, model, input_tokens, output_tokens, cache_creation_tokens, cache_read_tokens, cost_usd, project_slug, phase, skill, remaining_pct)
VALUES
  (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), 'sess-001', 'msg-001', 'claude-sonnet-4-6', 5000, 1000, 200, 3000, 0.0450, 'cortex', '18', 'cortex-research', 95.0),
  (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), 'sess-001', 'msg-002', 'claude-sonnet-4-6', 8000, 2000, 100, 5000, 0.0690, 'cortex', '18', 'cortex-spec', 88.0),
  (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), 'sess-002', 'msg-003', 'claude-opus-4-6', 10000, 3000, 500, 7000, 0.3750, 'cortex', '19', 'cortex-bridge', 92.0),
  (strftime('%Y-%m-%dT%H:%M:%fZ', 'now', '-1 day'), 'sess-000', 'msg-004', 'claude-sonnet-4-6', 3000, 500, 50, 2000, 0.0200, 'cortex', '17', 'cortex-research', 97.0),
  (strftime('%Y-%m-%dT%H:%M:%fZ', 'now', '-1 day'), 'sess-000', 'msg-005', 'claude-sonnet-4-6', 4000, 800, 100, 2500, 0.0300, 'cortex', '17', NULL, 80.0);

INSERT INTO codex_tasks (ts, task_id, model, input_tokens, output_tokens, cached_tokens, reasoning_tokens, cost_usd, session_id, project_slug, phase)
VALUES
  (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), 'codex-001', 'o3', 5000, 2000, 1000, 500, 0.1200, 'sess-001', 'cortex', '18');
SQL

# ── Test 1: --help shows Usage ───────────────────────────────────────────────
OUTPUT=$(bash "$REPORT" --help 2>&1)
if echo "$OUTPUT" | grep -q "Usage"; then
  pass "--help shows Usage"
else
  fail "--help shows Usage" "no Usage text found"
fi

# ── Test 2: Missing DB shows error ───────────────────────────────────────────
MISSING_OUTPUT=$(TOKEN_LEDGER_DB="/tmp/nonexistent-db-$$.db" bash "$REPORT" 2>&1 || true)
if echo "$MISSING_OUTPUT" | grep -q "Token ledger not found"; then
  pass "missing DB shows actionable error"
else
  fail "missing DB shows actionable error" "got: $MISSING_OUTPUT"
fi

# ── Test 3: Full report runs without error ───────────────────────────────────
if bash "$REPORT" > /dev/null 2>&1; then
  pass "full report runs without error"
else
  fail "full report runs without error" "exit code $?"
fi

# ── Test 4: --report daily produces output ───────────────────────────────────
DAILY=$(bash "$REPORT" --report daily 2>&1)
if echo "$DAILY" | grep -q "Daily Cost"; then
  pass "--report daily shows header"
else
  fail "--report daily shows header" "no header found"
fi

# ── Test 5: --report phase produces output ───────────────────────────────────
PHASE_OUT=$(bash "$REPORT" --report phase 2>&1)
if echo "$PHASE_OUT" | grep -q "Cost by Phase"; then
  pass "--report phase shows header"
else
  fail "--report phase shows header" "no header found"
fi

# ── Test 6: --report skill produces output ───────────────────────────────────
SKILL_OUT=$(bash "$REPORT" --report skill 2>&1)
if echo "$SKILL_OUT" | grep -q "Cost by Skill"; then
  pass "--report skill shows header"
else
  fail "--report skill shows header" "no header found"
fi

# ── Test 7: --report cache produces output with hit ratio ────────────────────
CACHE_OUT=$(bash "$REPORT" --report cache 2>&1)
if echo "$CACHE_OUT" | grep -q "Cache Hit Ratio"; then
  pass "--report cache shows header"
else
  fail "--report cache shows header" "no header found"
fi

# ── Test 8: --report sessions produces output ────────────────────────────────
SESS_OUT=$(bash "$REPORT" --report sessions 2>&1)
if echo "$SESS_OUT" | grep -q "Session Ranking"; then
  pass "--report sessions shows header"
else
  fail "--report sessions shows header" "no header found"
fi

# ── Test 9: --report burndown produces output ────────────────────────────────
BURN_OUT=$(bash "$REPORT" --report burndown 2>&1)
if echo "$BURN_OUT" | grep -q "Context Burndown"; then
  pass "--report burndown shows header"
else
  fail "--report burndown shows header" "no header found"
fi

# ── Test 10: --report provider produces output ───────────────────────────────
PROV_OUT=$(bash "$REPORT" --report provider 2>&1)
if echo "$PROV_OUT" | grep -q "Cost by Provider"; then
  pass "--report provider shows header"
else
  fail "--report provider shows header" "no header found"
fi

# ── Test 11: --today filters to today only ───────────────────────────────────
TODAY_OUT=$(bash "$REPORT" --today --report daily 2>&1)
YESTERDAY=$(date -u -d "yesterday" +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d 2>/dev/null || echo "SKIP")
if [[ "$YESTERDAY" == "SKIP" ]]; then
  pass "--today filter (skipped — date arithmetic unavailable)"
elif echo "$TODAY_OUT" | grep -q "$YESTERDAY"; then
  fail "--today filter excludes yesterday" "yesterday's date found in output"
else
  pass "--today filter excludes yesterday"
fi

# ── Test 12: --phase filter narrows to specific phase ────────────────────────
PHASE_FILTER=$(bash "$REPORT" --phase 19 --report phase 2>&1)
if echo "$PHASE_FILTER" | grep -q "19"; then
  if echo "$PHASE_FILTER" | grep -q "17"; then
    fail "--phase 19 filter excludes phase 17" "phase 17 found in output"
  else
    pass "--phase 19 filter shows only phase 19"
  fi
else
  fail "--phase 19 filter shows only phase 19" "phase 19 not found"
fi

# ── Test 13: --report with unknown name shows error ──────────────────────────
UNKNOWN_OUT=$(bash "$REPORT" --report bogus 2>&1 || true)
if echo "$UNKNOWN_OUT" | grep -q "Unknown report"; then
  pass "unknown report name shows error"
else
  fail "unknown report name shows error" "no error message"
fi

# ── Test 14: daily report shows actual data rows ─────────────────────────────
DAILY_DATA=$(bash "$REPORT" --report daily 2>&1)
if echo "$DAILY_DATA" | grep -q "0\."; then
  pass "daily report contains cost data"
else
  fail "daily report contains cost data" "no cost values found"
fi

# ── Test 15: cache report shows percentage ───────────────────────────────────
CACHE_DATA=$(bash "$REPORT" --report cache 2>&1)
if echo "$CACHE_DATA" | grep -q "%"; then
  pass "cache report shows hit ratio percentage"
else
  fail "cache report shows hit ratio percentage" "no % found"
fi

# ── summary ──────────────────────────────────────────────────────────────────
echo ""
echo "token-report.test.sh results:"
for t in "${TESTS[@]}"; do
  echo "$t"
done
echo ""
echo "$PASS_COUNT PASS, $FAIL_COUNT FAIL ($(( PASS_COUNT + FAIL_COUNT )) total)"

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo "ALL PASS"
  exit 0
else
  echo "SOME FAILURES"
  exit 1
fi
