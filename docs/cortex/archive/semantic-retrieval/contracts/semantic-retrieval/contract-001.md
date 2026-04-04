# Contract: semantic-retrieval — execute

**ID:** semantic-retrieval-001
**Slug:** semantic-retrieval
**Phase:** execute
**Created:** 20260404T001500Z
**Status:** draft
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Build semantic fact retrieval for Cortex so that any hook or skill can query the fact store with a natural-language question and get back the top-K most relevant facts in <2 seconds, using ollama embeddings and numpy cosine similarity over pre-computed vectors.

---

## Deliverables

- `scripts/cortex/cortex-embed.py` — batch embedding script
- `scripts/cortex/cortex-retrieve.py` — retrieval CLI
- `.claude/settings.json` — async PostCompact hook entry (modification)
- `.cortex/fact-embeddings.npy` — embedding matrix
- `.cortex/fact-index.json` — fact ID to row mapping
- `.cortex/fact-embeddings.meta.json` — staleness tracking metadata
- `test/test_semantic_retrieval.py` — test suite

---

## Scope

### In Scope

- Python embedding script (batch via ollama nomic-embed-text 768-dim)
- Python retrieval script (query embed + cosine similarity + top-K JSON output)
- Async PostCompact hook wiring
- .npy + index.json + meta.json file format
- Graceful degradation (ollama down, .npy missing)
- Incremental embedding (only new facts)
- Tests

### Out of Scope

- Full RAG pipeline
- Replacing existing handoff files
- UI for fact browsing
- Cross-project retrieval
- Real-time streaming embeddings
- Custom model training
- ANN index (faiss, annoy)
- Modifying session-start hook to use retrieval (future work)

---

## Write Roots

- `scripts/cortex/cortex-embed.py`
- `scripts/cortex/cortex-retrieve.py`
- `.cortex/fact-embeddings.npy`
- `.cortex/fact-index.json`
- `.cortex/fact-embeddings.meta.json`
- `.claude/settings.json`
- `test/test_semantic_retrieval.py`

---

## Done Criteria

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

---

## Validators

- [ ] [external] `python3 scripts/cortex/cortex-embed.py && python3 -c "import numpy as np; a = np.load('.cortex/fact-embeddings.npy'); assert a.shape[1] == 768; print(f'OK: {a.shape}')"` — embedding produces correct shape
- [ ] [external] `python3 -c "import json; d = json.load(open('.cortex/fact-index.json')); assert len(d) > 0; print(f'OK: {len(d)} entries')"` — index.json is valid and non-empty
- [ ] [external] `python3 -c "import json; d = json.load(open('.cortex/fact-embeddings.meta.json')); assert 'last_embedded_count' in d and 'model' in d; print('OK')"` — meta.json has required fields
- [ ] [external] `python3 scripts/cortex/cortex-retrieve.py "hook performance" --top-k 3 | python3 -c "import sys,json; r = json.load(sys.stdin); assert len(r) <= 3 and all('score' in x for x in r); print(f'OK: {len(r)} results')"` — retrieval returns valid JSON
- [ ] [external] `timeout 2 python3 scripts/cortex/cortex-retrieve.py "test query" --top-k 5` — retrieval completes within 2 seconds
- [ ] [external] `python3 -m pytest test/test_semantic_retrieval.py -v` — all tests pass
- [ ] [judgment] Review that retrieval returns semantically relevant facts (not just random top-K) for a known query
- [ ] [judgment] Review that graceful degradation produces a clear, actionable stderr warning

---

## Eval Plan

docs/cortex/evals/semantic-retrieval/eval-plan.md (pending)

---

## Approvals

- [ ] Contract approval
- [ ] Evals approval

---

## Completion Promise

<!-- The executing agent MUST emit this signal when all done criteria are satisfied: -->
<!-- CORTEX_PROMISE: semantic-retrieval-001 COMPLETE -->

---

## Failed Approaches

<!-- Initial contract — no prior attempts -->

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Delete `scripts/cortex/cortex-embed.py`
- Delete `scripts/cortex/cortex-retrieve.py`
- Delete `.cortex/fact-embeddings.npy`, `.cortex/fact-index.json`, `.cortex/fact-embeddings.meta.json`
- Remove the async PostCompact hook entry from `.claude/settings.json` (the second PostCompact entry)
- Delete `test/test_semantic_retrieval.py`

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
