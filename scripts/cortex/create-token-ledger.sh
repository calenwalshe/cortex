#!/usr/bin/env bash
# create-token-ledger.sh — idempotent token ledger SQLite schema migration
#
# Usage: create-token-ledger.sh
#
# Creates ~/.cortex/token-ledger.db with 4 tables for Claude/Codex token
# tracking. Safe to re-run — all DDL uses IF NOT EXISTS.
#
# Environment:
#   TOKEN_LEDGER_DB  Override DB path (default: ~/.cortex/token-ledger.db)

set -euo pipefail

DB_PATH="${TOKEN_LEDGER_DB:-$HOME/.cortex/token-ledger.db}"

# ── ensure parent directory exists ───────────────────────────────────────────
mkdir -p "$(dirname "$DB_PATH")"

# ── run DDL ──────────────────────────────────────────────────────────────────
sqlite3 "$DB_PATH" <<'SQL'

-- Enable WAL for concurrent read/write from hooks
PRAGMA journal_mode=WAL;

-- Per-turn Claude tracking
CREATE TABLE IF NOT EXISTS claude_turns (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  session_id TEXT NOT NULL,
  message_id TEXT NOT NULL UNIQUE,
  model TEXT NOT NULL,
  input_tokens INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  cache_creation_tokens INTEGER NOT NULL DEFAULT 0,
  cache_read_tokens INTEGER NOT NULL DEFAULT 0,
  cost_usd REAL NOT NULL DEFAULT 0.0,
  project_slug TEXT,
  cwd TEXT,
  phase TEXT,
  skill TEXT,
  remaining_pct REAL
);

-- Per-task Codex tracking
CREATE TABLE IF NOT EXISTS codex_tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  task_id TEXT NOT NULL,
  model TEXT NOT NULL,
  input_tokens INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  cached_tokens INTEGER NOT NULL DEFAULT 0,
  reasoning_tokens INTEGER NOT NULL DEFAULT 0,
  cost_usd REAL NOT NULL DEFAULT 0.0,
  session_id TEXT,
  project_slug TEXT,
  phase TEXT,
  task_type TEXT,
  plan_file TEXT,
  exit_code INTEGER,
  elapsed_ms INTEGER
);

-- Session metadata
CREATE TABLE IF NOT EXISTS sessions (
  session_id TEXT PRIMARY KEY,
  started_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
  ended_at TEXT,
  project_slug TEXT,
  model TEXT,
  compacted INTEGER NOT NULL DEFAULT 0,
  total_input INTEGER NOT NULL DEFAULT 0,
  total_output INTEGER NOT NULL DEFAULT 0,
  total_cost REAL NOT NULL DEFAULT 0.0
);

-- Materialized daily rollups
CREATE TABLE IF NOT EXISTS daily_rollup (
  date TEXT NOT NULL,
  provider TEXT NOT NULL,
  model TEXT NOT NULL,
  project_slug TEXT NOT NULL DEFAULT '',
  phase TEXT NOT NULL DEFAULT '',
  input_tokens INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  cost_usd REAL NOT NULL DEFAULT 0.0,
  turn_count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (date, provider, model, project_slug, phase)
);

-- ── indexes ─────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_claude_turns_session ON claude_turns(session_id);
CREATE INDEX IF NOT EXISTS idx_claude_turns_ts ON claude_turns(ts);
CREATE INDEX IF NOT EXISTS idx_claude_turns_phase ON claude_turns(phase);
CREATE INDEX IF NOT EXISTS idx_claude_turns_skill ON claude_turns(skill);
CREATE INDEX IF NOT EXISTS idx_claude_turns_project ON claude_turns(project_slug);
CREATE INDEX IF NOT EXISTS idx_codex_tasks_session ON codex_tasks(session_id);
CREATE INDEX IF NOT EXISTS idx_codex_tasks_ts ON codex_tasks(ts);
CREATE INDEX IF NOT EXISTS idx_codex_tasks_phase ON codex_tasks(phase);

SQL

# ── confirmation ─────────────────────────────────────────────────────────────
TABLE_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name IN ('claude_turns','codex_tasks','sessions','daily_rollup')")
INDEX_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'")

echo "token-ledger.db: $TABLE_COUNT tables, $INDEX_COUNT indexes (WAL mode)"
