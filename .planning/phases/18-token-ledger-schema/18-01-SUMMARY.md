---
phase: 18-token-ledger-schema
plan: 01
subsystem: token-ledger
tags: [sqlite, schema, migration, token-tracking]
dependency_graph:
  requires: []
  provides: [token-ledger-db, schema-migration-script]
  affects: [19-posttooluse-hook, 20-token-report-cli]
tech_stack:
  added: [sqlite3-cli]
  patterns: [idempotent-migration, env-var-override, WAL-mode]
key_files:
  created:
    - scripts/cortex/create-token-ledger.sh
    - scripts/cortex/test-token-ledger.sh
  modified: []
decisions:
  - WAL mode enabled at creation time for concurrent hook writes
  - TOKEN_LEDGER_DB env var override for test isolation
  - No SQLite triggers for daily_rollup (deferred per context)
  - bash + sqlite3 CLI chosen over Node.js for migration script (simpler, no deps)
metrics:
  duration: 4min
  completed: 2026-04-03
  tasks: 2
  files: 2
---

# Phase 18 Plan 01: Token Ledger Schema Summary

SQLite schema migration creating ~/.cortex/token-ledger.db with 4 tables (claude_turns, codex_tasks, sessions, daily_rollup), 8 indexes, WAL mode, and compound PK upsert support -- validated by 23 integration tests.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create token ledger schema migration script | f34db34 | scripts/cortex/create-token-ledger.sh |
| 2 | Validate schema with integration test | 3cd82cc | scripts/cortex/test-token-ledger.sh |

## What Was Built

### Task 1: Schema Migration Script
`scripts/cortex/create-token-ledger.sh` -- a bash script that:
- Creates `~/.cortex/token-ledger.db` (or path from `TOKEN_LEDGER_DB` env var)
- Enables WAL journal mode for concurrent read/write
- Creates 4 tables matching the research dossier schema exactly:
  - `claude_turns` (15 columns) -- per-turn Claude token tracking with session_id, message_id UNIQUE, model, input/output/cache tokens, cost_usd, phase, skill, remaining_pct
  - `codex_tasks` (16 columns) -- per-task Codex tracking with task_id, model, input/output/cached/reasoning tokens, cost_usd, phase, task_type, exit_code, elapsed_ms
  - `sessions` (9 columns) -- session metadata with running totals (total_input, total_output, total_cost), compacted flag
  - `daily_rollup` (9 columns) -- materialized aggregates with compound PK (date, provider, model, project_slug, phase) for upsert
- Creates 8 indexes for query performance
- Fully idempotent via CREATE TABLE/INDEX IF NOT EXISTS

### Task 2: Integration Test Suite
`scripts/cortex/test-token-ledger.sh` -- 23 tests covering:
- Table existence (4 tests)
- Column counts via PRAGMA table_info (4 tests)
- Index count and individual index existence (9 tests)
- UNIQUE constraint on claude_turns.message_id
- Compound PK upsert on daily_rollup
- WAL journal mode
- Idempotency (re-run exits 0)
- Sessions PK enforcement
- Default timestamp generation

All tests run against an isolated temp DB with trap-based cleanup.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Installed sqlite3 CLI**
- **Found during:** Task 1 verification
- **Issue:** sqlite3 command not found (libsqlite3-0 installed but not the CLI tool)
- **Fix:** `sudo apt-get install -y sqlite3`
- **Files modified:** none (system package)

**2. [Rule 1 - Bug] Fixed pipefail interference with constraint tests**
- **Found during:** Task 2 verification
- **Issue:** `set -euo pipefail` caused sqlite3 error output piped to grep to fail silently -- the non-zero exit of sqlite3 propagated through pipefail, making the `if` branch take the else path even when grep matched
- **Fix:** Capture stderr into a variable with `|| true` before grepping, avoiding the pipe
- **Files modified:** scripts/cortex/test-token-ledger.sh
- **Commit:** 3cd82cc

## Verification Results

All 5 verification criteria pass:
1. `bash scripts/cortex/create-token-ledger.sh` exits 0
2. `.tables` shows: claude_turns codex_tasks daily_rollup sessions
3. Index count returns 8
4. `bash scripts/cortex/test-token-ledger.sh` exits 0 (23/23 pass)
5. Re-running create script exits 0 (idempotent)

## Known Stubs

None -- all tables, indexes, and constraints are fully implemented.

## Self-Check: PASSED

- [x] scripts/cortex/create-token-ledger.sh exists
- [x] scripts/cortex/test-token-ledger.sh exists
- [x] .planning/phases/18-token-ledger-schema/18-01-SUMMARY.md exists
- [x] Commit f34db34 exists
- [x] Commit 3cd82cc exists
