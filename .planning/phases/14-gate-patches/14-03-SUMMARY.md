---
phase: 14-gate-patches
plan: "03"
subsystem: skills
tags: [autonomy, gate-patches, invocation-flags, test-harness]
dependency_graph:
  requires: [14-01, 14-02, scripts/cortex/resolve-autonomy.js]
  provides: [invocation-flag-docs-all-5-skills, test/gate-conditionals.test.sh]
  affects:
    - skills/cortex-clarify/SKILL.md
    - skills/cortex-research/SKILL.md
    - skills/cortex-spec/SKILL.md
    - skills/cortex-review/SKILL.md
    - skills/cortex-audit/SKILL.md
tech_stack:
  added: []
  patterns: [invocation-layer-override, bash-test-harness, stdin-json-resolver]
key_files:
  created:
    - test/gate-conditionals.test.sh
  modified:
    - skills/cortex-clarify/SKILL.md
    - skills/cortex-research/SKILL.md
    - skills/cortex-spec/SKILL.md
    - skills/cortex-review/SKILL.md
    - skills/cortex-audit/SKILL.md
decisions:
  - "--autonomy and --gate flags documented as invocation layer input (highest precedence in 4-layer resolution)"
  - "Test script uses PASS=$((PASS+1)) not ((PASS++)) to avoid set -e false-falsy exit on zero-valued increment"
  - "Test script pipes JSON to node resolver via stdin — matches CLI mode established in Phase 13"
metrics:
  duration: "~4 minutes"
  completed: "2026-04-02T20:29:47Z"
  tasks_completed: 2
  files_modified: 5
  files_created: 1
requirements: [AUTON-01, AUTON-02]
---

# Phase 14 Plan 03: Invocation Flag Docs and Gate Conditionals Test Summary

Added `--autonomy` and `--gate` invocation flag documentation to all 5 patched skill files and created a 28-assertion bash test harness validating gate conditional resolution across all 3 presets, all 8 non-mandatory gates, and mandatory gate enforcement.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add --autonomy and --gate flag docs to all 5 skill files | d2089fd | skills/cortex-{clarify,research,spec,review,audit}/SKILL.md |
| 2 | Create gate-conditionals test script | 2c042d4 | test/gate-conditionals.test.sh |

## What Was Built

### Task 1: Invocation Flag Documentation (5 skill files)

Each of the 5 skill files received two new flag entries in the Arguments section and an updated autonomy resolution block.

**cortex-clarify/SKILL.md:** Added `--autonomy <preset>` and `--gate <name>=<bool>` after the existing `<idea>` argument. Updated the Phase 2 resolution block step 3 to explicitly say: "If `--autonomy` or `--gate` flags were provided, use them as the invocation layer (highest precedence in the 4-layer resolution)."

**cortex-research/SKILL.md:** Added two rows to the Arguments table after `--team`. Updated Phase 3b resolution block step 3 with the invocation layer reference.

**cortex-spec/SKILL.md:** Replaced "no flags or arguments" with explicit `--autonomy` and `--gate` entries. Updated the autonomy config resolution block step 3 with the invocation layer reference.

**cortex-review/SKILL.md:** Added `--autonomy` and `--gate` entries after `--pr N`. Updated the Contract Compliance autonomy resolution block step 3 with the invocation layer reference.

**cortex-audit/SKILL.md:** Added `--autonomy` and `--gate` entries after `--quick`. Updated the Autonomy Gate: Security Verdict block step 3 with the invocation layer reference.

### Task 2: Gate Conditionals Test Script

Created `test/gate-conditionals.test.sh` — a bash test harness with 28 assertions across 6 test groups:

1. **Supervised preset** — all 8 non-mandatory gates are `true`
2. **Full-auto preset, non-mandatory gates** — all 8 are `false`
3. **Full-auto preset, mandatory gates** — `reclarify`, `ux_taste_eval`, `human_action` all remain `true`
4. **Gates-only preset** — `contract_approval` is `true`, review gates are `false`
5. **Invocation override** — per-gate `contract_approval=true` wins over `full-auto` preset
6. **Mandatory gate enforcement** — `reclarify=false` invocation override is blocked; gate stays `true`

The script pipes JSON to `node scripts/cortex/resolve-autonomy.js` via stdin (CLI mode from Phase 13) and extracts gate values with inline node.

**Result:** 28/28 pass, exit code 0.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed ((PASS++)) false-exit under set -e**
- **Found during:** Task 2 verification
- **Issue:** `set -euo pipefail` combined with `((PASS++))` when PASS=0 returns exit code 1 (0 is falsy), causing the script to abort after the first PASS case
- **Fix:** Replaced `((PASS++))` / `((FAIL++))` with `PASS=$((PASS + 1))` / `FAIL=$((FAIL + 1))` — arithmetic expansion that never returns a falsy exit code
- **Files modified:** test/gate-conditionals.test.sh
- **Commit:** 2c042d4

## Must-Haves Verification

| Truth | Status |
|-------|--------|
| Each of the 5 patched skill files documents --autonomy and --gate invocation flags | SATISFIED — all 5 files verified |
| The flags are described as passing to the resolver as the invocation layer (highest precedence) | SATISFIED — each resolution block updated |
| A test script validates that resolved gate values change behavior in the expected direction for each preset | SATISFIED — 28 assertions, all pass |
| Tests confirm mandatory gates remain true even when full-auto preset is active | SATISFIED — group 3 (3 assertions) + group 6 (1 assertion) |

## Artifact Verification

| Artifact | Contains | Status |
|----------|----------|--------|
| test/gate-conditionals.test.sh | `resolve-autonomy` | PRESENT |
| skills/cortex-clarify/SKILL.md | `--autonomy` | PRESENT |
| skills/cortex-spec/SKILL.md | `--gate` | PRESENT |

## Self-Check: PASSED

Files verified:
- `test/gate-conditionals.test.sh` — exists, 28 assertions, ALL TESTS PASSED
- `skills/cortex-clarify/SKILL.md` — exists, contains --autonomy, --gate
- `skills/cortex-research/SKILL.md` — exists, contains --autonomy, --gate
- `skills/cortex-spec/SKILL.md` — exists, contains --autonomy, --gate, invocation layer
- `skills/cortex-review/SKILL.md` — exists, contains --autonomy, --gate
- `skills/cortex-audit/SKILL.md` — exists, contains --autonomy, --gate

Commits verified:
- `d2089fd` — feat(14-03): add --autonomy and --gate flag docs to all 5 skill files
- `2c042d4` — test(14-03): create gate-conditionals test harness
