---
slug: cortex-belief-memory
brief_iteration: 1
last_updated: 2026-04-20
---

# Current Understanding: cortex-belief-memory

---

## Possible Terminals

| Terminal | Status | Ruled-Out Reason | Evidence |
|---|---|---|---|
| commit-to-build | **live** | — | Belief engine exists and works; integration points are well-defined |
| kill-with-learning | ruled-out | Problem is real — Cortex loses knowledge at session boundaries | 233K-char research doc + working belief engine |
| decompose | **live** | — | Could split into: (a) auto-ingest hook, (b) CortexModule, (c) research pre-query, (d) spec belief-reader |
| experiment-required | ruled-out | Belief engine already validated with 2330 forms, 388 derived objects, 1371 inferences | Live system on ~/memory/vault/ |
| already-exists | ruled-out | .cortex/facts.jsonl is flat extraction — no worlds, no status tracking, no inference | facts.jsonl has no belief state |
| hold-on-dependency | ruled-out | All dependencies available (beliefs.db, sources.db, l3_engine.py deployed) | — |

---

## Durable Findings

- The SCAPE belief engine is deployed and validated: 2330 logical forms, 8 Kripke worlds, 4 inference rules, 388 derived objects (302 lessons, 86 contradictions) — Source: live system at ~/memory/vault/beliefs.db
- The engine supports namespaced derived objects via `namespace` column — can scope to `cortex:{slug}` without schema changes — Source: belief_store.py derived_objects table
- Cortex already has a fact extraction hook (`cortex-vault-extractor.py`) that runs after artifact creation — Source: cortex-clarify SKILL.md Phase 4c, cortex-spec SKILL.md Phase 2c
- The existing vault intake adapters (intake_doc.py, intake_notes.py) can ingest any Cortex artifact — Source: source_store.py, tested with 139K-char research doc
- L3 extraction via Haiku takes ~1-2s per atom/source — acceptable for post-skill async but possibly too slow for inline blocking — Source: backfill run of 415 atoms
- 7 formal logic systems were evaluated for L3 (Datalog, TMS/ATMS, OWL, Event Calculus, ASP, Z3, Modal/Kripke); pure Python was chosen for v1 — Source: ChatGPT research doc chunks 39-40
- The short-term/long-term memory split maps to: short-term = CortexModule (namespace cortex:{slug}), long-term = PersonalMemoryModule (namespace personal:*) — Source: design discussion in current session

---

## Provisional Thoughts

- **[PROVISIONAL]** logical_forms may need a `slug` column (not just derived_objects namespace) so forms themselves are scoped, not just derived objects
- **[PROVISIONAL]** Promotion policy on slug close: promote forms with `status=stable` + derived objects of type `lesson` and `design_rule` to `personal:*` namespace; archive everything else
- **[PROVISIONAL]** Research pre-query should inject a `## Known Beliefs` section at the top of the research agent's prompt, not modify the clarify brief
- **[PROVISIONAL]** Async extraction via post-hook is better than inline — keeps skill execution snappy; the belief state is available for the NEXT cycle, not the current one
- **[PROVISIONAL]** TMS dependency tracking is not needed for v1 — flagging contested beliefs for human review is sufficient; auto-retraction adds complexity without clear value at current scale

---

## Research Notes

- **Use `/chrome-query` with pro modes (ChatGPT Pro, Gemini Advanced) for concept research.** The mechanism and comparison questions (TMS design patterns, Datalog integration strategies, belief scoping models) benefit from deep reasoning mode responses rather than search-based results. Route through Chrome browser proxy to leverage pro-tier models.

---

## Open Questions

- Should logical_forms get a `slug` column for scoping, or is filtering by `extraction_run` + source provenance sufficient? — *Revisit when:* designing the namespace model
- What happens to short-term beliefs when a slug is decomposed into child slugs? Do they inherit? — *Revisit when:* decompose terminal is in play
- Should the CortexModule have different inference rules than PersonalMemoryModule? (e.g., "plan without outcome → open_thread" is more relevant for Cortex) — *Revisit when:* designing CortexModule
- How does `vault beliefs` output format into the research agent's prompt without blowing the token budget? — *Revisit when:* implementing research pre-query

---

## Iteration History

| Iteration | Brief | Dossier | Reframe Reason |
|---|---|---|---|
| 1 | docs/cortex/clarify/cortex-belief-memory/20260420T010000Z-clarify-brief.md | TBD | (initial) |
