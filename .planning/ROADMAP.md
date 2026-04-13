# Roadmap: cortex-vault — Memory Vault Integration

## Overview

Wire the existing memory vault (`~/memory/vault/`) into Cortex's intelligence phases so that session start injects top-5 cross-slug vault facts into `additionalContext` and gate transitions (clarify brief, research dossier, spec) write typed facts back to the vault via a new `cortex-vault-extractor.py` script calling `add_fact()` directly.

## Phases

### Phase 1: Build extractor and hook injection

**Goal**: Write `scripts/cortex/cortex-vault-extractor.py` with full extraction logic and modify `cortex-session-start.sh` to inject vault facts into `additionalContext`
**Depends on**: Nothing
**Requirements**: None formalized
**Success Criteria** (what must be TRUE):
  1. `cortex-session-start.sh` calls `recall_query.py` and injects vault facts into `additionalContext` under a distinct `VAULT MEMORY` section header
  2. Total `additionalContext` length after vault injection remains under 10,000 characters
  3. Vault read uses `--top-k 5 --project cortex` to scope retrieval to Cortex-relevant facts
  4. Vault read soft-fails gracefully (empty string, no error) when vault index is absent or query returns nothing
  5. `scripts/cortex/cortex-vault-extractor.py` exists and accepts `--artifact <path> --slug <slug>` arguments
  6. Extractor correctly identifies artifact type using this path-pattern truth table: path contains `clarify/` → `brief`; path contains `research/` and filename does not match `current-understanding.md` → `dossier`; path contains `specs/` and filename is `spec.md` → `spec`. Any other path → error "unsupported artifact type"
  7. Extractor calls `add_fact()` for each extracted typed fact with these exact field values: `project_scope="cortex"`, `session_id="cortex-{slug}"`, `scope="learning"`, `valid_from=YYYY-MM-DD` derived from artifact filename timestamp or file mtime. Per-category values: scope-exclusion → `confidence=0.95, importance=0.6, memory_type="semantic"`; owner-constraint → `confidence=0.95, importance=0.8, memory_type="semantic"`; design-assumption → `confidence=0.75, importance=0.7, memory_type="semantic"`; research-finding → `confidence=0.80, importance=0.7, memory_type="semantic"`; architecture-decision → `confidence=0.90, importance=0.8, memory_type="semantic"`; adjacent-finding → `confidence=0.75, importance=0.65, memory_type="semantic"`; failed-approach → `confidence=0.85, importance=0.75, memory_type="procedural"`; risk-mitigation → `confidence=0.80, importance=0.70, memory_type="semantic"`
  8. Extraction is idempotent: re-running extractor on the same artifact path and slug does not create duplicate facts (deduplication by `session_id + topic + content[:50]` check before write)
  9. Vault write soft-fails gracefully (logged warning, no exception) when `fact_store.py` is unavailable or vault path does not exist
**Research**: Unlikely
**Plans**: 0 plans

### Phase 2: Wire skill insertions

**Goal**: Insert extractor calls at Phase 4c (cortex-clarify), Phase 2.9 (cortex-research), and Phase 2c (cortex-spec) in the three intelligence skill files
**Depends on**: Phase 1: Build extractor and hook injection
**Requirements**: None formalized
**Success Criteria** (what must be TRUE):
  1. `cortex-clarify` Phase 4c calls `cortex-vault-extractor.py` after writing the clarify brief
  2. `cortex-research` Phase 2.9 calls `cortex-vault-extractor.py` after writing the research dossier
  3. `cortex-spec` Phase 2c calls `cortex-vault-extractor.py` after writing the spec
**Research**: Unlikely
**Plans**: 0 plans

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| Phase 1: Build extractor and hook injection | 0/0 | Not started | - |
| Phase 2: Wire skill insertions | 0/0 | Not started | - |
