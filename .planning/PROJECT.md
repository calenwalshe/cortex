# cortex-vault — Memory Vault Integration

## What This Is

Each Cortex intelligence session starts from zero. When a new slug begins, accumulated learnings from prior slugs — architectural decisions, failed approaches, open questions with trigger conditions, and research findings — exist in the memory vault at `~/memory/vault/` but are never injected into the new session. The vault has a working FAISS semantic index, a SQLite fact store, a retrieval API (`recall_query.py`), and an ingestion API (`add_fact()`), but Cortex's intelligence phases have no interface to it. This work wires the existing vault into Cortex at two defined event boundaries — reading at session start and writing at gate transitions — so that each new slug begins with accumulated cross-slug intelligence rather than from a cold start.

## Core Value

Each new Cortex slug starts with accumulated cross-slug learnings rather than from zero — decisions made, approaches failed, and lessons learned in prior slugs are automatically available at session start without any manual curation.

## Requirements

### Active

- None formalized

### Out of Scope

- Redesigning or modifying the vault itself (`~/memory/vault/` stays as-is)
- Improving the autoresearch classification loop (F1=0.25 targeting 0.7 — separate slug)
- Replacing `.cortex/facts.jsonl` — it stays as the per-session local facts store
- General-purpose conversation memory (only Cortex gate-transition artifacts are ingested)
- Adding a database or external service — vault is already file-based (SQLite, FAISS, JSONL)
- Wiring vault reads/writes into GSD execution phases (execute, validate, repair) — intelligence phases only
- inbox/promotion pipeline for Cortex artifacts
- cortex-close vault integration (deferred)

## Context

**Current baseline:** Cortex sessions start cold — no cross-slug memory injected. `.cortex/facts.jsonl` stores per-project facts but not cross-slug learnings. Vault exists and is operational but unconnected to Cortex.

**Target:** Session start injects top-5 cross-slug vault facts via `recall_query.py`. Gate transitions (clarify, research, spec) write typed facts to vault via `cortex-vault-extractor.py` calling `add_fact()` directly.

**Contract:** docs/cortex/contracts/cortex-vault/contract-001.md

## Constraints

- 10K character hard cap on `additionalContext` — vault injection must stay within budget (`max(0, 9500 - len(existing_content))`)
- Must survive /clear, /compact, and session crashes — vault is disk-resident; injection happens at SessionStart, not during conversation
- Must be additive — must not modify existing gate logic, break existing skill flows, or require changes to primary artifact formats
- `fact_store.py` is imported directly via `sys.path.insert` (no relative imports, verified) — do NOT call as subprocess
- Vault writes use `add_fact()` directly (not inbox/promotion) — structured artifacts don't need LLM reclassification
- Shallow mode only in hooks (`recall_query.py` without `--deep`) — target <3s latency

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Direct `add_fact()` over inbox/promotion | inbox/promotion extractors expect session JSONL (turns), not structured artifacts; Cortex artifacts are already classified | Use `sys.path.insert` + direct import |
| Top-k=5 for session start | ~800–1500 chars synthesized prose; fits 5K–8K remaining additionalContext budget | Default top-k=5, configurable via VAULT_TOP_K env var |
| Synthesized output over raw facts | LLM synthesis trades granularity for compactness; right trade at 5K char budget | Use `recall_query.py` default output |
| sys.path.insert over subprocess | fact_store.py has no CLI interface; `__main__` is test harness; no relative imports verified | `sys.path.insert(0, "~/memory/vault/scripts/")` + import |
