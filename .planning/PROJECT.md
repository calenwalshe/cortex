# Cortex Belief Memory Integration

## What This Is

The Cortex discovery loop (clarify → research → spec) loses knowledge at every session boundary. Research cycle 2 doesn't know what cycle 1 established as stable. Spec generation reads dossier text, not a typed belief state. When a slug closes, everything learned during discovery evaporates. This project wires the existing SCAPE belief engine into the Cortex skill pipeline so that discovery cycles accumulate beliefs, research builds on stable ground, and knowledge earned during discovery survives slug closure.

## Core Value

Every Cortex discovery cycle accumulates typed, provenanced beliefs that persist across session boundaries, so research doesn't re-cover stable ground, specs are generated from the belief state, and knowledge earned during discovery survives slug closure to inform future work.

## Requirements

### Active

- [ ] **BM-01**: Schema migration — add scope_type/scope_id to logical_forms + derived_dependencies table
- [ ] **BM-02**: Bridge script — cortex_belief_bridge.py with query, ingest, promote, invalidate functions
- [ ] **BM-03**: Skill reads — belief queries injected into cortex-clarify, cortex-research, cortex-spec
- [ ] **BM-04**: Skill writes — L3 extraction wired into cortex-clarify, cortex-research, cortex-spec
- [ ] **BM-05**: Promotion — cortex-close promotes lessons/design_rules to global scope
- [ ] **BM-06**: Dependency tracking — derived_dependencies with cascading invalidation
- [ ] **BM-07**: Soft-fail — all vault calls wrapped in try/except, skills work without vault
- [ ] **BM-08**: Tests — 8+ pytest tests covering all integration points

### Out of Scope

- New inference rules beyond existing 4
- CortexModule as separate L3 module
- Formal logic engines (Datalog, TMS, OWL)
- Dashboard UI changes
- GSD execution modifications
- Replacing .cortex/facts.jsonl
- canonical_hash deduplication

## Context

Baseline: Belief engine exists (beliefs.db, 2330 forms, 388 derived objects, 8 Kripke worlds) but no Cortex skill reads from or invokes it. Vault writes exist in 3 skills via cortex-vault-extractor.py but L3 engine is never called.

Target: 4 Cortex skills wired with belief read/write phases. Short-term beliefs scoped per slug, long-term promoted on close.

## Constraints

- Vault at ~/memory/vault/ is global, Cortex state is per-project
- All claude -p calls use env -u ANTHROPIC_API_KEY
- Existing skills must work unchanged when vault is unavailable
- Belief injection capped at 2000 chars per skill invocation

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Explicit scope columns on logical_forms | Rebuild independence, clear provenance | scope_type + scope_id columns |
| Selective promotion only | Prevents semantic pollution of long-term memory | Lessons/design_rules auto-promote |
| JTMS Lite dependency tracking | More than logging, less than full TMS | derived_dependencies table |
| Inline extraction (not async) | Stale beliefs cost more than 1-2s latency | L3 extraction runs inline |
| 3-stage cross-project retrieval | Prevents contamination | Global stable → recurring → caution |
