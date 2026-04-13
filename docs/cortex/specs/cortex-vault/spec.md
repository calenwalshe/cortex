# Spec: cortex-vault

<!-- ART-03: Spec Template — produced by /cortex-spec -->

**Slug:** cortex-vault
**Timestamp:** 2026-04-13T14:30:00Z
**Status:** draft

---

## 1. Problem

Each Cortex intelligence session starts from zero. When a new slug begins, accumulated learnings from prior slugs — architectural decisions, failed approaches, open questions with trigger conditions, and research findings — exist in the memory vault at `~/memory/vault/` but are never injected into the new session. The vault has a working FAISS semantic index, a SQLite fact store, a retrieval API (`recall_query.py`), and an ingestion API (`add_fact()`), but Cortex's intelligence phases have no interface to it. The consequence is repeated re-discovery: the same tradeoffs are evaluated, the same risks are catalogued, and the same patterns are rediscovered slug after slug. This slug wires the existing vault into Cortex at two defined event boundaries — reading at session start and writing at gate transitions — so that each new slug begins with accumulated cross-slug intelligence rather than from a cold start.

---

## 2. Acceptance Criteria

- [ ] `cortex-session-start.sh` calls `recall_query.py` and injects vault facts into `additionalContext` under a distinct `VAULT MEMORY` section header
- [ ] Total `additionalContext` length after vault injection remains under 10,000 characters
- [ ] Vault read uses `--top-k 5 --project cortex` to scope retrieval to Cortex-relevant facts
- [ ] Vault read soft-fails gracefully (empty string, no error) when vault index is absent or query returns nothing
- [ ] `scripts/cortex/cortex-vault-extractor.py` exists and accepts `--artifact <path> --slug <slug>` arguments
- [ ] Extractor correctly identifies artifact type using this path-pattern truth table: path contains `clarify/` → `brief`; path contains `research/` and filename does not match `current-understanding.md` → `dossier`; path contains `specs/` and filename is `spec.md` → `spec`. Any other path → error "unsupported artifact type"
- [ ] Extractor calls `add_fact()` for each extracted typed fact with these exact field values: `project_scope="cortex"`, `session_id="cortex-{slug}"`, `scope="learning"`, `valid_from=YYYY-MM-DD` derived from artifact filename timestamp or file mtime. Per-category values: scope-exclusion → `confidence=0.95, importance=0.6, memory_type="semantic"`; owner-constraint → `confidence=0.95, importance=0.8, memory_type="semantic"`; design-assumption → `confidence=0.75, importance=0.7, memory_type="semantic"`; research-finding → `confidence=0.80, importance=0.7, memory_type="semantic"`; architecture-decision → `confidence=0.90, importance=0.8, memory_type="semantic"`; adjacent-finding → `confidence=0.75, importance=0.65, memory_type="semantic"`; failed-approach → `confidence=0.85, importance=0.75, memory_type="procedural"`; risk-mitigation → `confidence=0.80, importance=0.70, memory_type="semantic"`
- [ ] Extraction is idempotent: re-running extractor on the same artifact path and slug does not create duplicate facts (deduplication by `session_id + topic + content[:50]` check before write)
- [ ] Vault write soft-fails gracefully (logged warning, no exception) when `fact_store.py` is unavailable or vault path does not exist
- [ ] `cortex-clarify` Phase 4c calls `cortex-vault-extractor.py` after writing the clarify brief
- [ ] `cortex-research` Phase 2.9 calls `cortex-vault-extractor.py` after writing the research dossier
- [ ] `cortex-spec` Phase 2c calls `cortex-vault-extractor.py` after writing the spec

---

## 3. Scope

### In Scope

- `cortex-session-start.sh` vault read injection block (read path)
- `scripts/cortex/cortex-vault-extractor.py` — new Python extractor for 3 artifact types
- Insertion into 3 Cortex skill files: cortex-clarify (Phase 4c), cortex-research (Phase 2.9), cortex-spec (Phase 2c)
- 9 extraction categories mapped to vault schema: scope-exclusion, owner-constraint, design-assumption, research-finding, architecture-decision, adjacent-finding, failed-approach, risk-mitigation, and open-question (as trigger-condition annotation)
- Idempotency guard in the extractor
- Graceful failure in both read and write paths

### Out of Scope

- Redesigning or modifying the vault itself (`~/memory/vault/` stays as-is)
- Improving the autoresearch classification loop (F1=0.25 targeting 0.7 — separate slug)
- Replacing `.cortex/facts.jsonl` — it stays as the per-session local facts store
- General-purpose conversation memory (only Cortex gate-transition artifacts are ingested)
- Adding a database or external service — vault is already file-based (SQLite, FAISS, JSONL)
- Wiring vault reads/writes into GSD execution phases (execute, validate, repair) — intelligence phases only
- inbox/promotion pipeline for Cortex artifacts (see Architecture Decision — direct `add_fact()` chosen instead)
- cortex-close vault integration (deferred — see open questions)

---

## 4. Architecture Decision

**Chosen approach:** Direct `add_fact()` for gate-transition writes; `recall_query.py` synthesized output for session-start reads.

**Rationale:** The clarify brief originally constrained writes to go through the inbox/promotion pipeline. Research overturned this: the inbox/promotion extractors (`episodic_extractor.py`, `procedural_extractor.py`) expect session JSONL input (conversational turns), not structured Cortex artifacts. Sending a dossier through that pipeline would require LLM reclassification of content that is already classified by artifact section. `add_fact()` in `fact_store.py` is a lower-level API designed for programmatic insertion — it bypasses extraction but writes directly to SQLite + FAISS atomically. This is the correct path for structured artifacts reviewed by humans at gate approval: confidence is high (0.80–0.95), classification is explicit (by section type), and no LLM re-interpretation is needed. The clarify brief constraint was based on the assumption that Cortex writes would be raw events; research showed they are structured artifacts. The constraint is modified accordingly, with evidence from Q2 audit.

For reads: `recall_query.py --top-k 5 --project cortex` returns synthesized prose (not raw JSON) ready for `additionalContext` injection. No wrapper needed. The synthesis step trades individual fact granularity for compactness — the right trade at a 10K char budget where space must be shared with current-state, per-session facts, and coherence warnings.

### Alternatives Considered

- **Inbox/promotion pipeline for Cortex artifacts:** Rejected. Extractors expect session JSONL format (turns), not structured markdown. Sending a dossier as a free-form inbox stub loses section-level structure and requires LLM reclassification of already-classified content, adding noise without value.
- **Raw facts (direct SQLite query) for hook injection:** Rejected. Raw facts are less compact than synthesized prose — more characters per information unit. At 5K-8K char remaining budget, synthesized top-5 (~800-1500 chars) fits more cleanly than 5 raw fact objects.
- **Top-k=10 for SessionStart injection:** Rejected as default. Produces ~1500-3000 chars, which still fits but pushes limits for fact-heavy sessions. Use top-k=5 as default; expose as `VAULT_TOP_K` env var for future tuning.

---

## 5. Interfaces

- **`~/memory/vault/recall_query.py`** — Read interface. CLI: `python3 recall_query.py "QUERY" --top-k N --project SCOPE`. Returns synthesized prose. Owned by vault; this spec reads from it, does not modify it.
- **`~/memory/vault/scripts/fact_store.py`** — Write interface. Function: `add_fact(content, session_id, valid_from, topic, memory_type, project_scope, confidence, importance, scope, entities, ingestion_time)`. Returns fact_id (UUID). Owned by vault; imported directly via `sys.path.insert(0, os.path.expanduser("~/memory/vault/scripts/"))` — verified: no relative imports, safe to import from any working directory. Do NOT call as subprocess (its `__main__` block is a test harness, not a CLI).
- **`/home/agent/projects/cortex/.claude/hooks/cortex-session-start.sh`** — Modified. Vault injection block added after line 40 (end of `.cortex/facts.jsonl` retrieval block), before line 43 (health check). Reads: `VAULT_SCRIPT`, `SLUG`. Writes: `VAULT_FACTS` variable appended to `$EXTRA`.
- **`/home/agent/.claude/skills/cortex-clarify/SKILL.md`** — Modified. Phase 4c insertion: calls `cortex-vault-extractor.py` after clarify brief is written.
- **`/home/agent/.claude/skills/cortex-research/SKILL.md`** — Modified. Phase 2.9 insertion: calls `cortex-vault-extractor.py` after research dossier is written.
- **`/home/agent/.claude/skills/cortex-spec/SKILL.md`** — Modified. Phase 2c insertion: calls `cortex-vault-extractor.py` after spec is written.
- **`/home/agent/projects/cortex/scripts/cortex/cortex-vault-extractor.py`** — New file. Created by this spec.

---

## 6. Dependencies

- **`~/memory/vault/recall_query.py`** — Required for session-start read. Must exist; failure is soft (empty injection, no crash).
- **`~/memory/vault/scripts/fact_store.py`** — Required for gate-transition write. Must be importable via `sys.path.insert`. Failure is soft (logged warning, no crash).
- **`~/memory/vault/facts.faiss` + `facts.map.json`** — Required for retrieval. Missing index returns empty string from `recall_query.py` (safe).
- **`all-MiniLM-L6-v2` (sentence-transformers)** — Used internally by `recall_query.py` for embedding queries. Already installed in vault environment.
- **`Python 3`** — Required for extractor script and vault API calls.
- **Cortex skills: cortex-clarify, cortex-research, cortex-spec** — 3 insertion points. These skill files are in `~/.claude/skills/` and are modified directly.

---

## 7. Risks

- **`fact_store.py` import fails from cortex repo** — The vault scripts could have relative imports that fail with `sys.path.insert`. Mitigation: `fact_store.py` was verified to have no relative imports (only stdlib + third-party: json, sqlite3, uuid, faiss, numpy, sentence_transformers). Use `sys.path.insert(0, os.path.expanduser("~/memory/vault/scripts/"))` followed by `from fact_store import add_fact`. Its `__main__` block is a test harness that does not accept CLI args — do NOT call it as a subprocess with JSON-encoded kwargs (that would silently run the test harness and ignore the args).
- **additionalContext budget overflow** — If current-state.md or per-session facts are larger than expected, vault injection may push total over 10K. Mitigation: measure total chars before appending vault facts and truncate to available budget (`max(0, 9500 - len(existing_content))`).
- **Near-duplicate facts from multiple extraction passes** — If a dossier is re-extracted (e.g., after being revised and re-specced), near-duplicate facts accumulate in SQLite + FAISS. Mitigation: idempotency guard using `(session_id, topic, content[:50])` check before calling `add_fact()`. First extraction wins; subsequent re-runs are no-ops.
- **recall_query.py `--project cortex` filter semantics unclear** — Research noted uncertainty about whether `--project cortex` matches `project_scope = "cortex"` exactly or uses LIKE/prefix matching. Mitigation: test with a live vault query during implementation; if filter doesn't work, fall back to unscoped query with post-filter in the hook.
- **Session-start hook performance** — `recall_query.py` shallow mode targets <3s; deep mode is multi-step. Mitigation: always use shallow mode (no `--deep` flag) in the hook to keep session start latency acceptable.

---

## 8. Sequencing

1. Write `scripts/cortex/cortex-vault-extractor.py` — the new extractor with all 9 extraction categories, idempotency guard, and soft-fail write path. Verify importability of `fact_store.py` from cortex scripts directory.
2. Test extractor with a live Cortex artifact (the cortex-vault clarify brief itself is available). Verify facts are written to vault with correct fields.
3. Modify `cortex-session-start.sh` — add vault injection block after line 40, append `VAULT MEMORY` section to `$EXTRA`. Verify total `additionalContext` length stays under 10K.
4. Test hook modification by running the hook manually and inspecting JSON output.
5. Insert Phase 4c into `cortex-clarify/SKILL.md` — call extractor after clarify brief write. Match existing gate-critique Phase 4c pattern.
6. Insert Phase 2.9 into `cortex-research/SKILL.md` — call extractor after dossier write. Match existing Phase 2.9 pattern.
7. Insert Phase 2c into `cortex-spec/SKILL.md` — call extractor after spec write. Match existing Phase 2c pattern.
8. Run full validators: grep checks for all 3 skill insertions, manual test of extractor idempotency, manual test of hook budget constraint.

---

## 9. Tasks

- [ ] Write `scripts/cortex/cortex-vault-extractor.py` with CLI (`--artifact <path> --slug <slug>`), artifact type detection from path, section-level extraction for 3 artifact types, `add_fact()` calls for all 9 categories, idempotency guard, and soft-fail on vault unavailability
- [ ] Implement vault write via direct import: `sys.path.insert(0, os.path.expanduser("~/memory/vault/scripts/")); from fact_store import add_fact` — verified no relative imports in fact_store.py; do NOT use subprocess (fact_store.py has no CLI interface)
- [ ] Modify `.claude/hooks/cortex-session-start.sh`: add `VAULT_FACTS` block after line 40, add budget check before appending, add `VAULT MEMORY` section to `$EXTRA` block
- [ ] Run `python3 -c "import json; hook_out = ...; assert len(hook_out['hookSpecificOutput']['additionalContext']) <= 10000"` to verify budget constraint
- [ ] Edit `~/.claude/skills/cortex-clarify/SKILL.md` — insert Phase 4c (extractor call after clarify brief write, before Phase 5)
- [ ] Edit `~/.claude/skills/cortex-research/SKILL.md` — insert Phase 2.9 (extractor call after dossier write, matching existing Phase 2.9 pattern)
- [ ] Edit `~/.claude/skills/cortex-spec/SKILL.md` — insert Phase 2c (extractor call after spec write, matching existing Phase 2c pattern)
- [ ] Run idempotency test: call extractor twice on same artifact, verify no duplicate facts in vault (query `facts.db` before and after second run)
- [ ] Run soft-fail test: rename vault temporarily and verify hook and extractor complete without crashing
