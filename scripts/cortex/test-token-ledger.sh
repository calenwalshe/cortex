#!/usr/bin/env bash
# test-token-ledger.sh — integration tests for token ledger schema
#
# Validates all 4 tables, column counts, indexes, constraints, WAL mode,
# and idempotency against an isolated temp DB.

set -euo pipefail

TEST_DB="/tmp/test-token-ledger-$$.db"
PASS_COUNT=0
FAIL_COUNT=0
TESTS=()

# ── cleanup trap ─────────────────────────────────────────────────────────────
cleanup() {
  rm -f "$TEST_DB" "${TEST_DB}-wal" "${TEST_DB}-shm"
}
trap cleanup EXIT

# ── helpers ──────────────────────────────────────────────────────────────────
pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  TESTS+=("  PASS: $1")
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  TESTS+=("  FAIL: $1")
}

# ── resolve create script relative to this script ───────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREATE_SCRIPT="$SCRIPT_DIR/create-token-ledger.sh"

if [[ ! -x "$CREATE_SCRIPT" ]]; then
  echo "FAIL: create-token-ledger.sh not found or not executable at $CREATE_SCRIPT" >&2
  exit 1
fi

# ── run create script against temp DB ────────────────────────────────────────
TOKEN_LEDGER_DB="$TEST_DB" bash "$CREATE_SCRIPT" > /dev/null

# ── test: table existence (4 checks) ────────────────────────────────────────
for table in claude_turns codex_tasks sessions daily_rollup; do
  if sqlite3 "$TEST_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='$table'" | grep -q "$table"; then
    pass "table $table exists"
  else
    fail "Missing table: $table"
  fi
done

# ── test: column counts via PRAGMA table_info ────────────────────────────────
check_columns() {
  local table="$1" expected="$2"
  local actual
  actual=$(sqlite3 "$TEST_DB" "PRAGMA table_info($table)" | wc -l)
  if [ "$actual" -eq "$expected" ]; then
    pass "$table has $expected columns"
  else
    fail "$table expected $expected columns, got $actual"
  fi
}

check_columns claude_turns 15
check_columns codex_tasks 16
check_columns sessions 9
check_columns daily_rollup 9

# ── test: index count ────────────────────────────────────────────────────────
INDEX_COUNT=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'")
if [ "$INDEX_COUNT" -eq 8 ]; then
  pass "8 indexes exist"
else
  fail "Expected 8 indexes, got $INDEX_COUNT"
fi

# ── test: specific indexes exist ─────────────────────────────────────────────
for idx in idx_claude_turns_session idx_claude_turns_ts idx_claude_turns_phase \
           idx_claude_turns_skill idx_claude_turns_project \
           idx_codex_tasks_session idx_codex_tasks_ts idx_codex_tasks_phase; do
  if sqlite3 "$TEST_DB" "SELECT name FROM sqlite_master WHERE type='index' AND name='$idx'" | grep -q "$idx"; then
    pass "index $idx exists"
  else
    fail "Missing index: $idx"
  fi
done

# ── test: UNIQUE constraint on message_id ────────────────────────────────────
sqlite3 "$TEST_DB" "INSERT INTO claude_turns (session_id, message_id, model) VALUES ('s1', 'msg1', 'opus')"
DUP_ERR=$(sqlite3 "$TEST_DB" "INSERT INTO claude_turns (session_id, message_id, model) VALUES ('s1', 'msg1', 'opus')" 2>&1 || true)
if echo "$DUP_ERR" | grep -qi "unique"; then
  pass "message_id UNIQUE constraint enforced"
else
  fail "message_id UNIQUE constraint missing"
fi

# ── test: daily_rollup compound PK upsert ────────────────────────────────────
sqlite3 "$TEST_DB" "INSERT INTO daily_rollup (date, provider, model, project_slug, phase, turn_count) VALUES ('2026-04-01', 'anthropic', 'opus', 'cortex', '18', 5)"
sqlite3 "$TEST_DB" "INSERT OR REPLACE INTO daily_rollup (date, provider, model, project_slug, phase, turn_count) VALUES ('2026-04-01', 'anthropic', 'opus', 'cortex', '18', 10)"
RESULT=$(sqlite3 "$TEST_DB" "SELECT turn_count FROM daily_rollup WHERE date='2026-04-01'")
if [ "$RESULT" = "10" ]; then
  pass "daily_rollup compound PK upsert works"
else
  fail "Upsert failed: expected 10, got $RESULT"
fi

# ── test: WAL mode ───────────────────────────────────────────────────────────
WAL=$(sqlite3 "$TEST_DB" "PRAGMA journal_mode")
if [ "$WAL" = "wal" ]; then
  pass "WAL journal mode active"
else
  fail "Expected WAL mode, got $WAL"
fi

# ── test: idempotency (run create script again) ──────────────────────────────
if TOKEN_LEDGER_DB="$TEST_DB" bash "$CREATE_SCRIPT" > /dev/null 2>&1; then
  pass "idempotent re-run exits 0"
else
  fail "second run of create script failed"
fi

# ── test: session PK ────────────────────────────────────────────────────────
sqlite3 "$TEST_DB" "INSERT INTO sessions (session_id, model) VALUES ('sess-1', 'opus')"
PK_ERR=$(sqlite3 "$TEST_DB" "INSERT INTO sessions (session_id, model) VALUES ('sess-1', 'opus')" 2>&1 || true)
if echo "$PK_ERR" | grep -qi "unique\|constraint"; then
  pass "sessions PK enforced"
else
  fail "sessions PK not enforced"
fi

# ── test: default timestamps ────────────────────────────────────────────────
TS=$(sqlite3 "$TEST_DB" "INSERT INTO claude_turns (session_id, message_id, model) VALUES ('s2', 'msg2', 'opus'); SELECT ts FROM claude_turns WHERE message_id='msg2'")
if echo "$TS" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T'; then
  pass "claude_turns ts default works"
else
  fail "claude_turns ts default: got '$TS'"
fi

# ── summary ──────────────────────────────────────────────────────────────────
TOTAL=$((PASS_COUNT + FAIL_COUNT))
echo ""
for line in "${TESTS[@]}"; do
  echo "$line"
done
echo ""
if [ "$FAIL_COUNT" -eq 0 ]; then
  echo "PASS: $PASS_COUNT/$TOTAL tests passed"
  exit 0
else
  echo "FAIL: $PASS_COUNT/$TOTAL passed, $FAIL_COUNT failed"
  exit 1
fi
