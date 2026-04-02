---
phase: 13-autonomy-config-foundation
plan: 01
subsystem: config
tags: [autonomy, json-schema, config-resolution, nodejs, bash-tests]

# Dependency graph
requires:
  - phase: 12-auto-doc-sync
    provides: hooks infrastructure and pre-commit pipeline patterns
provides:
  - templates/cortex/autonomy.json — documented schema template with 3 presets and 13 named gates
  - scripts/cortex/resolve-autonomy.js — 4-layer config resolver with mandatory gate enforcement
  - test/autonomy-config.test.sh — 18-case test suite covering AUTON-03/04/07/11
affects:
  - phase-14-gate-patches (consumes resolveAutonomy from scripts/cortex/resolve-autonomy.js)
  - phase-15-bridge (reads resolved config for autonomy-aware artifact generation)
  - phase-16-observability (extends resolver output for dry-run and status display)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CommonJS resolver module with CLI mode (stdin JSON in, stdout JSON out) for bash testability"
    - "4-layer config merge: start from preset, apply global, apply project, apply invocation, then force mandatory gates"
    - "_doc/_gates_doc fields for inline JSON documentation (no comment support in JSON)"

key-files:
  created:
    - templates/cortex/autonomy.json
    - scripts/cortex/resolve-autonomy.js
    - test/autonomy-config.test.sh
  modified:
    - package.json

key-decisions:
  - "Mandatory gate enforcement applied LAST in the merge chain — ensures no intermediate layer can accidentally disable ux_taste_eval, human_action, or reclarify"
  - "_gates_doc object at top-level (not inline in gates) keeps the gates object with exactly 13 boolean keys matching the verification check"
  - "CLI stdin/stdout JSON mode on resolver enables bash test harness without requiring a separate test runner"
  - "Unknown preset throws an Error (not silently falls back) — fail loudly on misconfiguration"

patterns-established:
  - "Config resolver pattern: require('./scripts/cortex/resolve-autonomy.js') then call resolveAutonomy({ projectConfig, globalConfig, invocationFlags })"
  - "Gate access pattern: const { gates } = resolveAutonomy(opts); if (gates.contract_approval) { ... }"
  - "Bash test pattern matches test/auto-doc-sync.test.sh: assert_pass/assert_fail helpers, PASS/FAIL counters, summary line"

requirements-completed: [AUTON-03, AUTON-04, AUTON-07, AUTON-11]

# Metrics
duration: 3min
completed: 2026-04-02
---

# Phase 13 Plan 01: Autonomy Config Foundation Summary

**Autonomy config template (3 presets, 13 named gates) and 4-layer resolver with mandatory gate enforcement — config substrate for gate-patching phases 14-16**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-04-02T19:50:37Z
- **Completed:** 2026-04-02T19:53:00Z
- **Tasks:** 3 (TDD: RED + GREEN commits for Tasks 2 and 3)
- **Files modified:** 4

## Accomplishments

- `templates/cortex/autonomy.json` with 13 named gates, supervised default preset, inline documentation via `_doc`/`_gates_doc` fields
- `scripts/cortex/resolve-autonomy.js` exports `resolveAutonomy`, `PRESET_DEFAULTS`, `MANDATORY_GATES`; implements 4-layer merge with mandatory gate enforcement applied last
- `test/autonomy-config.test.sh` passes 18/18 test cases covering all 4 requirements (AUTON-03, AUTON-04, AUTON-07, AUTON-11)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create autonomy config template** - `efc660c` (feat)
2. **Task 2 RED: Failing tests for resolver** - `(red commit)` (test)
3. **Task 2 GREEN: Implement resolver** - `14e59c2` (feat)
4. **Task 3: Wire test suite into package.json** - `80fd96f` (chore)

_Note: TDD tasks have RED (test → fails) + GREEN (impl → passes) commits_

## Files Created/Modified

- `templates/cortex/autonomy.json` — Schema template: preset field, 13 gate booleans (supervised defaults), _doc metadata
- `scripts/cortex/resolve-autonomy.js` — CommonJS resolver module with CLI stdin mode; exports resolveAutonomy, PRESET_DEFAULTS, MANDATORY_GATES
- `test/autonomy-config.test.sh` — 18-case bash test suite; assert_pass/assert_fail pattern matching existing project tests
- `package.json` — Added `bash test/autonomy-config.test.sh` to test script chain

## Decisions Made

- Mandatory gate enforcement applied last in the merge chain — ensures ux_taste_eval, human_action, reclarify cannot be suppressed at any layer
- `_gates_doc` top-level object documents gate groupings without adding non-boolean keys to the `gates` object (preserves the 13-key invariant the verify command checks)
- Unknown preset throws `Error` rather than falling back silently — misconfigured presets should fail loudly
- CLI stdin/stdout JSON mode enables bash testability without additional test harness dependencies

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

- Pre-existing installer test failure ("credential audit") in `test/installer.test.sh` — unrelated to this plan, present before any changes. Documented here for traceability; not fixed (out of scope per deviation rules).

## Known Stubs

None — all deliverables are fully implemented and verified.

## Next Phase Readiness

Phase 14 (Gate Patches) can consume the resolver immediately:
- `require('./scripts/cortex/resolve-autonomy.js')` is importable
- `resolveAutonomy({ projectConfig })` returns `{ preset, gates }` with 13 gate booleans
- `gates.contract_approval`, `gates.spec_approval`, etc. are the direct conditional checks
- Full backward compatibility: missing config defaults to supervised (all gates active)

---
*Phase: 13-autonomy-config-foundation*
*Completed: 2026-04-02*

## Self-Check: PASSED

- FOUND: templates/cortex/autonomy.json
- FOUND: scripts/cortex/resolve-autonomy.js
- FOUND: test/autonomy-config.test.sh
- FOUND: commits efc660c, 14e59c2, 80fd96f
