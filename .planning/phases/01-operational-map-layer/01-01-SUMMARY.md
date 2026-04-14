---
phase: 01-operational-map-layer
plan: "01"
subsystem: operational-indexer
tags: [python, jsonl, posttooluse, hook, ledger, tdd, pytest]

requires: []
provides:
  - "scripts/cortex/operational-indexer.py --hook mode: filters Edit/Write PostToolUse events into rolling JSONL ledger"
  - "test/test_operational_indexer.py: 24 pytest tests covering AC1-AC4"
affects:
  - 01-02  # --summary mode reads the ledger written by --hook
  - 01-03  # hook registration in settings.json / session-start.sh

tech-stack:
  added: []
  patterns:
    - "JSONL rolling ledger with synchronous prune-at-append (no cron)"
    - "PostToolUse stdin JSON parsing with select() timeout guard"
    - "Soft-fail reads (slug, state.json, ledger) — all default to empty string"

key-files:
  created:
    - scripts/cortex/operational-indexer.py
    - test/test_operational_indexer.py
  modified: []

key-decisions:
  - "Filter Edit/Write at write time (--hook), not at read time (--summary): keeps ledger clean"
  - "Prune synchronously at append time, not via cron: bounded without scheduled jobs"
  - "--ledger and --state flags added for test isolation (not just testing convenience — required for AC validators)"
  - "timezone-aware datetime.now(timezone.utc) used to avoid Python 3.12 deprecation warning"
  - "select() timeout of 2s on stdin to match structural-indexer.py pattern"

patterns-established:
  - "TDD RED-GREEN on subprocess-invoked Python hooks: write tests that run script as subprocess, assert ledger state"
  - "Prune-at-append pattern: read all lines, append, slice to -MAX_ENTRIES, rewrite"

duration: 18min
completed: 2026-04-14
---

# Phase 01 Plan 01: operational-indexer --hook mode Summary

**PostToolUse hook that filters Edit/Write events into a 500-entry rolling JSONL ledger with schema {timestamp, session_id, file_path, tool_name, slug}, implemented via TDD with 24 passing tests.**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-04-14T00:00:00Z
- **Completed:** 2026-04-14T00:18:00Z
- **Tasks:** 2 (RED + GREEN; REFACTOR skipped — no cleanup needed)
- **Files modified:** 2

## Accomplishments

- Wrote 24 failing pytest tests covering all 4 acceptance criteria (RED)
- Implemented operational-indexer.py --hook mode with correct filter, schema, prune, and exit-0 guarantee (GREEN)
- Verified schema via real ledger tail, prune boundary (502 → 500), Bash non-append, and exit code mechanically

## Task Commits

Each TDD phase committed atomically:

1. **RED — failing tests** - `72ee370` (test)
2. **GREEN — implementation** - `7171b41` (feat)

## Files Created/Modified

- `/home/agent/projects/cortex/scripts/cortex/operational-indexer.py` — --hook mode implementation + --summary stub
- `/home/agent/projects/cortex/test/test_operational_indexer.py` — 24 pytest tests, AC1–AC4

## Decisions Made

- `--ledger` and `--state` path override flags added (beyond minimal spec) to enable proper test isolation via subprocess invocation
- `datetime.datetime.now(datetime.timezone.utc)` used instead of deprecated `utcnow()` — caught during verification
- `--summary` implemented as a valid JSON stub (not NotImplemented exception) so the flag is usable without crashing pending Plan 02

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced deprecated datetime.datetime.utcnow()**

- **Found during:** GREEN verification (deprecation warning on Python 3.12)
- **Issue:** `datetime.datetime.utcnow()` emits DeprecationWarning and will be removed in a future Python version
- **Fix:** Replaced both call sites with `datetime.datetime.now(datetime.timezone.utc)`
- **Files modified:** scripts/cortex/operational-indexer.py
- **Fixed in:** GREEN commit `7171b41`

## Verification Results

All plan verification checks passed:

- `python3 -m pytest test/test_operational_indexer.py -v -k "hook"` — 24 passed
- Edit hook exits 0: confirmed
- `tail -1 .cortex/edit-ledger.jsonl | python3 -c "... assert all(k in e for k in [...]) ..."` — schema OK
- Bash hook: ledger line count unchanged (delta: 0)
- Prune boundary: 502 entries → exactly 500 remain

## Next Phase Readiness

- Plan 02 (--summary mode) can read from `.cortex/edit-ledger.jsonl` — format is stable
- Plan 03 (hook registration) has a working script to register in `.claude/settings.json`
- No blockers
