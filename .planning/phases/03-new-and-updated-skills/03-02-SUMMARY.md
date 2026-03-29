---
phase: 03-new-and-updated-skills
plan: 02
subsystem: skills
tags: [cortex-spec, cortex-status, continuity, handoff, SKILL.md]

# Dependency graph
requires:
  - phase: 02-artifact-scaffolding-and-templates
    provides: spec.md, gsd-handoff.md, contract.md, current-state.md templates that these skills write to
provides:
  - skills/cortex-spec/SKILL.md — net-new skill: converts clarify + research into spec, handoff, and contract
  - skills/cortex-status/SKILL.md — replacement skill: continuity reconstruction from repo-local artifacts
affects:
  - 03-new-and-updated-skills (other plans in phase using these skills)
  - any consumer of /cortex-spec or /cortex-status commands

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Prerequisite gate pattern: block with actionable error if required artifact is missing
    - Explicit GSD prohibition: cortex-spec does NOT auto-invoke GSD, human imports handoff manually
    - Continuity reconstruction from repo-local artifacts only, no reliance on chat history

key-files:
  created:
    - skills/cortex-spec/SKILL.md
  modified:
    - skills/cortex-status/SKILL.md

key-decisions:
  - "cortex-spec requires both clarify brief and at least one research dossier — blocks with actionable error if either is missing"
  - "cortex-spec does NOT auto-invoke GSD; the human must explicitly import gsd-handoff.md as a manual step"
  - "eval_plan field is mandatory on every contract — contracts without it are incomplete and must not advance past spec state"
  - "cortex-status reads exclusively from docs/cortex/handoffs/current-state.md and .cortex/state.json — never from .planning/"
  - "Old cortex-status system-health behavior (API keys, layer files, upstream versions, Python packages) fully retired"

patterns-established:
  - "Skill phase structure: Validate → Synthesize → Write artifacts → Update state → Output terminal summary"
  - "Continuity reconstruction order: state.json (machine) → current-state.md (human) → artifact scan (disk) → reconcile → refresh"

requirements-completed: [CMD-03, CMD-07]

# Metrics
duration: 8min
completed: 2026-03-29
---

# Phase 03 Plan 02: New and Updated Skills Summary

**cortex-spec skill (net-new) converts clarify brief + research dossiers into spec.md, gsd-handoff.md, and contract-001.md; cortex-status skill (full replacement) reconstructs continuity context from repo-local artifacts without reading chat history or .planning/**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-03-29T03:04:56Z
- **Completed:** 2026-03-29T03:13:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created `skills/cortex-spec/SKILL.md` — net-new skill implementing a 5-phase protocol: prerequisite validation, spec synthesis (all 9 mandatory sections), GSD handoff write, contract write with mandatory eval_plan, and continuity state update
- Replaced `skills/cortex-status/SKILL.md` — completely retired the old system-health behavior (API connectivity, upstream version checks, Python package verification) and replaced with a 5-phase continuity reconstruction protocol reading exclusively from repo-local artifacts
- Both skills have explicit prohibition/boundary language: cortex-spec "does NOT auto-invoke GSD"; cortex-status "Does NOT read .planning/STATE.md or any GSD planning state"

## Task Commits

Each task was committed atomically:

1. **Task 1: Create skills/cortex-spec/SKILL.md (net-new)** - `9a3ab03` (feat)
2. **Task 2: Replace skills/cortex-status/SKILL.md (behavioral replacement)** - `6ddd25d` (feat)

**Plan metadata:** (pending final commit)

## Files Created/Modified

- `skills/cortex-spec/SKILL.md` — Net-new skill: /cortex-spec command, 5-phase protocol writing spec/handoff/contract with prerequisite gates and explicit GSD prohibition
- `skills/cortex-status/SKILL.md` — Full behavioral replacement: /cortex-status now reconstructs continuity from repo-local artifacts, reads current-state.md + state.json, writes refreshed next-prompt.md

## Decisions Made

- `eval_plan` field is mandatory on every contract — matches Phase 02-01 decision already in STATE.md; skill explicitly calls this out
- cortex-spec does NOT auto-invoke GSD — matches COMMANDS.md decision; stated explicitly in Rules section
- cortex-status reads from exactly two state sources: current-state.md and state.json — no GSD state, no chat history required
- Old system-health checks (API keys, upstream/superpowers, claude-stack-env, Python packages) fully removed — not retirement-compatible with the vNext continuity model

## Deviations from Plan

None — plan executed exactly as written.

The only minor fix: the automated verify check used `grep -c "does NOT"` (lowercase "does") while the initial draft had "Does NOT" (uppercase). Fixed by using "does NOT" literally in the Rules section phrase: "This skill does NOT auto-invoke GSD." No behavioral change.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Both skills are ready for plan 03-03 (if any additional skills are needed in this phase)
- cortex-spec is the critical path skill: it closes the clarify → research → spec loop and produces the GSD handoff pack
- cortex-status is the recovery skill: safe to run after /clear or compaction to reconstruct full context
- Templates relied upon (spec.md, gsd-handoff.md, contract.md, next-prompt.md) are all present from Phase 02

---
*Phase: 03-new-and-updated-skills*
*Completed: 2026-03-29*
