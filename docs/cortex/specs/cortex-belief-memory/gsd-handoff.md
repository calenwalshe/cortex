# GSD Handoff: cortex-belief-memory

**Slug:** cortex-belief-memory
**Timestamp:** 20260420T034000Z
**Status:** draft

---

## Objective

Wire the SCAPE belief engine into the Cortex discovery loop so that each clarify→research→spec cycle accumulates typed beliefs, research builds on stable ground instead of re-covering it, specs generate from the belief state, and knowledge earned during discovery promotes to long-term memory when the slug closes.

---

## Deliverables

- `~/memory/vault/scripts/cortex_belief_bridge.py` — bridge script for Cortex→vault belief operations
- `~/memory/vault/scripts/test_cortex_belief_bridge.py` — test suite
- `~/memory/vault/beliefs.db` — schema extended (scope_type, scope_id on logical_forms; derived_dependencies table)
- `~/.claude/skills/cortex-clarify/SKILL.md` — Phase 3.5 + Phase 4c.5 additions
- `~/.claude/skills/cortex-research/SKILL.md` — Phase 0.5 + Phase 2.9b additions
- `~/.claude/skills/cortex-spec/SKILL.md` — Phase 1d.5 + Phase 2c.5 additions
- `~/.claude/skills/cortex-close/SKILL.md` — Phase 5.5 addition

---

## Requirements

- None formalized

---

## Tasks

- [ ] ALTER TABLE logical_forms ADD COLUMN scope_type TEXT DEFAULT 'global', scope_id TEXT; create indexes
- [ ] Backfill existing 2330 forms with scope_type='global'
- [ ] CREATE TABLE derived_dependencies with cascading invalidation support
- [ ] Create cortex_belief_bridge.py: query_beliefs(), ingest_and_extract(), promote_on_close(), invalidate_dependents(), all with soft-fail
- [ ] Implement 3-stage cross-project belief query (global stable → recurring → caution)
- [ ] Implement compact belief injection formatting (max 2000 chars)
- [ ] Add Phase 3.5 to cortex-clarify: query prior constraints/exclusions before writing brief
- [ ] Add Phase 4c.5 to cortex-clarify: inline L3 extraction after artifact creation
- [ ] Add Phase 0.5 to cortex-research: query beliefs before question routing
- [ ] Add Phase 2.9b to cortex-research: inline L3 extraction after dossier creation
- [ ] Add Phase 1d.5 to cortex-spec: query architecture precedents before synthesizing
- [ ] Add Phase 2c.5 to cortex-spec: inline L3 extraction after spec creation
- [ ] Add Phase 5.5 to cortex-close: L3 finalization + selective promotion (lessons/design_rules only)
- [ ] Wire derived_dependencies into inference rules
- [ ] Implement soft-fail wrappers for all vault calls
- [ ] Write 8+ pytest tests
- [ ] End-to-end validation: full Cortex cycle with belief accumulation

---

## Acceptance Criteria

- [ ] cortex-clarify queries vault beliefs before writing brief
- [ ] cortex-research queries vault beliefs before question routing
- [ ] cortex-spec queries vault beliefs before synthesizing
- [ ] All 3 skills call vault ingest + L3 extraction inline after artifact creation
- [ ] cortex-close runs L3 finalization and promotes lessons/design_rules to global
- [ ] logical_forms has scope_type/scope_id columns with backfill
- [ ] derived_dependencies table exists
- [ ] Cross-project query returns 3-stage results
- [ ] All 4 skills work unchanged when vault is unreachable
- [ ] Belief injection capped at 2000 chars
- [ ] 8+ pytest tests pass

---

## Contract Link

docs/cortex/contracts/cortex-belief-memory/contract-001.md
