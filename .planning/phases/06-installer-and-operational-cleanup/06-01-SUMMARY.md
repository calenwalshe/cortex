---
phase: 06-installer-and-operational-cleanup
plan: 01
subsystem: infra
tags: [node, installer, symlink, hooks, agents, skills, settings.json]

# Dependency graph
requires:
  - phase: 04-subagents-and-hooks
    provides: all 4 agents and 11 hooks exist in .claude/agents/ and .claude/hooks/ repo paths
provides:
  - MANIFEST constant enumerating all 7 skills, 4 agents, 11 hooks
  - ensureSymlink() idempotent symlink helper (handles absent/stale/copy cases)
  - installAgents() symlinking 4 agents to ~/.claude/agents/
  - installHooks() symlinking 11 hooks to ~/.claude/hooks/ (replacing any existing copy)
  - isHookAlreadyWired() dedup check for settings.json merge
  - wireSettings() wiring all 9 hook events without clobbering existing entries
  - dry-run preview table showing would-create/already-set/replace-copy per item
  - bin/install.js exits 0 on --dry-run on any machine (no readdirSync on absent repo)
affects: [06-02-installer-and-operational-cleanup, any user running the installer]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "MANIFEST-driven enumeration: hardcoded manifest prevents ENOENT crashes in dry-run mode"
    - "ensureSymlink pattern: readlinkSync → EINVAL/ENOENT → unlinkSync → symlinkSync for idempotent file-or-symlink replacement"
    - "isHookAlreadyWired dedup: walks all existing entries per event, checks command substring match before appending"

key-files:
  created: []
  modified:
    - bin/install.js

key-decisions:
  - "MANIFEST replaces readdirSync in dry-run path — installer can enumerate without repo present"
  - "cortex-write-guard.sh is symlinked but NOT wired in settings.json — it is agent-invoked, not a global hook"
  - "All hooks use symlinkSync not copyFileSync — updates take effect immediately after git pull"
  - "isHookAlreadyWired uses command substring match, not equality — tolerates path variations"
  - "PostToolUse cortex-sync.sh entry is preserved — validator-trigger is appended as a second entry"

patterns-established:
  - "ensureSymlink: canonical idempotent symlink helper used for skills, agents, and hooks"
  - "MANIFEST-first dry-run: all enumeration uses MANIFEST constant, no filesystem reads from CORTEX_LOCAL"
  - "settings.json append-only: existing arrays always read and appended to, never overwritten"

requirements-completed: [INST-01, INST-02, INST-03, INST-06]

# Metrics
duration: 2min
completed: 2026-03-29
---

# Phase 6 Plan 01: Installer Core Rewrite Summary

**MANIFEST-driven bin/install.js rewrite: 7 skills, 4 agents, 11 hooks symlinked idempotently, 9 settings events wired, --dry-run exits 0 without repo access**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-29T15:38:03Z
- **Completed:** 2026-03-29T15:39:45Z
- **Tasks:** 3 (executed as single atomic write)
- **Files modified:** 1

## Accomplishments

- Added MANIFEST constant (7 skills, 4 agents, 11 hooks) — installer now enumerates without touching the uncloned repo path
- Added ensureSymlink() helper that correctly handles absent target (ENOENT), stale symlink, and regular file copy (EINVAL) with a single idempotent code path
- Added installAgents() symlinking 4 cortex agent .md files to ~/.claude/agents/ (creates dir if absent)
- Added installHooks() replacing old single-file installHook() — symlinks all 11 hooks, correctly detects and replaces the existing cortex-sync.sh copy
- Replaced wireSettings() with HOOK_EVENTS-driven version covering all 9 events with per-command dedup via isHookAlreadyWired()
- Rewrote printSummary() with DRY_RUN preview table showing [would create] / [already set] / [replace copy] per item
- Fixed installClaudeMd() to not read from ~/projects/cortex/ during dry-run

## Task Commits

All three plan tasks were implemented together in one atomic commit:

1. **Tasks 1-3: Full rewrite** — `3243308` (feat)

## Files Created/Modified

- `/home/agent/projects/cortex/bin/install.js` — Complete rewrite: MANIFEST, ensureSymlink, installAgents, installHooks, isHookAlreadyWired, generalized wireSettings, dry-run preview table

## Decisions Made

- cortex-write-guard.sh is symlinked to ~/.claude/hooks/ but not registered in settings.json — it is invoked by agent system prompts, not as a global Claude event hook
- PostToolUse cortex-sync.sh entry is preserved intact; cortex-validator-trigger.sh is appended as a separate second PostToolUse entry (plan spec: "do NOT remove the cortex-sync.sh entry")
- isHookAlreadyWired checks `h.command.includes(commandFragment)` rather than exact equality — tolerates absolute path differences without false positives on distinct filenames

## Deviations from Plan

None - plan executed exactly as written. All three tasks collapsed into one file write as they all touched bin/install.js and the final state was clear from the plan specifications.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- bin/install.js is complete and passes all phase-gate grep checks
- `node bin/install.js --dry-run` exits 0 and shows the correct preview table
- Ready for 06-02: dotfiles-setup.sh wrapper + test/installer.test.sh (5 assertions)
- Live install (without --dry-run) can be run to verify full deployment; 06-02 will add automated test coverage for idempotency and all 9 settings events

---
*Phase: 06-installer-and-operational-cleanup*
*Completed: 2026-03-29*
