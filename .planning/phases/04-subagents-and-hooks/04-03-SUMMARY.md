---
phase: 04-subagents-and-hooks
plan: "03"
subsystem: hooks
tags: [bash, hooks, enforcement, phase-guard, validators, task-lifecycle, agent-team]

requires:
  - phase: 04-02
    provides: .claude/settings.json with session lifecycle hooks (SessionStart, PreCompact, PostCompact, Stop)

provides:
  - cortex-phase-guard.sh: PreToolUse Write|Edit hook denying writes outside docs/cortex/ and .cortex/ during clarify/research/spec phases
  - cortex-validator-trigger.sh: PostToolUse Write|Edit hook appending written paths to .cortex/dirty-files.json during execute/repair phases
  - cortex-task-created.sh: TaskCreated hook rejecting tasks missing deliverable, validator, or contract link
  - cortex-task-completed.sh: TaskCompleted hook blocking completion when active contract has failing validators
  - cortex-teammate-idle.sh: TeammateIdle hook feeding actionable next-step to idle agent workers
  - .claude/settings.json extended with 5 new hook event registrations (9 total)

affects: [phase-05-eval-subsystem, phase-06-installer]

tech-stack:
  added: []
  patterns:
    - "JSON deny output (permissionDecision) via python3 for multiline-safe hook messages"
    - "Soft-fail pattern: exit 0 on all guard conditions (missing state.json, empty file path, wrong mode)"
    - "python3 for JSON construction in hooks — avoids jq escaping issues with special characters"
    - "dirty-files.json accumulates file paths during execute/repair for downstream validator runner"
    - "continue: false pattern for TaskCreated/TaskCompleted blocking"
    - "exit 2 from TeammateIdle keeps agent team workers active"

key-files:
  created:
    - .claude/hooks/cortex-phase-guard.sh
    - .claude/hooks/cortex-validator-trigger.sh
    - .claude/hooks/cortex-task-created.sh
    - .claude/hooks/cortex-task-completed.sh
    - .claude/hooks/cortex-teammate-idle.sh
  modified:
    - .claude/settings.json

key-decisions:
  - "phase-guard uses JSON permissionDecision deny (exit 0) not exit 2 — gives Claude an actionable reason rather than a terse failure"
  - "validator-trigger is async PostToolUse — records dirty files only, never runs validators inline (timeout risk)"
  - "task-created checks deliverable, validator, and contract link — objective is implicitly covered by subject+description content"
  - "task-completed checks eval-status.md for FAIL rows rather than re-running validators — lightweight read-only enforcement"
  - "teammate-idle uses exit 2 to signal continuation — keeps worker agents from silently completing"

patterns-established:
  - "Enforcement hook pattern: INPUT=$(cat) first, soft-fail on missing state.json, mode-switch to determine enforcement scope"
  - "All hook paths use CLAUDE_PROJECT_DIR — no hardcoded machine paths anywhere in the hook bundle"

requirements-completed: [HOOK-02, HOOK-03, HOOK-04, HOOK-05, HOOK-06, LOOP-01, LOOP-03, LOOP-04]

duration: 5min
completed: 2026-03-29
---

# Phase 4 Plan 03: Enforcement Hooks Summary

**Five enforcement hooks wired into .claude/settings.json: phase-guard (PreToolUse deny), validator-trigger (PostToolUse dirty-file tracking), task-created/completed (lifecycle blocking), and teammate-idle (agent worker feedback)**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-29T14:55:00Z
- **Completed:** 2026-03-29T15:00:24Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- Five enforcement hook scripts created, all executable, all following the soft-fail/mode-switch pattern
- cortex-phase-guard blocks writes outside docs/cortex/ and .cortex/ during clarify/research/spec — passes through silently for execute and later modes
- cortex-validator-trigger records dirty files to .cortex/dirty-files.json during execute/repair; no inline validator execution
- Task lifecycle hooks enforce contract compliance at creation (missing fields) and completion (failing validators in eval-status.md)
- .claude/settings.json now registers 9 hook events total (4 from plan 04-02 + 5 new)

## Task Commits

1. **Task T1: cortex-phase-guard.sh and cortex-validator-trigger.sh** - `51ff2cc` (feat)
2. **Task T2: cortex-task-created.sh, cortex-task-completed.sh, cortex-teammate-idle.sh** - `ee17d40` (feat)
3. **Task T3: Register enforcement hooks in .claude/settings.json** - `43f9f08` (feat)

## Files Created/Modified

- `.claude/hooks/cortex-phase-guard.sh` — PreToolUse Write|Edit; denies outside permitted roots in pre-execution phases
- `.claude/hooks/cortex-validator-trigger.sh` — PostToolUse Write|Edit async; appends path to .cortex/dirty-files.json
- `.claude/hooks/cortex-task-created.sh` — TaskCreated; rejects tasks missing deliverable, validator ref, or contract link
- `.claude/hooks/cortex-task-completed.sh` — TaskCompleted; blocks if active contract has FAIL rows in eval-status.md
- `.claude/hooks/cortex-teammate-idle.sh` — TeammateIdle; emits actionable next step from current-state.md, exits 2
- `.claude/settings.json` — merged 5 new hook registrations into existing 4; 9 events total, valid JSON

## Decisions Made

- phase-guard outputs `permissionDecision: deny` JSON (exit 0) not exit 2 — gives Claude an actionable error message with mode name and what to do
- validator-trigger is async — avoids blocking the Write/Edit response while recording dirty files
- task-created keyword checks cover deliverable, validator, and contract link; objective is implicit in subject+description combined text
- task-completed reads eval-status.md for FAIL table rows — lightweight, no subprocess validators, respects hook timeout budget
- teammate-idle exits 2 to signal the platform to keep the worker running

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- All 5 enforcement hooks are in place and registered
- Plan 04-04 (the final plan in phase 4) can proceed — its scope covers the continuity flow and contract loop wiring
- .cortex/dirty-files.json will be populated by cortex-validator-trigger once execute/repair mode is active in a real work session
- eval-status.md enforcement (task-completed) becomes meaningful once Phase 5 (Eval Subsystem) lands

---
*Phase: 04-subagents-and-hooks*
*Completed: 2026-03-29*
