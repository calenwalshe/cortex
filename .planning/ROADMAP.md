# Roadmap: cortex-belief-memory

## Overview

Wire the SCAPE belief engine into the Cortex discovery loop so that each clarify→research→spec cycle accumulates typed beliefs, research builds on stable ground instead of re-covering it, specs generate from the belief state, and knowledge earned during discovery promotes to long-term memory when the slug closes.

## Phases

### Phase 1: Schema Migration + Bridge Foundation

**Goal**: Extend beliefs.db schema and create the bridge script that all skills will import
**Depends on**: Nothing
**Requirements**: BM-01, BM-02, BM-06, BM-07
**Success Criteria** (what must be TRUE):
  1. logical_forms has scope_type/scope_id columns; existing 2330 forms backfilled
  2. derived_dependencies table exists with source_kind, source_id, role columns
  3. cortex_belief_bridge.py with query_beliefs(), ingest_and_extract(), promote_on_close(), invalidate_dependents()
  4. Cross-project belief query returns 3-stage results: global stable → recurring project → caution set
  5. All 4 skills work unchanged when vault is unreachable (soft-fail verified)
  6. Belief injection capped at 2000 chars in compact format
**Research**: Unlikely
**Plans**: 0 plans

### Phase 2: Skill Read Integration

**Goal**: Wire belief queries into cortex-clarify, cortex-research, cortex-spec before they operate
**Depends on**: Phase 1
**Requirements**: BM-03
**Success Criteria** (what must be TRUE):
  1. cortex-clarify queries vault beliefs for prior constraints/exclusions before writing the brief (Phase 3.5 insertion)
  2. cortex-research queries vault beliefs before question routing, surfacing "prior work found X — building on that" (Phase 0.5 insertion)
  3. cortex-spec queries vault beliefs for architecture decisions and failed approaches before synthesizing (Phase 1d.5 insertion)
  4. Belief reads inject a "Known Beliefs" section into skill working context (max 2000 chars)
**Research**: Unlikely
**Plans**: 0 plans

### Phase 3: Skill Write Integration

**Goal**: Wire L3 extraction into cortex-clarify, cortex-research, cortex-spec after artifact creation
**Depends on**: Phase 1
**Requirements**: BM-04
**Success Criteria** (what must be TRUE):
  1. All 3 skills call vault ingest + l3_engine.py extract_forms + run_inference inline after artifact creation
**Research**: Unlikely
**Plans**: 0 plans

### Phase 4: Promotion + Close

**Goal**: Wire promotion logic into cortex-close so knowledge survives slug closure
**Depends on**: Phase 1
**Requirements**: BM-05
**Success Criteria** (what must be TRUE):
  1. cortex-close runs L3 inference finalization and promotes lessons/design_rules to global scope (Phase 5.5)
**Research**: Unlikely
**Plans**: 0 plans

### Phase 5: Dependency Tracking + Tests + Validation

**Goal**: Wire JTMS Lite into inference rules and validate end-to-end
**Depends on**: Phase 2, Phase 3, Phase 4
**Requirements**: BM-06, BM-08
**Success Criteria** (what must be TRUE):
  1. derived_dependencies table exists for JTMS Lite cascading invalidation
  2. 8+ pytest tests cover: scope columns, promotion logic, dependency tracking, cross-project query, soft-fail
**Research**: Unlikely
**Plans**: 0 plans

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| Phase 1: Schema Migration + Bridge Foundation | 0/0 | Not started | - |
| Phase 2: Skill Read Integration | 0/0 | Not started | - |
| Phase 3: Skill Write Integration | 0/0 | Not started | - |
| Phase 4: Promotion + Close | 0/0 | Not started | - |
| Phase 5: Dependency Tracking + Tests + Validation | 0/0 | Not started | - |
