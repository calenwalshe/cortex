---
phase: 02-artifact-scaffolding-and-templates
plan: 04
subsystem: infra
tags: [cortex, scaffold, bash, idempotent, runtime-structure]

# Dependency graph
requires:
  - phase: 02-artifact-scaffolding-and-templates
    plan: 01
    provides: 9 docs/cortex/ subdirectory READMEs (clarify through handoffs)
  - phase: 02-artifact-scaffolding-and-templates
    plan: 02
    provides: 13 artifact templates in templates/cortex/
  - phase: 02-artifact-scaffolding-and-templates
    plan: 03
    provides: 6 continuity templates, .cortex/ structure, state.json schema
provides:
  - scripts/cortex/scaffold_runtime.sh — idempotent bash script that creates the full Cortex runtime substrate in any target project
  - Creates docs/cortex/ (9 subdirs), .cortex/ (state.json, .gitignore, runs/, tmp/, compaction/), and seeds 6 continuity files
affects:
  - 03-cortex-commands (scaffold_runtime.sh is the entry-point users run to set up a new project)
  - Any phase documenting onboarding/install flow

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd) — CWD-independent template resolution"
    - "Idempotency via [ -f dst ] pre-check before cp — no cp -n needed; guard is explicit"
    - "[ -f guard ] pattern for JSON seed files — state.json, dirty-files.json, validator-results.json only written if absent"
    - "mkdir -p for target dir creation — script handles both new and existing project roots"

key-files:
  created:
    - scripts/cortex/scaffold_runtime.sh
  modified: []

key-decisions:
  - "Idempotency guard is a [ -f dst ] pre-check, not cp -n — avoids portability warnings and makes intent explicit in the code"
  - "Script creates target directory with mkdir -p — supports scaffolding both existing and brand-new project roots"
  - "dirty-files.json and validator-results.json are written as scratch files (not tracked in git per .cortex/.gitignore)"

patterns-established:
  - "scaffold_runtime.sh is the canonical onboarding entry point — one command to create the full Cortex substrate"
  - "Template resolution via SCRIPT_DIR/../../templates/cortex — always resolves correctly regardless of how or from where the script is invoked"

requirements-completed: [ART-01, ART-02, ART-03, ART-04, ART-05, ART-06, ART-07, ART-08, CONT-04]

# Metrics
duration: 2min
completed: 2026-03-29
---

# Phase 02 Plan 04: Scaffold Runtime Script Summary

**Idempotent `scripts/cortex/scaffold_runtime.sh` that creates the full docs/cortex/ + .cortex/ substrate in any target project, seeding 6 continuity files from templates and writing state.json with null slug, clarify mode, all gates false**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-29T02:45:31Z
- **Completed:** 2026-03-29T02:47:33Z
- **Tasks:** 2
- **Files modified:** 1 created

## Accomplishments

- Wrote `scripts/cortex/scaffold_runtime.sh` — 152 lines, executable, passes `bash -n` syntax check
- Creates all 9 `docs/cortex/` subdirs and full `.cortex/` structure with a single command
- Seeds 6 continuity files to `docs/cortex/handoffs/` from `templates/cortex/` — existing files skipped
- Second run against an initialized project prints "skipped" for every file, changes nothing

## Task Commits

Each task was committed atomically:

1. **Task 1: Write scaffold_runtime.sh** - `0c6c52a` (feat)
2. **Task 2: Fix idempotency output + verify full file inventory** - `baf57fe` (fix)

**Plan metadata:** (next commit — docs)

## Files Created/Modified

- `scripts/cortex/scaffold_runtime.sh` — Idempotent scaffold script. Takes one argument (target project root). Resolves templates dir via `$SCRIPT_DIR/../../templates/cortex`. Creates all dirs with `mkdir -p`, seeds continuity files via `[ -f dst ]` pre-check, writes JSON seed files only if absent, creates `.gitkeep` in runtime dirs, writes `.cortex/.gitignore` only if absent.

## Decisions Made

- Idempotency uses `[ -f dst ]` pre-check before `cp` rather than `cp -n` — GNU coreutils emits a portability warning for `cp -n` on this platform; the explicit pre-check is cleaner and makes the intent readable in the code.
- Script creates target directory with `mkdir -p "$1"` before resolving its real path — this lets users pass a non-existent directory and have it bootstrapped from scratch.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed misleading "created" output on second run for handoff files**
- **Found during:** Task 2 (idempotency verification)
- **Issue:** `cp -n` exits 0 even when it does nothing — the `if cp -n; then echo "created"` branch always triggered, printing "created" even when the file already existed and was skipped
- **Fix:** Replaced `if cp -n` with `if [ -f dst ] / else cp` so "created" vs "skipped" reflects actual disk state
- **Files modified:** `scripts/cortex/scaffold_runtime.sh`
- **Verification:** Second run against directory with sentinel content prints "skipped" for all handoff files; sentinel content preserved
- **Committed in:** `baf57fe` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — logic/output bug)
**Impact on plan:** Fix was required for correct idempotency output; no behavior change to the actual copy-guard mechanism. No scope creep.

## Issues Encountered

- `cd "$1" && pwd` for TARGET resolution fails if the directory doesn't exist yet — added `mkdir -p "$1"` before the `cd`. This is the expected scaffolding use-case (bootstrapping a new project directory).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- `scaffold_runtime.sh` is the complete onboarding entry point for Cortex — Phase 3 command docs can reference it as "run once to initialize"
- All Phase 2 artifacts are complete: 9 READMEs (plan 01), 13 templates (plan 02), 6 continuity seeds + .cortex/ (plan 03), scaffold script (plan 04)
- No blockers for Phase 3

## Self-Check: PASSED

- FOUND: `/home/agent/projects/cortex/scripts/cortex/scaffold_runtime.sh`
- FOUND: commit `0c6c52a` (Task 1)
- FOUND: commit `baf57fe` (Task 2)
- VERIFIED: `bash -n` syntax check passes
- VERIFIED: state.json assertions pass (null slug, clarify mode, all gates false)
- VERIFIED: second run produces "skipped" for all pre-existing files

---
*Phase: 02-artifact-scaffolding-and-templates*
*Completed: 2026-03-29*
