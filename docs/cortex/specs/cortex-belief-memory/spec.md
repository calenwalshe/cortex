# Spec: cortex-belief-memory

**Slug:** cortex-belief-memory
**Timestamp:** 20260420T034000Z
**Status:** draft

---

## 1. Problem

The Cortex discovery loop (clarify → research → spec) loses knowledge at every session boundary. Research cycle 2 doesn't know what cycle 1 established as stable. Spec generation reads dossier text, not a typed belief state. When a slug closes, everything learned during discovery evaporates — the next slug starts from scratch even on related topics. A working belief engine exists (`beliefs.db` with Kripke worlds, logical forms, 4 inference rules, 2330 forms, 388 derived objects) but no Cortex skill reads from it or writes to it beyond flat fact extraction. The discovery loop needs to accumulate, query, and promote beliefs so research builds on stable ground, specs are informed by the belief state, and knowledge earned during discovery survives slug closure.

---

## 2. Acceptance Criteria

- [ ] `cortex-clarify` queries vault beliefs for prior constraints/exclusions before writing the brief (Phase 3.5 insertion)
- [ ] `cortex-research` queries vault beliefs before question routing, surfacing "prior work found X — building on that" (Phase 0.5 insertion)
- [ ] `cortex-spec` queries vault beliefs for architecture decisions and failed approaches before synthesizing (Phase 1d.5 insertion)
- [ ] All 3 skills call `vault ingest` + `l3_engine.py extract_forms` + `run_inference` inline after artifact creation
- [ ] `cortex-close` runs L3 inference finalization and promotes lessons/design_rules to global scope (Phase 5.5)
- [ ] `logical_forms` table has `scope_type` and `scope_id` columns with backfill of existing 2330 forms
- [ ] `derived_dependencies` table exists for JTMS Lite cascading invalidation
- [ ] Cross-project belief query returns 3-stage results: global stable → recurring project → caution set
- [ ] Vault-unavailable soft-fail: all 4 skills continue working unchanged when vault is unreachable
- [ ] Belief reads inject a "Known Beliefs" section into skill working context (max 2000 chars)
- [ ] 8+ pytest tests cover: scope columns, promotion logic, dependency tracking, cross-project query, soft-fail

---

## 3. Scope

### In Scope

- Add `scope_type`/`scope_id` columns to `logical_forms` table + backfill existing forms
- Add `derived_dependencies` table for JTMS Lite dependency tracking
- Modify 4 Cortex skill SKILL.md files with belief read/write phases
- Build `cortex_belief_bridge.py` — thin wrapper that Cortex skills call for vault belief operations
- Implement 3-stage cross-project belief retrieval query
- Implement promotion logic in cortex-close (selective: lessons/design_rules only)
- Implement cascading invalidation via derived_dependencies
- Soft-fail wrappers for all vault calls

### Out of Scope

- New inference rules (4 existing rules sufficient)
- CortexModule as a separate L3 module (per critique finding — orphan work, defer)
- Datalog/Soufflé or any formal logic engine
- UI changes to memory.calenwalshe.com dashboard
- Modifications to GSD execution pipeline
- Replacing .cortex/facts.jsonl (complementary, not replacement)
- Full TMS/ATMS implementation
- `canonical_hash` deduplication (defer)

---

## 4. Architecture Decision

**Chosen approach:** A thin bridge script (`cortex_belief_bridge.py`) that Cortex skills import to read/write beliefs via the existing vault engine. Skills call bridge functions at specific insertion points; the bridge handles vault availability checking, scope management, and soft-fail. Schema extended with scope columns + dependency table.

**Rationale:** The belief engine already exists and works (2330 forms, 388 derived objects). The integration is purely plumbing — connecting existing Cortex skill phases to existing vault operations via a bridge layer. The bridge isolates Cortex from vault internals and provides the soft-fail guarantee (skills work without vault).

**Note:** The clarify brief listed "Modifying the belief engine schema" as a non-goal. Research finding F3 demonstrated that `scope_type`/`scope_id` columns on `logical_forms` are necessary for rebuild independence and promotion logic. This is a minimal ALTER TABLE ADD COLUMN (same pattern successfully applied to atoms.db with zero issues). The non-goal is overridden by research evidence.

### Alternatives Considered

- **Hook-based integration (PostToolUse hook):** Rejected because hooks fire on tool calls, not on Cortex skill phases. A skill can write multiple artifacts across many tool calls — hooks can't distinguish "clarify brief written" from "random file edit."
- **Modify cortex-vault-extractor.py to also do L3:** Rejected because the extractor is a one-way fact writer. L3 needs bidirectional: read beliefs before operating, write forms after. Separate bridge is cleaner.
- **Namespace-only scoping (no schema change):** Rejected per research finding F3 — filtering by namespace + extraction_run creates fragile implicit ownership that breaks on rebuild. Explicit scope columns are safer.

---

## 5. Interfaces

### Reads

- `~/memory/vault/beliefs.db` — logical_forms, form_status, derived_objects, worlds (read by bridge for belief queries)
- `~/memory/vault/sources.db` — sources table (read to check if artifact already ingested)
- `~/.claude/skills/cortex-clarify/SKILL.md` — modified to add Phase 3.5 + Phase 4c.5
- `~/.claude/skills/cortex-research/SKILL.md` — modified to add Phase 0.5 + Phase 2.9b
- `~/.claude/skills/cortex-spec/SKILL.md` — modified to add Phase 1d.5 + Phase 2c.5
- `~/.claude/skills/cortex-close/SKILL.md` — modified to add Phase 5.5

### Writes

- `~/memory/vault/beliefs.db` — ALTER TABLE logical_forms (add scope_type, scope_id); CREATE TABLE derived_dependencies
- `~/memory/vault/scripts/cortex_belief_bridge.py` — new bridge script
- `~/memory/vault/scripts/test_cortex_belief_bridge.py` — tests
- `~/.claude/skills/cortex-clarify/SKILL.md` — Phase 3.5 + Phase 4c.5 additions
- `~/.claude/skills/cortex-research/SKILL.md` — Phase 0.5 + Phase 2.9b additions
- `~/.claude/skills/cortex-spec/SKILL.md` — Phase 1d.5 + Phase 2c.5 additions
- `~/.claude/skills/cortex-close/SKILL.md` — Phase 5.5 addition

---

## 6. Dependencies

- `beliefs.db` (deployed) — L3 belief runtime, Kripke worlds, logical forms, inference engine
- `sources.db` (deployed) — universal source intake layer
- `l3_engine.py` (deployed) — extract_forms(), run_inference(), run_full_pipeline()
- `belief_store.py` (deployed) — CRUD for beliefs.db
- `source_store.py` (deployed) — CRUD for sources.db
- `intake_doc.py` (deployed) — document intake adapter
- `sqlite3` (stdlib) — schema migration
- `cortex-vault-extractor.py` (deployed) — existing fact extraction (continues to run alongside L3)

---

## 7. Risks

- **Vault unavailability breaks Cortex skills** — Mitigation: every bridge call wrapped in try/except with soft-fail logging. Skills proceed without beliefs when vault is unreachable. Tested explicitly.
- **Scope column backfill corrupts existing forms** — Mitigation: ALTER TABLE ADD COLUMN with DEFAULT is atomic in SQLite. Pre/post row count verification. Backup before migration (same pattern used successfully on atoms.db).
- **Belief injection bloats skill context** — Mitigation: cap injected beliefs at 2000 chars. Format as compact bullet list, not full form dumps. Truncate if over budget.
- **L3 extraction latency slows skill execution** — Mitigation: inline extraction adds ~1-2s for single artifacts. Only extract the current artifact, not re-extract all. Acceptable for 2-4 cycle workflows per Gemini analysis.
- **Promotion pollutes long-term memory** — Mitigation: selective promotion policy — only lessons/design_rules auto-promote. Raw forms require 3+ scope recurrence. "6-month test" applied.

---

## 8. Sequencing

1. **Schema migration** — Add `scope_type`/`scope_id` to logical_forms, create `derived_dependencies` table, backfill existing forms as `scope_type='global'`. Verify row count.

2. **Bridge script** — Create `cortex_belief_bridge.py` with functions: `query_beliefs(topic, slug)`, `ingest_and_extract(artifact_path, slug)`, `promote_on_close(slug)`, `invalidate_dependents(form_id)`. All wrapped in soft-fail.

3. **Skill modifications — reads** — Add belief query phases to cortex-clarify (3.5), cortex-research (0.5), cortex-spec (1d.5). Each injects a "Known Beliefs" section into working context.

4. **Skill modifications — writes** — Add L3 extraction phases to cortex-clarify (4c.5), cortex-research (2.9b), cortex-spec (2c.5). Each calls `ingest_and_extract()` inline after artifact creation.

5. **cortex-close promotion** — Add Phase 5.5: run L3 finalization, promote lessons/design_rules to global scope, archive project-scoped forms.

6. **Dependency tracking** — Wire `derived_dependencies` into inference rules. When a source form is retracted, cascade invalidation via recursive CTE.

7. **Tests** — 8+ pytest tests covering scope columns, promotion, dependency cascading, cross-project query, soft-fail.

8. **Validation** — End-to-end: run cortex-clarify on a test slug → cortex-research → cortex-spec → verify beliefs accumulate and are queryable across phases.

---

## 9. Tasks

- [ ] ALTER TABLE logical_forms ADD COLUMN scope_type, scope_id + indexes
- [ ] Backfill existing 2330 forms with scope_type='global'
- [ ] CREATE TABLE derived_dependencies (derived_object_id, source_kind, source_id, role)
- [ ] Create `cortex_belief_bridge.py` with query_beliefs(), ingest_and_extract(), promote_on_close(), invalidate_dependents()
- [ ] Implement 3-stage cross-project belief query (global stable → recurring → caution)
- [ ] Implement belief injection formatting (compact bullets, max 2000 chars)
- [ ] Add Phase 3.5 to cortex-clarify SKILL.md (query prior constraints/exclusions)
- [ ] Add Phase 4c.5 to cortex-clarify SKILL.md (inline L3 extraction)
- [ ] Add Phase 0.5 to cortex-research SKILL.md (query beliefs before routing)
- [ ] Add Phase 2.9b to cortex-research SKILL.md (inline L3 extraction)
- [ ] Add Phase 1d.5 to cortex-spec SKILL.md (query architecture precedents)
- [ ] Add Phase 2c.5 to cortex-spec SKILL.md (inline L3 extraction)
- [ ] Add Phase 5.5 to cortex-close SKILL.md (L3 finalization + selective promotion)
- [ ] Wire derived_dependencies into inference rules for cascading invalidation
- [ ] Implement soft-fail wrappers (try/except + logging) for all vault calls
- [ ] Write 8+ pytest tests (scope, promotion, dependency, cross-project, soft-fail)
- [ ] End-to-end validation: clarify → research → spec on test slug with belief accumulation
