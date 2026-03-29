---
phase: 03-new-and-updated-skills
plan: 01
subsystem: skills
tags: [cortex-clarify, cortex-research, skill, problem-framing, research-pipeline]

# Dependency graph
requires:
  - phase: 02-artifact-scaffolding-and-templates
    provides: templates/cortex/clarify-brief.md, templates/cortex/research-dossier.md, templates/cortex/eval-proposal.md, docs/cortex/ directory structure
provides:
  - skills/cortex-clarify/SKILL.md — net-new clarify command with 5-phase instructions
  - skills/cortex-research/SKILL.md — updated with --phase/--depth interface and correct output routing
affects: [cortex-spec, cortex-status, all commands that depend on clarify brief gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "cortex-clarify is the mandatory gate to all downstream commands — no research without brief"
    - "Artifact paths use YYYYMMDDTHHMMSSZ compact timestamps (filesystem-safe)"
    - "Both skills update docs/cortex/handoffs/current-state.md and .cortex/state.json gates"

key-files:
  created:
    - skills/cortex-clarify/SKILL.md
  modified:
    - skills/cortex-research/SKILL.md

key-decisions:
  - "cortex-clarify explicitly blocks if active slug conflict detected in state.json"
  - "cortex-research Phase 0 blocks with explicit error message if no clarify brief found — not silent"
  - "--phase evals branches to eval-proposal.md (not research dossier) and uses different template"
  - "All tool invocations from legacy cortex-research preserved (Tavily, Jina, Perplexity, gpt-researcher, Gemini, Crawl4AI)"
  - "Legacy --quick/--deep flags fully removed; replaced by --depth quick|standard|deep"
  - "Legacy ~/research/ output path fully removed; replaced by docs/cortex/research/{slug}/{phase}-{timestamp}.md"

patterns-established:
  - "Each skill ends with a continuity update step (current-state.md + state.json)"
  - "Output always repo-local — chat-only responses do not satisfy commands"
  - "Phase flags (--phase) are separators: each invocation produces one artifact per phase, not combined"

requirements-completed: [CMD-01, CMD-02]

# Metrics
duration: 2min
completed: 2026-03-29
---

# Phase 3 Plan 01: New and Updated Skills Summary

**cortex-clarify SKILL.md (net-new, 5-phase problem framing) and cortex-research SKILL.md (vNext interface with --phase/--depth flags, docs/cortex/ output routing, and --phase evals branch)**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-29T03:04:51Z
- **Completed:** 2026-03-29T03:06:51Z
- **Tasks:** 2
- **Files modified:** 2 (1 created, 1 rewritten)

## Accomplishments

- Created `skills/cortex-clarify/SKILL.md` from scratch: 5-phase instructions (slug derivation, state check, brief population, artifact write, continuity update), all 7 clarify-brief template sections covered, clarify_complete gate flip, output at `docs/cortex/clarify/{slug}/{timestamp}-clarify-brief.md`
- Rewrote `skills/cortex-research/SKILL.md`: replaced legacy `--quick`/`--deep` flags and `~/research/` path with `--phase concept|implementation|evals` + `--depth quick|standard|deep`, added Phase 0 clarify-brief gate, added --phase evals branch to `docs/cortex/evals/{slug}/eval-proposal.md`, preserved all 7 tool invocations
- Both skills now update `docs/cortex/handoffs/current-state.md` and `.cortex/state.json` as final step

## Task Commits

1. **Task 1: Create skills/cortex-clarify/SKILL.md (net-new)** - `7588d47` (feat)
2. **Task 2: Update skills/cortex-research/SKILL.md (behavioral extension)** - `747cec7` (feat)

**Plan metadata:** _(docs commit follows)_

## Files Created/Modified

- `skills/cortex-clarify/SKILL.md` — Net-new problem framing skill, 125 lines, gates all downstream research and spec commands
- `skills/cortex-research/SKILL.md` — Rewritten with vNext interface, 201 lines, --phase/--depth flags, docs/cortex/ routing, evals branch

## Decisions Made

- cortex-research Phase 0 uses an explicit blocking error message when no clarify brief is found (not silent skip) — keeps the human aware of gate requirements
- --phase evals uses a completely different template (eval-proposal.md) and writes to a different path (docs/cortex/evals/) — consistent with COMMANDS.md spec
- Legacy tool invocations preserved verbatim — behavioral update, not a pipeline replacement

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- cortex-clarify SKILL.md is ready for use — the intelligence spine's first command is now operational
- cortex-research SKILL.md is aligned with COMMANDS.md vNext interface
- Remaining skills in Phase 3 (cortex-spec, cortex-status, and any others) can proceed

---
*Phase: 03-new-and-updated-skills*
*Completed: 2026-03-29*
