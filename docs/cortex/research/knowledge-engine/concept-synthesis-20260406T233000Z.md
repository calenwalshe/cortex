# Research Dossier: knowledge-engine — synthesis

**Slug:** knowledge-engine
**Phase:** concept (synthesis)
**Timestamp:** 20260406T233000Z
**Depth:** deep (4 parallel research agents, complex slug)

---

## Executive Summary

The knowledge engine is **~40% already built**. `cortex-embed.py`, `cortex-retrieve.py`, `cortex-postcompact.js` (fact extraction), 15 tests, 53 facts in `facts.jsonl`, numpy embeddings — all exist and work. The semantic-retrieval slug was executed (not just specced), then archived because the code was already shipping.

The gap is not infrastructure — it's **quality and integration**:
1. Extraction quality is poor (53 facts are mostly noise — gate decisions and section headers)
2. Zero consumers are wired up (no skill, hook, or command reads facts)
3. Procedural/lesson memory types (E4) don't exist
4. Session-start hook doesn't inject retrieved facts

This changes the scope from "build a knowledge engine" to "sharpen extraction, add E4 types, and wire consumers."

---

## Finding 1: What's Built and Working

| Component | File | Status | Reusable? |
|-----------|------|--------|-----------|
| Embedding script | `scripts/cortex/cortex-embed.py` | Production-ready, tested | Yes — keep as-is |
| Retrieval script | `scripts/cortex/cortex-retrieve.py` | Production-ready, tested | Yes — keep as-is |
| Fact extraction (PostCompact) | `.claude/hooks/cortex-postcompact.js` | Working but low quality | Yes — extend |
| Test suite | `test/test_semantic_retrieval.py` | 15 tests, passing | Yes — extend |
| Fact store | `.cortex/facts.jsonl` | 53 facts (mostly noise) | Rebuild with quality filter |
| Embeddings | `.cortex/fact-embeddings.npy` | 53×768 numpy | Regenerate after quality fix |
| Async hook wiring | `.claude/settings.json` | PostCompact → embed registered | Keep |
| Two-phase architecture | embed at compact, retrieve at query | Validated | Keep |

### Updated Benchmark Numbers (2026-04-06)

| Metric | Original Spec | Current Measurement | Budget |
|--------|--------------|--------------------| -------|
| Query embedding (ollama warm) | 77ms | ~150ms | <2s ✓ |
| End-to-end retrieval | 79ms | ~400ms | <2s ✓ |
| Cold start (first call) | N/A | ~600ms | <2s ✓ |
| Batch embed (53 facts) | 2.4s | 3.7s | <10s ✓ |

All within budget. Use ~500ms worst-case for planning.

---

## Finding 2: Extraction Quality Problem

The 53 existing facts are mostly noise:
- Autonomy gate decisions ("gate: slug_conflict, value: false")
- Vague context pointers ("Recent commit: abc1234")
- Generic preference labels ("Where JSONL log files are stored")
- Section headings from CONTEXT.md files

**Root cause:** The extraction patterns in `cortex-postcompact.js` are too broad — they capture structural metadata rather than substantive intelligence.

### Fix: Quality filter + new sources + new categories

**Current sources (6):** decisions.md, STATE.md, CONTEXT.md (per-phase), git log, state.json artifacts, current-state.md

**New sources to add (3):**
- Contract `## Failed Approaches` sections → `lesson` facts
- Investigation artifacts → `lesson`, `observation`, `procedure` facts  
- Research dossier recommendations → `observation` facts

**Current fact types (6):** decision, preference, constraint, pattern, blocker, context_pointer

**New fact types (3, E4):**
- `procedure` — reusable tactic: "when X, do Y" (from investigation repair recommendations)
- `lesson` — learned failure: "tried X on slug Y, failed because Z" (from Failed Approaches)
- `observation` — neutral research finding (from dossier recommendations and investigation root causes)

**Quality filter:** Skip facts where `text` field is:
- Under 20 characters
- Just a section heading (matches `^#{1,3} `)
- A commit hash or file path with no context
- A gate decision with no substantive content

---

## Finding 3: Integration Architecture (Priority-Ranked)

### P0: Session-Start Hook (highest impact, lowest risk)

**File:** `~/.claude/hooks/cortex-session-start.sh`

Currently injects `current-state.md` as `additionalContext`. Add fact retrieval between reading current-state and constructing JSON output:

```bash
# After reading CONTENT from current-state.md
SLUG=$(jq -r '.slug // ""' "$CLAUDE_PROJECT_DIR/.cortex/state.json" 2>/dev/null)
if [[ -f "$CLAUDE_PROJECT_DIR/.cortex/facts.jsonl" && -n "$SLUG" ]]; then
  # Fast grep-based retrieval for current slug (fallback)
  FACTS=$(grep "\"slug\":\"$SLUG\"" "$FACTS_FILE" | tail -10 | jq -r '.text' | head -20)
  # Or semantic retrieval if embeddings exist:
  # FACTS=$(python3 "$CLAUDE_PROJECT_DIR/scripts/cortex/cortex-retrieve.py" "$SLUG" --top-k 10 --format text)
fi
# Append FACTS to additionalContext
```

Non-breaking — just adds more context to existing injection.

### P1: cortex-drive Phase 1 Init

**File:** `skills/cortex-drive/SKILL.md` (after owner-intent reading, before decision table)

Add step: "Query facts for current slug. Surface any `lesson` or `pattern` type facts as context. If a lesson says 'approach X failed on a similar slug,' flag it before dispatching."

### P2: cortex-investigate Phase 2 (Pattern Analysis)

**File:** `skills/cortex-investigate/SKILL.md`

Add step: "Query facts for `pattern`, `lesson`, `observation` types matching the affected files or error type. Surface: 'Similar failure on slug X — root cause was Y.'"

### P3: cortex-research Phase 0

**File:** `skills/cortex-research/SKILL.md`

Add step: "Query facts matching the research topic. If prior research exists, note findings and avoid re-covering known territory."

---

## Finding 4: Auto-Memory Boundary

Claude Code's auto-memory (`~/.claude/projects/*/memory/`) and the knowledge engine are **complementary, not overlapping**:

| | Auto-Memory | Knowledge Engine |
|--|-------------|-----------------|
| **Captures** | User behavioral patterns ("always use external research") | Session operational intelligence ("decided X because Y") |
| **Granularity** | Coarse (prose paragraphs) | Fine (atomic JSONL facts) |
| **Retrieval** | Full load (all memories into context) | Semantic retrieval (top-k relevant) |
| **Control** | Opaque (Claude decides) | Transparent (deterministic extraction) |
| **Volume** | Low (3 memories for cortex) | High (53+ facts, growing) |

**Recommendation:** SUPPLEMENT, not replace. Don't write to auto-memory format (undocumented, could break). Don't ignore it either (it provides useful behavioral context). The two systems coexist.

---

## Finding 5: Pipeline Design

### Complete Data Flow

```
[compaction event]
    ↓
precompact.sh (sync, ~200ms)
  → captures decisions.md, STATE.md, CONTEXT.md, git log, state.json
  → writes precompact snapshot to .cortex/compaction/
    ↓
postcompact.js (sync, ~500ms)
  → reads precompact snapshot + investigation artifacts + contract Failed Approaches + research dossiers
  → extracts typed facts (9 categories)
  → quality filter (skip noise)
  → dedup by content hash (MD5 first 8 chars)
  → appends to .cortex/facts.jsonl
    ↓
cortex-embed.py (async, 3-10s)
  → reads facts.jsonl, incremental embedding (only new facts)
  → ollama nomic-embed-text 768-dim
  → writes .cortex/fact-embeddings.npy + fact-index.json + fact-embeddings.meta.json
  → graceful degradation: if ollama down, skip silently
    ↓
[query time — session start, skill invocation]
cortex-retrieve.py (80-400ms)
  → query embedding via ollama
  → cosine similarity against .npy
  → returns top-k facts as JSON
  → fallback: if no embeddings, grep facts.jsonl by slug tag
```

### Graceful Degradation Chain

| Failure | Behavior |
|---------|----------|
| ollama not running | Embedding skipped (async, non-blocking). Retrieval falls back to grep by slug. |
| No facts.jsonl | Session-start injects nothing extra. Skills proceed without facts. |
| No embeddings (.npy) | Retrieval falls back to grep by slug. |
| No investigation artifacts | E4 lesson/procedure extraction skipped for this compaction. |

---

## Revised Task Map

### Must-Do

| # | Task | Files | Effort | Notes |
|---|------|-------|--------|-------|
| 1 | Add quality filter to fact extraction | `cortex-postcompact.js` | Small | Skip noise: short texts, section headers, bare paths |
| 2 | Add 3 new extraction sources | `cortex-postcompact.js` | Medium | Failed Approaches, investigation artifacts, research dossiers |
| 3 | Add 3 E4 fact types (procedure, lesson, observation) | `cortex-postcompact.js` | Small | New extraction patterns for each type |
| 4 | Wire session-start hook to inject retrieved facts | `cortex-session-start.sh` | Small | Append top-k facts to additionalContext |
| 5 | Wire cortex-drive Phase 1 to read facts | `skills/cortex-drive/SKILL.md` | Small | Surface lessons/patterns before dispatch |
| 6 | Wire cortex-investigate to query facts | `skills/cortex-investigate/SKILL.md` | Small | Similar past failures in pattern analysis |
| 7 | Wire cortex-research to query facts | `skills/cortex-research/SKILL.md` | Small | Avoid re-covering known territory |
| 8 | Rebuild facts.jsonl with quality filter | One-time migration | Small | Re-extract from existing compaction snapshots |
| 9 | Extend test suite for new fact types + integration | `test/test_semantic_retrieval.py` | Medium | New tests for E4 types, quality filter, integration |

### Should-Do

| # | Task | Effort |
|---|------|--------|
| 10 | Add confidence scores to E4 facts | Small |
| 11 | Add `superseded_by` field for contradiction handling | Small |
| 12 | Add `--type` filter to cortex-retrieve.py | Small |
| 13 | Update benchmark numbers in archived spec | Tiny |

### Defer

| # | Task | Reason |
|---|------|--------|
| 14 | Graph memory (GraphRAG for relations) | Overkill at <10K facts |
| 15 | Adversarial memory security (A-MemGuard) | Premature until base system works |
| 16 | /cortex-remember command for explicit capture | Nice-to-have, compaction capture is sufficient |
| 17 | Cross-project fact sharing | Single-project scope is sufficient |

---

## Open Questions Resolved

> "Should fact extraction run in postcompact hook or separate async script?"
**Answer:** In postcompact hook (sync, ~500ms). Only embedding is async. Extraction is fast enough to be sync.

> "How does knowledge engine interact with Claude Code's auto-memory?"
**Answer:** Supplement. Auto-memory = behavioral patterns (opaque, coarse). Knowledge engine = operational intelligence (transparent, atomic). No conflict.

> "Should cortex-drive read facts at Phase 1, or should skills query on demand?"
**Answer:** Both. Drive reads at Phase 1 init (P1). Individual skills query on demand (P2-P3). Session-start provides the baseline (P0).

> "What's the right top-k for retrieval?"
**Answer:** Default 10, configurable. Prior spec validated this.

> "Should facts have confidence scores?"
**Answer:** Yes for E4 types (procedure, lesson, observation). Not needed for structural types (decision, constraint).

> "How do we handle fact contradiction?"
**Answer:** `superseded_by` field (should-do). Timestamp-based recency weighting in retrieval scoring as fallback.

> "Should there be a /cortex-remember command?"
**Answer:** Defer. Compaction-based extraction is sufficient for v1. Explicit capture is a v2 feature.

---

## Sources

### Internal (Existing Code)
- `scripts/cortex/cortex-embed.py` — production embedding script
- `scripts/cortex/cortex-retrieve.py` — production retrieval script
- `.claude/hooks/cortex-postcompact.js` — fact extraction (11KB)
- `test/test_semantic_retrieval.py` — 15 tests
- `.cortex/facts.jsonl` — 53 existing facts (quality issues documented)
- `.cortex/fact-embeddings.npy` — 53×768 numpy embeddings
- `docs/cortex/archive/semantic-retrieval/` — full spec + contract + benchmarks

### Internal (Prior Research)
- `docs/cortex/research/memory-extraction/concept-20260403T225000Z.md`
- `docs/cortex/research/pattern-harvest/concept-20260403T213444Z.md` (patterns #12, #13)

### Design
- `docs/cortex/research/knowledge-engine/concept-20260406T230000Z.md` — pipeline design with 12 JSONL examples
