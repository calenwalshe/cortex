# Contract: cortex-belief-memory — execute

**ID:** cortex-belief-memory-001
**Slug:** cortex-belief-memory
**Phase:** execute
**Created:** 20260420T034000Z
**Status:** draft
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Wire the SCAPE belief engine into 4 Cortex skills so that discovery cycles accumulate beliefs, research builds on stable ground, specs generate from belief state, and knowledge promotes to long-term memory on slug close.

---

## Deliverables

- `~/memory/vault/scripts/cortex_belief_bridge.py` — bridge script
- `~/memory/vault/scripts/test_cortex_belief_bridge.py` — test suite
- `~/memory/vault/beliefs.db` — schema extended (scope columns + dependency table)
- `~/.claude/skills/cortex-clarify/SKILL.md` — belief read/write phases
- `~/.claude/skills/cortex-research/SKILL.md` — belief read/write phases
- `~/.claude/skills/cortex-spec/SKILL.md` — belief read/write phases
- `~/.claude/skills/cortex-close/SKILL.md` — promotion phase

---

## Scope

### In Scope

- scope_type/scope_id columns on logical_forms + backfill
- derived_dependencies table for JTMS Lite
- cortex_belief_bridge.py (query, ingest, promote, invalidate, soft-fail)
- Skill modifications: 4 SKILL.md files with belief read + write phases
- 3-stage cross-project retrieval query
- Selective promotion on close (lessons/design_rules only)
- Cascading invalidation via dependencies
- Soft-fail wrappers
- Tests

### Out of Scope

- New inference rules
- CortexModule as separate L3 module
- Formal logic engines (Datalog, TMS, OWL)
- Dashboard UI changes
- GSD execution modifications
- Replacing facts.jsonl
- canonical_hash dedup

---

## Write Roots

- `~/memory/vault/scripts/cortex_belief_bridge.py`
- `~/memory/vault/scripts/test_cortex_belief_bridge.py`
- `~/memory/vault/beliefs.db` (ALTER TABLE + CREATE TABLE)
- `~/memory/vault/scripts/belief_store.py` (if dependency tracking needs store changes)
- `~/memory/vault/scripts/l3_module.py` (if rules need dependency wiring)
- `~/.claude/skills/cortex-clarify/SKILL.md`
- `~/.claude/skills/cortex-research/SKILL.md`
- `~/.claude/skills/cortex-spec/SKILL.md`
- `~/.claude/skills/cortex-close/SKILL.md`

---

## Done Criteria

- [ ] cortex-clarify queries vault beliefs before writing brief (Phase 3.5)
- [ ] cortex-research queries vault beliefs before question routing (Phase 0.5)
- [ ] cortex-spec queries vault beliefs before synthesizing (Phase 1d.5)
- [ ] All 3 skills call vault ingest + L3 extraction inline after artifact creation
- [ ] cortex-close runs L3 finalization + promotes lessons/design_rules to global (Phase 5.5)
- [ ] logical_forms has scope_type/scope_id columns; existing 2330 forms backfilled
- [ ] derived_dependencies table exists with source_kind, source_id, role columns
- [ ] Cross-project query returns 3-stage results (global stable → recurring → caution)
- [ ] All 4 skills work unchanged when vault is unreachable (soft-fail verified)
- [ ] Belief injection capped at 2000 chars in compact format
- [ ] 8+ pytest tests pass covering scope, promotion, dependency, cross-project, soft-fail

---

## Validators

- [ ] [external] `sqlite3 ~/memory/vault/beliefs.db "SELECT scope_type, COUNT(*) FROM logical_forms GROUP BY scope_type"` returns rows
- [ ] [external] `sqlite3 ~/memory/vault/beliefs.db ".tables"` includes derived_dependencies
- [ ] [external] `python3 ~/memory/vault/scripts/cortex_belief_bridge.py --test` returns 0
- [ ] [external] `cd ~/memory/vault/scripts && python3 -m pytest test_cortex_belief_bridge.py -v` passes 8+ tests
- [ ] [external] `grep -c "Phase 3.5\|Phase 0.5\|Phase 1d.5\|Phase 5.5" ~/.claude/skills/cortex-clarify/SKILL.md ~/.claude/skills/cortex-research/SKILL.md ~/.claude/skills/cortex-spec/SKILL.md ~/.claude/skills/cortex-close/SKILL.md` returns 4+ matches
- [ ] [judgment] Belief injection content in skill working context is useful and concise, not noise

---

## Eval Plan

docs/cortex/evals/cortex-belief-memory/eval-plan.md

---

## Approvals

- [ ] Contract approval
- [ ] Evals approval

---

## Completion Promise

<!-- CORTEX_PROMISE: cortex-belief-memory-001 COMPLETE -->

---

## Failed Approaches

N/A — initial contract

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Revert SKILL.md changes: `git checkout` the 4 skill files
- Drop scope columns: `ALTER TABLE logical_forms DROP COLUMN scope_type; ALTER TABLE logical_forms DROP COLUMN scope_id;`
- Drop dependency table: `DROP TABLE IF EXISTS derived_dependencies;`
- Delete bridge script: `rm ~/memory/vault/scripts/cortex_belief_bridge.py ~/memory/vault/scripts/test_cortex_belief_bridge.py`

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
