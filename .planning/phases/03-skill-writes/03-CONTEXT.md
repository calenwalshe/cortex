# Phase 3: Skill Write Integration - Context

**Gathered:** 2026-04-20
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

Wire L3 extraction into 3 Cortex skills (clarify, research, spec) so that after each artifact is created, it's ingested into sources.db and processed through the L3 engine (extract forms → assign worlds → run inference). Inline, not async.

</domain>

<decisions>
## Implementation Decisions

- **Inline extraction** — Gemini research confirmed: for 2-4 cycle workflows, stale beliefs cost more than 1-2s latency
- **cortex-clarify Phase 4c.5** — after existing vault extractor (Phase 4c), call bridge.ingest_and_extract()
- **cortex-research Phase 2.9b** — after existing vault extractor (Phase 2.9), call bridge.ingest_and_extract()
- **cortex-spec Phase 2c.5** — after existing vault extractor (Phase 2c), call bridge.ingest_and_extract()
- **Soft-fail** — if L3 engine unavailable, log warning and continue

### Claude's Discretion

- Whether to pass project scope or slug as the scope_id for new forms
- Whether extraction runs on the full artifact or just key sections

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/cortex-belief-memory/spec.md (Section 8, Step 4)
- docs/cortex/research/cortex-belief-memory/concept-20260420T020000Z.md (F2, F7)
- ~/.claude/skills/cortex-clarify/SKILL.md (Phase 4c)
- ~/.claude/skills/cortex-research/SKILL.md (Phase 2.9)
- ~/.claude/skills/cortex-spec/SKILL.md (Phase 2c)

</canonical_refs>

<specifics>
## Specific Ideas

- bridge.ingest_and_extract(artifact_path, slug) handles: source_store.ingest → l3_engine.extract_forms → l3_engine.run_inference
- New forms get scope_type='project', scope_id=slug
- Existing vault extractor continues to run (writes to facts.db) — L3 extraction is additive

</specifics>

<deferred>
## Deferred Ideas

- Async extraction via post-hook for high-latency scenarios
- Extraction prompt tuning for Cortex artifact structure (vs atom-oriented prompt)

</deferred>

---

*Phase: 03-skill-writes*
*Context gathered: 2026-04-20 via /cortex-bridge*
