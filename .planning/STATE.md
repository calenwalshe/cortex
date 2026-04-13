---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: cortex-vault
status: in_progress
stopped_at: Phase 2 skill wiring complete
last_updated: "2026-04-13T16:00:00Z"
last_activity: 2026-04-13 — Completed Phase 2 skill insertions (cortex-clarify, cortex-research, cortex-spec)
progress:
  total_phases: 2
  completed_phases: 1
  total_plans: 2
  completed_plans: 2
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-13)

**Core value:** Each new Cortex slug starts with accumulated cross-slug learnings rather than from zero — decisions made, approaches failed, and lessons learned in prior slugs are automatically available at session start without any manual curation.
**Current focus:** Phase 2 complete — all skill insertions wired

## Current Position

Phase: 2 of 2 (Wire skill insertions)
Plan: 2 of 2
Status: Phase complete
Last activity: 2026-04-13 — Completed 02-02-PLAN (skill wiring)

Progress: [█████████████████████] 2/2 plans; 1/2 phases complete (Phase 1 done per prompt context; Phase 2 now done)

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

## Accumulated Context

### Decisions

Bridge import from Cortex contract: docs/cortex/contracts/cortex-vault/contract-001.md

Key architectural decisions already locked:
- Write path: direct `add_fact()` via `sys.path.insert` import (NOT subprocess — fact_store.py has no CLI interface)
- Read path: `recall_query.py --top-k 5 --project cortex` shallow mode (no --deep, target <3s)
- Idempotency key: `(session_id, topic, content[:50])` — check before every `add_fact()` call
- Budget guard: `max(0, 9500 - len(existing_content))` — truncate vault facts to available space
- Hook injection point: after outer `if [[ -f "$FACTS_FILE"...]]` closes, before `HEALTH=""` line
- 9 extraction categories: scope-exclusion, owner-constraint, design-assumption, research-finding, architecture-decision, adjacent-finding, failed-approach, risk-mitigation (memory_type=procedural), open-question

### Pending Todos

None.

### Blockers/Concerns

eval_plan is pending — run /cortex-research --phase evals to produce eval plan before final close.

### Phase 2 Decisions

| Decision | Context |
|----------|---------|
| Rename critique phases (4c→4d, 2.9→2.95, 2c→2d) | Contract done criteria name Phase 4c/2.9/2c for vault extractor — vault extractor must claim those labels |
| Synchronous extractor invocation | Consistent with cortex-critique pattern; no async benefit |
| Extractor skip on evals path (research) | Evals artifacts have different schema; skip condition inherited from existing Phase 2.9 pattern |

## Session Continuity

Last session: 2026-04-13T16:00:00Z
Stopped at: Completed 02-02-PLAN — all Phase 2 skill insertions wired
Resume file: None
