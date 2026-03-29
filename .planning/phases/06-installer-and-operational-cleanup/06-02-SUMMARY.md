---
phase: 06-installer-and-operational-cleanup
plan: 02
subsystem: testing
tags: [installer, bash, shell, dotfiles, symlinks, test-suite]

# Dependency graph
requires:
  - phase: 06-01
    provides: bin/install.js rewrite with MANIFEST, installAgents, installHooks, wireSettings 9 events
provides:
  - dotfiles-setup.sh — CWD-independent shell entry point delegating to bin/install.js
  - test/installer.test.sh — automated test suite with 7 assertions (5 test groups), isolated temp HOME
  - Full INST-* test coverage: dry-run, symlinks, idempotency, settings dedup, credential audit
affects: [phase-06, installer, deployment]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SCRIPT_DIR pattern for CWD-independent shell wrappers"
    - "Isolated temp HOME via mktemp -d + trap cleanup for installer tests"
    - "{ grep ... || true; } | wc -l to handle set -euo pipefail + no-match grep"

key-files:
  created:
    - dotfiles-setup.sh
    - test/installer.test.sh
  modified: []

key-decisions:
  - "dotfiles-setup.sh is intentionally minimal — 4 lines, zero logic, all delegation to bin/install.js"
  - "Test isolation via exported HOME=$TEST_HOME before node invocation — works because install.js reads HOME via os.homedir()"
  - "~/projects/cortex symlink inside TEST_HOME points to real repo — provides source files without HOME complexity"
  - "grep no-match failure under set -euo pipefail fixed with { ... || true; } pattern not || true | wc -l"

patterns-established:
  - "Thin shell wrapper pattern: SCRIPT_DIR + node delegation, no logic in .sh"
  - "Test isolation pattern: mktemp -d + export HOME + trap cleanup + symlink to real repo"

requirements-completed: [INST-04, INST-05, INST-06]

# Metrics
duration: 8min
completed: 2026-03-29
---

# Phase 6 Plan 02: Installer Shell Wrapper and Test Suite Summary

**dotfiles-setup.sh CWD-independent shell entry point + test/installer.test.sh with 7 assertions covering dry-run, symlinks, idempotency, settings dedup, and credential audit**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-29T15:42:36Z
- **Completed:** 2026-03-29T15:50:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- dotfiles-setup.sh: 4-line shell wrapper using SCRIPT_DIR pattern, chmod +x, exits 0 on --dry-run from any CWD
- test/installer.test.sh: 7 assertions in 5 test groups, all pass, uses isolated mktemp HOME so real ~/.claude/ is never touched
- All 6 phase-gate checks pass; credential audit returns 0 matches

## Task Commits

Each task was committed atomically:

1. **Task 1: Create dotfiles-setup.sh wrapper** - `dc1add7` (feat)
2. **Task 2: Create test/installer.test.sh with 5 assertions** - `7758562` (feat)

## Files Created/Modified
- `dotfiles-setup.sh` — thin shell wrapper delegating all args to `bin/install.js` via SCRIPT_DIR
- `test/installer.test.sh` — automated test suite: dry-run, 7 skills / 4 agents / 11 hooks symlinks, idempotency, settings dedup, credential audit

## Decisions Made
- dotfiles-setup.sh has zero logic beyond SCRIPT_DIR + delegation — all installer logic stays in bin/install.js
- Test HOME isolation via `export HOME=$TEST_HOME` before node invocation exploits the fact that `os.homedir()` reads the HOME env var
- `$TEST_HOME/projects/cortex` symlinks to the real repo — cleanest way to give the installer its source files without altering CORTEX_LOCAL computation
- Used `{ grep ... || true; } | wc -l` grouping pattern to prevent `set -euo pipefail` from aborting on grep exit code 1 (no matches)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed set -euo pipefail + grep no-match interaction in credential audit test**
- **Found during:** Task 2 (test suite creation)
- **Issue:** `grep ... | wc -l` under `set -euo pipefail` — when grep finds 0 matches, it exits 1, which propagates through the pipeline and aborts the script before wc -l runs. The test would exit 1 even when 0 credential URLs exist (correct outcome).
- **Fix:** Wrapped grep in a command group `{ grep ...; || true; }` before piping to wc -l so the group always exits 0 regardless of grep's match result.
- **Files modified:** test/installer.test.sh
- **Verification:** Re-ran test suite; credential audit PASS, all 7 assertions green, exit 0.
- **Committed in:** 7758562 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug fix)
**Impact on plan:** Fix was required for correctness — test produced false failure without it. No scope creep.

## Issues Encountered
None beyond the pipefail/grep interaction documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
Phase 6 complete. All 6 plans done. Full INST-01 through INST-06 coverage achieved across 06-01 and 06-02:
- INST-01: installRepo (06-01)
- INST-02: installSkills symlinks (06-01)
- INST-03: wireSettings 9 events (06-01)
- INST-04: installAgents + installHooks (06-01)
- INST-05: dotfiles-setup.sh entry point (06-02)
- INST-06: automated test suite (06-02)

---
*Phase: 06-installer-and-operational-cleanup*
*Completed: 2026-03-29*
