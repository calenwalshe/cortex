# Phase 1: Schema Migration + Bridge Foundation - Context

**Gathered:** 2026-04-20
**Status:** Ready for execution
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Extend beliefs.db schema with scope columns and dependency tracking table, then create the bridge script that all Cortex skills will import for belief operations. This phase produces all infrastructure — subsequent phases only wire skills to call it.

</domain>

<decisions>
## Implementation Decisions

- **scope_type/scope_id on logical_forms** — explicit scope columns, not namespace-only filtering. scope_type='global' (default) or 'project', scope_id=NULL or slug string. Research finding F3.
- **derived_dependencies table** — JTMS Lite with (derived_object_id, source_kind, source_id, role). Cascading invalidation via SQLite recursive CTE. Research finding F5.
- **3-stage retrieval** — global stable → recurring project → caution set. SQL view pattern from research finding F6.
- **Soft-fail everywhere** — every bridge function wrapped in try/except. Skills proceed without vault.
- **2000 char cap** — belief injection formatted as compact bullets, truncated at budget.

### Claude's Discretion

- Exact format of compact belief bullets (subject: content vs full form dump)
- Whether to add indexes on scope_type+scope_id immediately or defer
- Bridge script internal organization (single file vs module)

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/cortex-belief-memory/spec.md
- docs/cortex/specs/cortex-belief-memory/gsd-handoff.md
- docs/cortex/contracts/cortex-belief-memory/contract-001.md
- docs/cortex/research/cortex-belief-memory/concept-20260420T020000Z.md
- ~/memory/vault/scripts/belief_store.py (existing L3 CRUD)
- ~/memory/vault/scripts/l3_engine.py (existing L3 runtime)
- ~/memory/vault/scripts/source_store.py (existing intake CRUD)

</canonical_refs>

<specifics>
## Specific Ideas

- ALTER TABLE logical_forms ADD COLUMN scope_type TEXT NOT NULL DEFAULT 'global'; ALTER TABLE logical_forms ADD COLUMN scope_id TEXT;
- Backfill all existing forms as scope_type='global' (they predate slug scoping)
- Bridge functions: query_beliefs(topic, slug), ingest_and_extract(artifact_path, slug), promote_on_close(slug), invalidate_dependents(form_id)
- Cross-project query SQL from research: WHERE (scope_type='global' AND status IN ('active','stable')) OR (scope_id=:slug AND world_id NOT IN ('rejected'))

</specifics>

<deferred>
## Deferred Ideas

- CortexModule as separate L3 module
- canonical_hash deduplication
- utility_score with decay on promoted beliefs
- origin_kind (observed|inferred|promoted) tracking

</deferred>

---

*Phase: 01-schema-bridge*
*Context gathered: 2026-04-20 via /cortex-bridge*
