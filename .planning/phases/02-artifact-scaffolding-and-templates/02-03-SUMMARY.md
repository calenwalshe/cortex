---
phase: 02-artifact-scaffolding-and-templates
plan: 03
subsystem: infra
tags: [continuity, handoffs, state-json, cortex, templates]

# Dependency graph
requires:
  - phase: 01-core-docs-and-architecture-alignment
    provides: CONTINUITY.md schema definitions used as field source of truth
provides:
  - 6 continuity template files in templates/cortex/ with {FIELD} placeholders
  - 6 seed handoff files in docs/cortex/handoffs/ with empty-state defaults
  - .cortex/state.json seeded with null slug, clarify mode, all gates false
  - .cortex/ directory structure with correct gitignore (durable vs scratch split)
affects: [03-cortex-status-command, 04-session-hooks, any phase reading .cortex/state.json or docs/cortex/handoffs/]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Continuity templates use {FIELD} uppercase placeholders — field names use lowercase snake_case to match CONTINUITY.md schema keys"
    - ".cortex/.gitignore negation pattern: ignore scratch dirs, !state.json and !compaction/ ensure durable files are tracked"
    - "Seed handoff files use (none)/(no active work) defaults so /cortex-status has a valid starting state without a work item"

key-files:
  created:
    - templates/cortex/current-state.md
    - templates/cortex/open-questions.md
    - templates/cortex/next-prompt.md
    - templates/cortex/decisions.md
    - templates/cortex/eval-status.md
    - templates/cortex/last-compact-summary.md
    - docs/cortex/handoffs/current-state.md
    - docs/cortex/handoffs/open-questions.md
    - docs/cortex/handoffs/next-prompt.md
    - docs/cortex/handoffs/decisions.md
    - docs/cortex/handoffs/eval-status.md
    - docs/cortex/handoffs/last-compact-summary.md
    - .cortex/state.json
    - .cortex/.gitignore
    - .cortex/compaction/.gitkeep
  modified: []

key-decisions:
  - "Scratch files (runs/, tmp/, dirty-files.json, validator-results.json) created on disk but not committed — .gitignore correctly rejects them on first git add, confirming .gitignore is working as intended"
  - "Template placeholders use {UPPERCASE_FIELD} format with lowercase field label (e.g., **next_action:** {NEXT_ACTION}) to match both schema key names and template convention"

patterns-established:
  - "Continuity template fields match CONTINUITY.md schema table field-by-field — no invented fields, no omissions"
  - "Seed handoff files use explicit (none) strings rather than leaving fields empty — prevents read failures when /cortex-status runs before any work item is started"

requirements-completed: [ART-08, CONT-04]

# Metrics
duration: 4min
completed: 2026-03-29
---

# Phase 02 Plan 03: Continuity Templates and .cortex/ State Directory Summary

**6 continuity templates with CONTINUITY.md-matched schema, 6 seeded handoff files, and .cortex/ machine state directory with state.json seeded to null/clarify/all-gates-false**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-29T02:40:18Z
- **Completed:** 2026-03-29T02:42:17Z
- **Tasks:** 2
- **Files modified:** 15 created, 0 modified

## Accomplishments

- 6 continuity template files in `templates/cortex/` with `{FIELD}` placeholders matching all CONTINUITY.md schema fields exactly
- 6 seed handoff files in `docs/cortex/handoffs/` initialized to empty-state defaults so `/cortex-status` has a valid starting point
- `.cortex/` directory tree: `state.json` (null slug, clarify mode, all gates false), `compaction/`, `.gitignore` — gitignore correctly separates durable from scratch files

## Task Commits

1. **Task 1: Create 6 continuity templates and seed docs/cortex/handoffs/** - `c409491` (feat)
2. **Task 2: Create .cortex/ machine state directory with seed files and gitignore** - `4d6029f` (feat)

**Plan metadata:** (next commit — docs)

## Files Created/Modified

- `templates/cortex/current-state.md` — template with all 8 schema fields: slug, mode, approval_status, active_contract_path, recent_artifacts, open_questions, blockers, next_action
- `templates/cortex/open-questions.md` — per-question fields: question, blocks_phase, status, resolution
- `templates/cortex/next-prompt.md` — paste-ready restart prompt shape from CONTINUITY.md with field comments
- `templates/cortex/decisions.md` — per-decision fields: timestamp, decision, context, rationale, alternatives_considered, impact
- `templates/cortex/eval-status.md` — per-dimension fields: dimension, status, last_run, threshold, result
- `templates/cortex/last-compact-summary.md` — fields: slug, compact_timestamp, what_was_accomplished, artifacts_written, decisions_made, open_items, next_action
- `docs/cortex/handoffs/current-state.md` — seeded with (none)/clarify/pending defaults, next_action = "Run /cortex-clarify to begin a new work item"
- `docs/cortex/handoffs/open-questions.md` — seeded with "(No active questions — no work item in progress)"
- `docs/cortex/handoffs/next-prompt.md` — seeded with "(no active work — run /cortex-clarify to start)"
- `docs/cortex/handoffs/decisions.md` — seeded with empty decision log
- `docs/cortex/handoffs/eval-status.md` — seeded with "(no active contract)"
- `docs/cortex/handoffs/last-compact-summary.md` — seeded noting no compaction has run yet
- `.cortex/state.json` — machine state seed: null slug, clarify mode, pending approval, null contract, empty artifacts, false approvals, all gates false
- `.cortex/.gitignore` — ignores runs/, tmp/, dirty-files.json, validator-results.json; negation for state.json and compaction/
- `.cortex/compaction/.gitkeep` — tracks compaction dir in git

## Decisions Made

- Scratch files on disk but not committed: `dirty-files.json`, `validator-results.json`, `runs/`, and `tmp/` were created locally but the `.cortex/.gitignore` correctly excludes them. The `git add` failure for these paths confirmed the gitignore is working as intended.
- Template placeholder format: `{UPPERCASE_FIELD}` placeholders with lowercase field labels (e.g., `**next_action:** {NEXT_ACTION}`) preserves both the schema key name and the template fill-in convention.

## Deviations from Plan

None — plan executed exactly as written. The `git add` rejection of scratch files was expected behavior confirming correct gitignore operation, not a deviation.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Continuity substrate is complete and ready for Phase 3 (`/cortex-status` command implementation)
- `.cortex/state.json` schema is the authoritative runtime state that Phase 3 commands will read/write
- `docs/cortex/handoffs/current-state.md` is the primary handoff doc that `/cortex-status` will parse and display
- No blockers for Phase 3

## Self-Check: PASSED

- FOUND: templates/cortex/current-state.md
- FOUND: docs/cortex/handoffs/current-state.md
- FOUND: .cortex/state.json
- FOUND: .cortex/.gitignore
- FOUND: commit c409491 (Task 1)
- FOUND: commit 4d6029f (Task 2)

---
*Phase: 02-artifact-scaffolding-and-templates*
*Completed: 2026-03-29*
