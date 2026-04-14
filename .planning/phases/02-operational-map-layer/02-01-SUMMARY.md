---
phase: 02-operational-map-layer
plan: "01"
subsystem: skill-injection
tags: [cortex-clarify, cortex-spec, operational-indexer, skill-injection]
one-liner: "Inject operational-context read phase into clarify (Phase 2d) and spec (Phase 1e) skills, wiring hotspot and co-change data from the edit ledger into intelligence-phase working context"

dependency-graph:
  requires:
    - 01-01: operational-indexer.py --summary mode (provides JSON output consumed here)
    - 01-02: edit-ledger schema (hotspots and co_change_pairs fields)
    - 01-03: hook registration (ledger populated by session events)
  provides:
    - cortex-clarify Phase 2d: reads operational summary before writing clarify brief
    - cortex-spec Phase 1e: reads operational summary before synthesizing spec
  affects:
    - 02-02: session-start anchor (adjacent Phase 2 plan in same phase)
    - future clarify runs: hotspots auto-inform Write Roots
    - future spec runs: co-change pairs auto-inform Section 7 Risks

tech-stack:
  added: []
  patterns:
    - soft-fail pipeline injection (2>/dev/null || echo fallback JSON)
    - inline working-context enrichment before LLM phase execution

key-files:
  created: []
  modified:
    - skills/cortex-clarify/SKILL.md
    - skills/cortex-spec/SKILL.md

decisions:
  - description: "Inject as new Phase 2d/1e steps rather than modifying existing phases"
    rationale: "Preserves existing phase semantics; additive insertion avoids breaking existing clarify/spec behavior"
  - description: "Soft-fail always — ledger absence never blocks the pipeline"
    rationale: "New sessions or repos without ledger history must not be gated; value is additive not required"
  - description: "Use 2>/dev/null fallback echo pattern (not try/catch)"
    rationale: "Consistent with existing soft-fail conventions in cortex-clarify Phase 2c and cortex-spec Phase 1d structural graph steps"

metrics:
  duration: "~2 min"
  completed: "2026-04-14"
---

# Phase 02 Plan 01: Skill Injection — Operational Context Summary

## What Was Built

Injected two new intelligence-phase steps:

1. **cortex-clarify Phase 2d** — inserted after Phase 2c (structural graph) and before Phase 3 (populate clarify brief). Runs `operational-indexer.py --summary`, parses hotspots and co-change pairs, and injects an `### Operational Context (auto-indexed):` block into working context. Hotspots inform Write Roots; co-change pairs flag coupling risks in Open Questions.

2. **cortex-spec Phase 1e** — inserted after Phase 1d (structural graph) and before Phase 2 (synthesize spec). Same indexer invocation and JSON parsing. Hotspots inform Section 5 Interfaces write roots; co-change pairs inform Section 7 Risks.

Both phases use identical soft-fail pattern: `2>/dev/null || echo '{"hotspots":[],"co_change_pairs":[],"caveat":"ledger absent"}'`. If hotspots is empty, the phase logs "no operational context available" and proceeds without error.

## Verification

- `grep -c "operational-indexer" /home/agent/.claude/skills/cortex-clarify/SKILL.md` → 1
- `grep -c "operational-indexer" /home/agent/.claude/skills/cortex-spec/SKILL.md` → 1
- Phase 2c still present in clarify; Phase 3 still present after 2d
- Phase 1d still present in spec; Phase 2 still present after 1e
- Both injections include `2>/dev/null` soft-fail

## Deviations from Plan

None — plan executed exactly as written.

## Next Phase Readiness

Plan 02-02 (session-start anchor) is adjacent in Phase 2. No blockers from this plan.
