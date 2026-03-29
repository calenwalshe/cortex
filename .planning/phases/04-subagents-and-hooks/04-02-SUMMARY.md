---
phase: 04-subagents-and-hooks
plan: "02"
subsystem: infra
tags: [hooks, bash, claude-code, session-lifecycle, continuity]

# Dependency graph
requires:
  - phase: 02-artifact-scaffolding-and-templates
    provides: .cortex/state.json schema and docs/cortex/handoffs/ directory structure
  - phase: 03-new-and-updated-skills
    provides: /cortex-status command that reads current-state.md
provides:
  - Four executable session lifecycle hook scripts under .claude/hooks/
  - .claude/settings.json registering SessionStart, PreCompact, PostCompact, and Stop hooks
  - Automated current-state.md hydration on every session start
  - Pre/post-compaction snapshot and summary writing
affects:
  - 04-03-enforcement-hooks
  - Any phase using session continuity or compaction flow

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "CLAUDE_PROJECT_DIR env var for portable hook paths"
    - "python3 -c for JSON construction in bash (avoids jq multiline escaping)"
    - "async: true on Stop hook to avoid delaying agent responses"
    - "Soft-fail pattern: all hooks exit 0 on missing files"

key-files:
  created:
    - .claude/hooks/cortex-session-start.sh
    - .claude/hooks/cortex-session-end.sh
    - .claude/hooks/cortex-precompact.sh
    - .claude/hooks/cortex-postcompact.sh
    - .claude/settings.json
  modified: []

key-decisions:
  - "Stop hook registered async: true — does not delay agent responses"
  - "CLAUDE_PROJECT_DIR used for all paths — no hardcoded machine paths"
  - "python3 used for JSON construction in session-start to handle multiline strings without jq escaping issues"
  - "All hooks soft-fail (exit 0) when expected files are absent — safe for fresh projects"

patterns-established:
  - "Hook soft-fail: [[ ! -f file ]] && exit 0 guards all hooks"
  - "State extraction pattern: jq -r '.field // default' with 2>/dev/null fallback"
  - "Redirect to /dev/null with || exit 0 on all file writes"

requirements-completed: [HOOK-01, HOOK-07, HOOK-08, HOOK-09, CONT-01, CONT-02, CONT-03]

# Metrics
duration: 5min
completed: 2026-03-29
---

# Phase 04 Plan 02: Session Lifecycle Hooks Summary

**Four bash hooks registered in .claude/settings.json deliver automated continuity: session-start injects current-state.md as additionalContext, Stop writes updated state after each turn (async), PreCompact snapshots to .cortex/compaction/, PostCompact refreshes last-compact-summary.md and next-prompt.md.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-29T05:30:33Z
- **Completed:** 2026-03-29T05:35:00Z
- **Tasks:** 3 of 3
- **Files modified:** 5

## Accomplishments

- Created cortex-session-start.sh: reads current-state.md, emits JSON with `additionalContext` key so Claude is hydrated without manual /cortex-status on every session start
- Created cortex-session-end.sh: async Stop hook that rebuilds current-state.md from .cortex/state.json fields after every agent response turn
- Created cortex-precompact.sh: writes timestamped snapshot combining current-state.md and state.json before compaction runs
- Created cortex-postcompact.sh: writes last-compact-summary.md and refreshes next-prompt.md after compaction
- Created .claude/settings.json registering all four hooks with correct event names and async flag on Stop

## Task Commits

Each task was committed atomically:

1. **T1: Create cortex-session-start.sh and cortex-session-end.sh** - `e3f3a62` (feat)
2. **T2: Create cortex-precompact.sh and cortex-postcompact.sh** - `4de48ec` (feat)
3. **T3: Create .claude/settings.json with session lifecycle hook registrations** - `4a38be7` (feat)

## Files Created/Modified

- `.claude/hooks/cortex-session-start.sh` - SessionStart hook: reads current-state.md, emits JSON additionalContext blob
- `.claude/hooks/cortex-session-end.sh` - Async Stop hook: rebuilds current-state.md from state.json fields
- `.claude/hooks/cortex-precompact.sh` - PreCompact hook: writes timestamped snapshot to .cortex/compaction/
- `.claude/hooks/cortex-postcompact.sh` - PostCompact hook: writes last-compact-summary.md, refreshes next-prompt.md
- `.claude/settings.json` - Hook registration for SessionStart, PreCompact, PostCompact, Stop

## Decisions Made

- Stop hook is `async: true` — firing synchronously after every response would add visible latency; continuity writes can be deferred.
- `python3 -c` used in session-start for JSON output — jq heredoc escaping breaks on multiline markdown content; python3 handles it cleanly.
- All hooks use `CLAUDE_PROJECT_DIR` variable — hardcoding `/home/agent/projects/cortex` would break portability across installs.
- Soft-fail pattern (`exit 0` on missing files) throughout — hooks must not error on fresh projects with no state yet.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. Hooks become active immediately on the next Claude Code session start in this project directory.

## Next Phase Readiness

- All four hooks are registered and executable — session lifecycle automation is live
- Plan 04-03 can now build enforcement hooks on top of this settings.json skeleton (Stop/PreCompact events are already wired)
- No blockers

---
*Phase: 04-subagents-and-hooks*
*Completed: 2026-03-29*
