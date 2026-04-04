# Spec: semantic-retrieval

**Slug:** semantic-retrieval
**Timestamp:** 20260404T001500Z
**Status:** draft

---

## 1. Problem

Cortex hooks and skills currently load all handoff files (current-state.md, decisions.md, open-questions.md) and the entire facts.jsonl into context at session-start and after compaction. As the fact store grows, this becomes a token sink — most loaded facts are irrelevant to the current task. The system needs selective retrieval: given a natural-language query, return only the top-K most relevant facts in under 2 seconds, so that context loading scales with relevance rather than fact count.

---

## 2. Scope

### In Scope

- Python embedding script that batch-embeds facts.jsonl via ollama `nomic-embed-text` (768-dim)
- Async PostCompact hook entry that triggers embedding after fact extraction
- Python retrieval script (`cortex-retrieve.py`) that takes a query string, embeds it via ollama, computes cosine similarity against pre-computed embeddings, and returns top-K facts as JSON on stdout
- `.cortex/fact-embeddings.npy` storage (numpy array) + `.cortex/fact-index.json` (fact ID to row mapping) + `.cortex/fact-embeddings.meta.json` (staleness tracking)
- Graceful degradation when ollama is unreachable or embeddings are missing
- Integration point for session-start hook to call retrieval instead of loading all facts

### Out of Scope

- Full RAG pipeline (no document chunking, no retrieval-augmented generation loop)
- Replacing existing handoff file system (current-state.md, next-prompt.md, decisions.md unchanged)
- UI for browsing or managing facts
- Cross-project retrieval (facts remain per-project in .cortex/)
- Real-time streaming embeddings (batch on compaction is sufficient)
- Fine-tuning or training custom embedding models
- ANN index (faiss, annoy, etc.) — brute-force cosine is fast enough at <10K facts

---

## 3. Architecture Decision

**Chosen approach:** Two-phase split — embed at compaction time (async, latency-tolerant), retrieve at query time (pre-computed embeddings, <100ms).

**Rationale:** Embedding requires a model, which adds latency. By splitting embed and retrieve into separate phases, the slow model-dependent step runs in the background during compaction, while retrieval at query time only needs numpy (2ms) plus a single ollama query embedding call (77ms). This keeps retrieval well within the <2s hook budget.

### Alternatives Considered

- **Single-phase (embed + retrieve at query time via sentence-transformers):** Rejected — 13s model load per subprocess invocation, regardless of cache state. Completely unsuitable for hooks with <5s budgets.
- **sentence-transformers for batch embedding + ollama for query:** Rejected — dimension mismatch (384 vs 768). Cosine similarity on mismatched dimensions is meaningless.
- **SQLite with BLOB columns for embedding storage:** Rejected — adds complexity for no gain at <10K facts. numpy .npy is simpler, faster (<1ms load), and has zero additional dependencies.
- **Pre-computed query embeddings for known patterns:** Rejected as primary approach — too brittle, doesn't handle ad-hoc queries. Works as an optional future optimization.

---

## 4. Interfaces

- **ollama HTTP API** (`localhost:11434/api/embed`) — owned by ollama systemd service. This spec reads embeddings from it (both batch and single-query). Write: nothing.
- **`.cortex/facts.jsonl`** — owned by `cortex-postcompact.js`. This spec reads it to get fact text for embedding. Write: nothing (facts.jsonl is source of truth, not modified).
- **`.cortex/fact-embeddings.npy`** — new file, owned by the embedding script. Write: overwritten on each embedding pass.
- **`.cortex/fact-index.json`** — new file, owned by the embedding script. Maps fact IDs to row indices in the .npy array. Write: overwritten on each embedding pass.
- **`.cortex/fact-embeddings.meta.json`** — new file, owned by the embedding script. Tracks `{last_embedded_count, model, timestamp}`. Write: overwritten on each embedding pass.
- **`.claude/settings.json`** — owned by project config. This spec adds one PostCompact hook entry with `"async": true`. Write: one new hook entry appended.
- **`scripts/cortex/cortex-embed.py`** — new file. Batch embedding script called by async PostCompact hook.
- **`scripts/cortex/cortex-retrieve.py`** — new file. Retrieval CLI: `cortex-retrieve.py <query> [--top-k N]` → JSON on stdout.

---

## 5. Dependencies

- **ollama** (systemd service, v0.17.7+) — provides `/api/embed` endpoint for `nomic-embed-text` model. Used for both batch embedding and query-time embedding.
- **nomic-embed-text** (ollama model, 768-dim, 274MB) — the embedding model. Already installed on target machine.
- **numpy** (Python stdlib-adjacent, pre-installed) — used for `.npy` storage and cosine similarity computation.
- **`.cortex/facts.jsonl`** (produced by `cortex-postcompact.js` from memory-extraction milestone) — the source of truth for fact text.
- **`cortex-postcompact.js`** (existing hook) — must complete and write facts.jsonl before the embedding hook runs.

---

## 6. Risks

- **ollama daemon not running** — Mitigation: graceful degradation. Embedding script exits silently (facts remain unembedded until next compaction). Retrieval script falls back to loading all facts with a stderr warning.
- **nomic-embed-text model not installed** — Mitigation: embedding script checks `ollama list` output or catches HTTP error, logs warning, exits 0.
- **facts.jsonl grows beyond 10K facts** — Mitigation: current benchmarks show cosine over 10K facts takes ~180ms (projected). If this becomes an issue, add an ANN index in a future iteration. Not a concern at current scale (53 facts).
- **Embedding staleness after failed compaction** — Mitigation: meta.json tracks last_embedded_count. Retrieval still works with stale embeddings (returns slightly less relevant results). Next successful compaction re-embeds.
- **Async hook ordering** — Mitigation: the sync postcompact.js writes facts.jsonl first. The async embedding hook reads facts.jsonl. Claude Code runs sync hooks before async hooks within the same event, so ordering is guaranteed.

---

## 7. Sequencing

1. **Embedding script** — Write `scripts/cortex/cortex-embed.py`. Reads facts.jsonl, calls ollama batch embed, writes .npy + index.json + meta.json. Verify: run manually, check output files exist and have correct shapes.
2. **Retrieval script** — Write `scripts/cortex/cortex-retrieve.py`. Loads .npy, embeds query via ollama, computes cosine, returns top-K JSON. Verify: run with a test query, confirm JSON output with ranked facts.
3. **Async PostCompact hook** — Add hook entry to `.claude/settings.json`. Verify: trigger a compaction, confirm embedding files are created/updated.
4. **Graceful degradation** — Add fallback paths to retrieval script (ollama down, .npy missing). Verify: stop ollama, run retrieval, confirm fallback behavior.
5. **Tests** — Write test suite covering embedding, retrieval, degradation, and incremental embedding. Verify: all tests pass.

---

## 8. Tasks

- [ ] Write `scripts/cortex/cortex-embed.py` — reads facts.jsonl, calls ollama `/api/embed` with batch input, writes `.cortex/fact-embeddings.npy`, `.cortex/fact-index.json`, `.cortex/fact-embeddings.meta.json`
- [ ] Write `scripts/cortex/cortex-retrieve.py` — CLI taking `<query> [--top-k N]`, loads .npy, embeds query via ollama, cosine similarity, outputs JSON array of `{id, text, score}` to stdout
- [ ] Add async PostCompact hook entry to `.claude/settings.json` that calls `cortex-embed.py`
- [ ] Implement incremental embedding in `cortex-embed.py` — compare facts.jsonl line count against meta.json `last_embedded_count`, only embed new facts and append to .npy
- [ ] Implement graceful degradation in `cortex-retrieve.py` — fallback to loading all facts when ollama is unreachable or .npy is missing, with stderr warning
- [ ] Write tests for embedding script (correct .npy shape, meta.json values, incremental behavior)
- [ ] Write tests for retrieval script (top-K ordering, JSON output format, degradation fallback)
- [ ] Verify end-to-end: compaction triggers embedding, retrieval returns relevant facts

---

## 9. Acceptance Criteria

- [ ] `cortex-embed.py` produces `.cortex/fact-embeddings.npy` with shape `(N, 768)` where N matches fact count in facts.jsonl
- [ ] `cortex-embed.py` produces `.cortex/fact-index.json` mapping each fact ID to its row index
- [ ] `cortex-embed.py` produces `.cortex/fact-embeddings.meta.json` with `last_embedded_count`, `model`, and `timestamp` fields
- [ ] `cortex-retrieve.py <query>` returns JSON array of `{id, text, score}` objects sorted by descending score
- [ ] `cortex-retrieve.py` completes in <2 seconds end-to-end (including ollama query embedding)
- [ ] `cortex-retrieve.py` falls back to loading all facts (no filtering) when ollama is unreachable, with stderr warning
- [ ] `cortex-retrieve.py` falls back to loading all facts when `.npy` file is missing, with stderr warning
- [ ] Async PostCompact hook entry exists in `.claude/settings.json` and calls `cortex-embed.py`
- [ ] Incremental embedding works: adding new facts to facts.jsonl and re-running embed produces updated .npy with correct row count
- [ ] All tests pass
