---
phase: "02"
plan: "02"
subsystem: cortex-vault
tags: [cortex-vault, skill-integration, extractor, vault-facts]
one-liner: "Vault extractor wired into all 3 intelligence-phase skill files at Phase 4c/2.9/2c with soft-fail non-blocking pattern"

dependency-graph:
  requires:
    - "01-cortex-vault — extractor script (cortex-vault-extractor.py) must exist and pass tests"
  provides:
    - "skills/cortex-clarify/SKILL.md Phase 4c vault extraction step"
    - "skills/cortex-research/SKILL.md Phase 2.9 vault extraction step"
    - "skills/cortex-spec/SKILL.md Phase 2c vault extraction step"
  affects:
    - "Future cortex-vault Phase 3 (session-start injection) — vault now populated at all three gate points"

tech-stack:
  added: []
  patterns:
    - "Soft-fail extractor invocation: exit-code check with warning-only on failure"
    - "Phase numbering: insert before critique step, rename critique to next suffix"

key-files:
  created: []
  modified:
    - "skills/cortex-clarify/SKILL.md"
    - "skills/cortex-research/SKILL.md"
    - "skills/cortex-spec/SKILL.md"

decisions:
  - "Inserted vault extractor at Phase 4c/2.9/2c by renaming existing cortex-critique phases to 4d/2.95/2d respectively — preserves contract numbering from done criteria 10-12"
  - "Vault extractor skip condition inherited in cortex-research Phase 2.9 to match existing evals-phase skip behavior"

metrics:
  duration: "10 minutes"
  completed: "2026-04-13"
---

# Phase 02 Plan 02: Cortex Vault Skill Wiring Summary

## Objective

Insert `cortex-vault-extractor.py` calls at three gate transition points in Cortex skill files so that typed vault facts are extracted and persisted whenever a clarify brief, research dossier, or spec is written.

## What Was Built

Three additive insertions into the Cortex intelligence-phase skill files:

1. **`skills/cortex-clarify/SKILL.md` — Phase 4c** (new): Calls `cortex-vault-extractor.py --artifact {clarify_brief_path} --slug {slug}` after the brief is written and before the cortex-critique call (renamed to Phase 4d).

2. **`skills/cortex-research/SKILL.md` — Phase 2.9** (new): Calls `cortex-vault-extractor.py --artifact {dossier_path} --slug {slug}` after the dossier is written. Inherits the existing skip condition for `--phase evals`. Existing cortex-critique renamed to Phase 2.95.

3. **`skills/cortex-spec/SKILL.md` — Phase 2c** (new): Calls `cortex-vault-extractor.py --artifact docs/cortex/specs/{slug}/spec.md --slug {slug}` after spec.md and project-context.md are written. Existing cortex-critique renamed to Phase 2d.

All three insertions use identical soft-fail pattern: extractor exit-code checked; non-zero logs a warning and continues without blocking downstream phases.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Rename existing critique phases (4c→4d, 2.9→2.95, 2c→2d) rather than using novel labels | Contract done criteria 10-12 explicitly name Phase 4c/2.9/2c for vault extractor — honoring the contract numbering requires vault extractor to claim those labels |
| Synchronous extractor invocation | Matches cortex-critique pattern; background would require async handling with no benefit |
| Skip extractor on evals path (research) | Extractor is for intelligence artifacts only; eval proposals have different schema and would produce noise |

## Validators Run

```
grep -n "cortex-vault-extractor" ~/.claude/skills/cortex-clarify/SKILL.md → line 171 PASS
grep -n "cortex-vault-extractor" ~/.claude/skills/cortex-research/SKILL.md → line 678 PASS
grep -n "cortex-vault-extractor" ~/.claude/skills/cortex-spec/SKILL.md → line 268 PASS
```

Judgment validator: soft-fail pattern confirmed in all 3 — extractor failure produces warning, does not halt pipeline.

## Commits

| Commit | Message |
|--------|---------|
| b2a6fc4 | feat(cortex-vault): insert extractor call in cortex-clarify Phase 4c |
| 692f932 | feat(cortex-vault): insert extractor call in cortex-research Phase 2.9 |
| 2864192 | feat(cortex-vault): insert extractor call in cortex-spec Phase 2c |

## Deviations from Plan

None — plan executed exactly as written.

## Next Phase Readiness

Phase 2 complete. The vault extractor is now called at all three intelligence gate transitions. The vault will be populated as users run `/cortex-clarify`, `/cortex-research`, and `/cortex-spec` on any slug. No blockers for subsequent work.
