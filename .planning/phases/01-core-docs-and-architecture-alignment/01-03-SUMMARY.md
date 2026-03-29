---
phase: 01-core-docs-and-architecture-alignment
plan: 03
subsystem: docs
tags: [cortex, evals, agents, readme, markdown, documentation]

# Dependency graph
requires: []
provides:
  - docs/EVALS.md with 8-dimension eval matrix, lifecycle (proposal→approval→plan→execution→repair/assure), artifact paths, and contract reference requirement
  - docs/AGENTS.md with 4-agent roster (specifier, critic, scribe, eval-designer), per-agent write scopes, permission model, Phase 4 status note
  - README.md rewritten with vNext lifecycle framing, 7-command surface, 4-layer architecture table, updated source tree
affects:
  - phase-03-skills (skills must match 7-command surface)
  - phase-04-agents (AGENTS.md is the Phase 4 spec target)
  - phase-05-evals (EVALS.md is the Phase 5 spec target)
  - phase-06-installer (README Quick Start references Phase 6 installer update)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AGENTS.md written as architectural spec (Phase 4 target), not current state — present-tense imperative with Phase 4 status note at top"
    - "EVALS.md uses 8-dimension matrix from REQUIREMENTS.md EVAL-05 verbatim — no invented taxonomy"
    - "README Quick Start defers installer details to Phase 6 — avoids over-promising stale npx command"

key-files:
  created:
    - docs/EVALS.md
    - docs/AGENTS.md
  modified:
    - README.md

key-decisions:
  - "cortex-critic documented as strictly read-only — produces critique returned inline or written by calling command on its behalf, never writes files itself"
  - "UX/taste eval dimension always requires human approval gate — hardcoded, not conditional"
  - "README removes npx github:calenwalshe/cortex installer promise; flags Phase 6 installer update pending"
  - "All eval artifacts (eval-proposal.md, eval-plan.md, results) live in target project repo under docs/cortex/evals/<slug>/, not in cortex framework repo"

patterns-established:
  - "Phase-N deliverable pattern: docs that describe future phases include explicit status note at top ('Phase N deliverables — not yet installed')"
  - "Exact dimension names from REQUIREMENTS.md carried verbatim into EVALS.md table — no paraphrase"

requirements-completed:
  - DOCS-05
  - DOCS-06
  - DOCS-07

# Metrics
duration: 2min
completed: 2026-03-29
---

# Phase 01 Plan 03: Core Docs — EVALS.md, AGENTS.md, README vNext Summary

**docs/EVALS.md and docs/AGENTS.md created as Phase 5/4 architectural specs; README.md rewritten with lifecycle intelligence framing, 7-command surface, and updated source tree replacing stale harmonisation wrapper content**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-03-29T02:20:54Z
- **Completed:** 2026-03-29T02:23:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Created docs/EVALS.md with full eval lifecycle (proposal → human approval → plan → execution → results → repair/assure), 8-dimension matrix using exact REQUIREMENTS.md names, artifact paths under docs/cortex/evals/<slug>/, contract reference requirement, and repair loop rules
- Created docs/AGENTS.md with 4-agent roster, per-agent write scopes, read-only status for cortex-critic, Phase 4 deliverable status note at top, permission model, invocation modes, and installation path
- Rewrote README.md: replaced "harmonizes GSD+Superpowers+GStack" tagline with lifecycle intelligence framing, added 7-command table, 4-layer architecture table, updated source tree showing docs/ with 5 markdown files and all 7 skill subdirectories, removed stale npx installer promise

## Task Commits

1. **Task 1: Create docs/EVALS.md and docs/AGENTS.md** - `deb488d` (feat)
2. **Task 2: Update README.md to vNext framing** - `1249418` (feat)

## Files Created/Modified

- `docs/EVALS.md` — eval lifecycle, 8-dimension matrix, artifact paths, contract reference requirement
- `docs/AGENTS.md` — 4-agent roster with write scopes, permission model, Phase 4 status note
- `README.md` — vNext rewrite: lifecycle framing, 7 commands, 4-layer table, updated source tree

## Decisions Made

- cortex-critic is read-only: produces critique inline or written by calling command on its behalf — it never writes files. This makes the read-only constraint enforceable without exceptions.
- UX/taste eval dimension hardcoded as always requiring human approval — not conditional on context, always a gate.
- README Quick Start defers installer details to Phase 6. Removed npx promise that may not survive vNext installer overhaul.
- All eval artifacts live in the target project repo (not cortex framework repo) — this distinction is explicit in both EVALS.md and AGENTS.md.

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

Phase 1 docs are complete. All 5 docs/\*.md files specified in REQUIREMENTS.md DOCS-02 through DOCS-06 now exist. CORTEX.md (DOCS-01) and README.md (DOCS-07) are also complete from plans 01-01 and 01-03.

Phase 2 (Artifact Scaffolding and Templates) can begin immediately.

---
*Phase: 01-core-docs-and-architecture-alignment*
*Completed: 2026-03-29*
