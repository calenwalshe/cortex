# GSD Handoff: semantic-retrieval

**Slug:** semantic-retrieval
**Timestamp:** 20260404T001500Z
**Status:** draft

---

## Objective

Build semantic fact retrieval for Cortex so that hooks and skills can query the fact store with a natural-language question and get back only the top-K relevant facts in <2 seconds — replacing exhaustive context loading with selective retrieval via ollama embeddings and numpy cosine similarity.

---

## Deliverables

- `scripts/cortex/cortex-embed.py` — batch embedding script (reads facts.jsonl, writes .npy + index + meta via ollama)
- `scripts/cortex/cortex-retrieve.py` — retrieval CLI (`<query> [--top-k N]` → JSON on stdout)
- `.claude/settings.json` modification — async PostCompact hook entry for embedding
- `.cortex/fact-embeddings.npy` — embedding matrix (N x 768)
- `.cortex/fact-index.json` — fact ID to row index mapping
- `.cortex/fact-embeddings.meta.json` — staleness tracking
- `test/test_semantic_retrieval.py` — test suite

---

## Requirements

- None formalized

---

## Tasks

- [ ] Write `scripts/cortex/cortex-embed.py` — reads facts.jsonl, calls ollama `/api/embed` with batch input, writes .npy + index.json + meta.json
- [ ] Write `scripts/cortex/cortex-retrieve.py` — CLI taking `<query> [--top-k N]`, loads .npy, embeds query via ollama, cosine similarity, outputs JSON array of `{id, text, score}` to stdout
- [ ] Add async PostCompact hook entry to `.claude/settings.json` that calls `cortex-embed.py`
- [ ] Implement incremental embedding — compare facts.jsonl line count against meta.json, only embed new facts
- [ ] Implement graceful degradation — fallback to all facts when ollama unreachable or .npy missing
- [ ] Write tests for embedding (correct .npy shape, meta.json, incremental behavior)
- [ ] Write tests for retrieval (top-K ordering, JSON format, degradation fallback)
- [ ] Verify end-to-end: compaction triggers embedding, retrieval returns relevant facts

---

## Acceptance Criteria

- [ ] `cortex-embed.py` produces `.cortex/fact-embeddings.npy` with shape `(N, 768)` where N matches fact count
- [ ] `cortex-embed.py` produces `.cortex/fact-index.json` mapping each fact ID to its row index
- [ ] `cortex-embed.py` produces `.cortex/fact-embeddings.meta.json` with `last_embedded_count`, `model`, `timestamp`
- [ ] `cortex-retrieve.py <query>` returns JSON array of `{id, text, score}` sorted by descending score
- [ ] `cortex-retrieve.py` completes in <2 seconds end-to-end
- [ ] `cortex-retrieve.py` falls back to all facts when ollama unreachable, with stderr warning
- [ ] `cortex-retrieve.py` falls back to all facts when .npy missing, with stderr warning
- [ ] Async PostCompact hook entry exists in `.claude/settings.json`
- [ ] Incremental embedding works correctly
- [ ] All tests pass

---

## Contract Link

docs/cortex/contracts/semantic-retrieval/contract-001.md
