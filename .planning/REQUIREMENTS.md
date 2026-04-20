# Requirements: cortex-belief-memory

**Defined:** 2026-04-20
**Core Value:** Every Cortex discovery cycle accumulates typed, provenanced beliefs that persist across session boundaries, so research doesn't re-cover stable ground, specs are generated from the belief state, and knowledge earned during discovery survives slug closure to inform future work.

## Belief Memory Requirements

- [ ] **BM-01**: Schema migration — add scope_type/scope_id to logical_forms + derived_dependencies table
- [ ] **BM-02**: Bridge script — cortex_belief_bridge.py with query, ingest, promote, invalidate functions
- [ ] **BM-03**: Skill reads — belief queries injected into cortex-clarify, cortex-research, cortex-spec
- [ ] **BM-04**: Skill writes — L3 extraction wired into cortex-clarify, cortex-research, cortex-spec
- [ ] **BM-05**: Promotion — cortex-close promotes lessons/design_rules to global scope
- [ ] **BM-06**: Dependency tracking — derived_dependencies with cascading invalidation
- [ ] **BM-07**: Soft-fail — all vault calls wrapped in try/except, skills work without vault
- [ ] **BM-08**: Tests — 8+ pytest tests covering all integration points

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| **BM-01** | Phase 1: Schema Migration + Bridge Foundation | Pending |
| **BM-02** | Phase 1: Schema Migration + Bridge Foundation | Pending |
| **BM-03** | Phase 2: Skill Read Integration | Pending |
| **BM-04** | Phase 3: Skill Write Integration | Pending |
| **BM-05** | Phase 4: Promotion + Close | Pending |
| **BM-06** | Phase 1 + Phase 5 | Pending |
| **BM-07** | Phase 1: Schema Migration + Bridge Foundation | Pending |
| **BM-08** | Phase 5: Dependency Tracking + Tests + Validation | Pending |

**Coverage:**
- Belief Memory requirements: 8 total -- all mapped
- Unmapped: 0
