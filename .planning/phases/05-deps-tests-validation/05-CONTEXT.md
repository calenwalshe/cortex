# Phase 5: Dependency Tracking + Tests + Validation - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Wire JTMS Lite dependency tracking into inference rules so retraction cascades, write comprehensive tests, and run end-to-end validation of the full Cortex belief memory pipeline.

</domain>

<decisions>
## Implementation Decisions

- **derived_dependencies wired into rules** — each rule records what it depended on when it fired
- **Cascading invalidation** — when source form retracted, recursive CTE finds dependents, marks stale, recomputes
- **8+ pytest tests** covering: scope columns, promotion logic, dependency tracking, cross-project query, soft-fail
- **End-to-end validation** — run cortex-clarify → cortex-research → cortex-spec on test slug, verify beliefs accumulate

### Claude's Discretion

- Test fixture design (in-memory SQLite vs temp dirs)
- Whether to mock Haiku calls in tests or use real extraction
- How deep the dependency cascade goes (1 level vs recursive)

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/cortex-belief-memory/spec.md (Section 8, Steps 6-8)
- docs/cortex/research/cortex-belief-memory/concept-20260420T020000Z.md (F5: JTMS Lite)
- ~/memory/vault/scripts/l3_module.py (existing inference rules)
- ~/memory/vault/scripts/test_knowledge_engine.py (existing test patterns)

</canonical_refs>

<specifics>
## Specific Ideas

- Modify each inference rule's evaluate() to also return dependency edges
- After creating a derived object, write its dependencies to derived_dependencies table
- invalidate_dependents(form_id) uses: WITH RECURSIVE dep_chain AS (...)
- Test: retract a source form → verify downstream derived objects get invalidated

</specifics>

<deferred>
## Deferred Ideas

- Full TMS with assumption sets
- Belief confidence propagation through dependency chains
- Performance benchmarking at scale (10K+ forms)

</deferred>

---

*Phase: 05-deps-tests-validation*
*Context gathered: 2026-04-20 via /cortex-bridge*
