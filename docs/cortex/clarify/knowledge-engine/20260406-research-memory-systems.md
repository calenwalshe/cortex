# Research: Production AI Agent Memory Systems

**Slug:** knowledge-engine
**Date:** 2026-04-06
**Type:** External research (deep)
**Search rounds:** 4 waves, 18+ queries, 12 page fetches

---

## Executive Summary

Production agent memory in 2026 has converged on a shared pattern: **extract atomic facts from conversations via LLM, store in vector + optional graph, retrieve by semantic similarity with composite scoring, handle contradictions via LLM-driven ADD/UPDATE/DELETE/NOOP operations**. Every major system (Mem0, Zep, LangMem, CrewAI) implements some variant of this. The critical differentiators are (1) how contradiction/staleness is handled, (2) whether graph structure captures relationships, and (3) whether procedural memory (lessons/skills) exists alongside semantic memory.

Cortex's constraints (file-based, no external DB, local ollama embeddings, <5s hook budget) are unusual. No production system works this way -- they all assume a vector DB or cloud service. But the *patterns* are directly portable: the extraction pipeline, the four operations, the composite scoring, and especially the procedural memory designs.

---

## 1. Mem0 (Production Memory Layer)

**Source:** [Mem0 Paper (arXiv:2504.19413)](https://arxiv.org/abs/2504.19413) | [Mem0 Research](https://mem0.ai/research) | [State of AI Agent Memory 2026](https://mem0.ai/blog/state-of-ai-agent-memory-2026) | [GitHub](https://github.com/mem0ai/mem0)

### Architecture

Two-phase pipeline running on every interaction:

**Phase 1 -- Extraction:**
- Input: conversation summary S + last m=10 messages + current exchange
- LLM extraction function phi produces set of salient memories omega = {omega_1, omega_2, ..., omega_n}
- Output: atomic natural-language fact strings

**Phase 2 -- Update:**
- For each extracted fact, retrieve top-s=10 semantically similar existing memories
- LLM selects one of four operations via tool calling:
  - **ADD**: No semantic equivalent exists -- create new memory
  - **UPDATE**: Complementary info -- augment existing memory
  - **DELETE**: Contradiction detected -- remove old memory
  - **NOOP**: No change needed
- Operations execute against vector store

### Graph Variant (Mem0g)

Directed labeled knowledge graph G=(V,E,L) built alongside vector store:
- **Entity Extractor**: LLM identifies entities with type classification (Person, Location, Event, etc.)
- **Relation Generator**: LLM infers labeled edges as semantic triplets (v_source, relation, v_dest)
- **Conflict Detector**: Computes embeddings for entities, searches for existing nodes above similarity threshold t, flags contradictions
- **Update Resolver**: LLM decides whether to add, merge, invalidate, or skip graph elements. Invalidated edges are marked obsolete (not deleted) to preserve temporal reasoning.
- **Storage**: Neo4j graph DB + GPT-4o-mini for extraction/updates via function calling

### Retrieval

- **Vector path**: Semantic similarity search against fact embeddings
- **Graph path (Mem0g)**: Entity-centric (identify entities in query, explore relationships) + semantic triplet matching (encode query as embedding, match against relationship encodings)

### Contradiction Handling

LLM-driven. New facts compared against top-10 similar existing facts. The LLM reasons about whether the new fact contradicts, supplements, or is redundant with existing facts. No rule-based heuristics -- pure LLM judgment. Invalidated graph edges retain temporal metadata rather than being physically deleted.

### Performance (LOCOMO benchmark)

| Metric | Mem0 | Mem0g | Full-context | OpenAI Memory |
|--------|------|-------|-------------|---------------|
| Single-hop accuracy | 67.1% | 65.7% | -- | 63.8% |
| Multi-hop accuracy | 51.2% | 47.2% | -- | -- |
| Temporal reasoning | 55.5% | 58.1% | -- | -- |
| Overall (LLM Judge) | 66.9% | 68.4% | 72.9% | 52.9% |
| p95 latency | 1.44s | 2.59s | 17.12s | -- |
| Tokens/query | ~7k | ~14k | ~26k | -- |

**Key finding**: Full-context is most accurate but unusable in production. Mem0 trades ~6 percentage points for 91% lower latency and 90% fewer tokens.

### What Cortex Can Steal

1. **The four-operation model (ADD/UPDATE/DELETE/NOOP)** -- directly applicable to fact reconciliation at compaction time
2. **Extract-then-reconcile pipeline** -- extract facts first, then compare against existing facts.jsonl
3. **Graph invalidation over deletion** -- mark facts as superseded rather than removing, preserving history
4. **Scoped memory** -- Mem0 uses user_id/agent_id/run_id scopes. Cortex equivalent: slug_id, milestone_id, global scope

---

## 2. Zep (Temporal Knowledge Graph)

**Source:** [Zep Paper (arXiv:2501.13956)](https://arxiv.org/abs/2501.13956) | [Graphiti GitHub](https://github.com/getzep/graphiti) | [Zep Blog](https://blog.getzep.com/zep-a-temporal-knowledge-graph-architecture-for-agent-memory/)

### Architecture

Three-tier hierarchical knowledge graph G=(N, E, phi):

**Tier 1 -- Episode Subgraph (G_e):**
- Raw input data (messages, text, JSON) stored as non-lossy episodic nodes
- Edges connect episodes to extracted semantic entities
- Bidirectional tracing for citation/provenance

**Tier 2 -- Semantic Entity Subgraph (G_s):**
- Extracted and resolved entity nodes
- Semantic edges representing relationships
- Built from episodes via LLM extraction

**Tier 3 -- Community Subgraph (G_c):**
- Clusters of strongly connected entities (label propagation algorithm)
- High-level summarizations via map-reduce
- Enables reasoning about groups/themes

### Bi-Temporal Model (unique to Zep)

Every edge tracks four timestamps:
- **t'_created, t'_expired** (transactional timeline T'): When facts enter/leave the system
- **t_valid, t_invalid** (event timeline T): When facts actually held true in the real world

This enables queries like "What was true as of date X?" and "When did we learn fact Y?"

### Contradiction Resolution

LLM compares new edges against semantically related existing edges. For temporally overlapping conflicts, t_invalid is set to the t_valid of the invalidating edge. **New information always takes priority.** Invalidated edges are preserved with temporal metadata.

### Retrieval Pipeline: f(alpha) = chi(rho(phi(alpha)))

1. **Search (phi)**: Three parallel strategies:
   - Cosine similarity (phi_cos) -- semantic
   - BM25 full-text (phi_bm25) -- keyword
   - Breadth-first search (phi_bfs) -- graph traversal within n-hops
2. **Reranker (rho)**: Reciprocal Rank Fusion, MMR, episode-mentions reranker, node distance reranker, optional cross-encoder LLM
3. **Constructor (chi)**: Formats output with t_valid/t_invalid ranges, entity names, community summaries

### Performance (LongMemEval -- 115k token conversations)

| Model | Zep Accuracy | Baseline | Improvement | Latency |
|-------|-------------|----------|-------------|---------|
| gpt-4o-mini | 63.8% | 55.4% | +15.2% | 3.20s vs 31.3s |
| gpt-4o | 71.2% | 60.2% | +18.5% | 2.58s vs 28.9s |

Context tokens: ~1.6k (Zep) vs ~115k (baseline). Temporal reasoning improved by +38.4%.

### What Cortex Can Steal

1. **Bi-temporal model** -- Track when a fact was true vs when Cortex learned it. Critical for "this decision was made in slug-3 but reversed in slug-7" reasoning
2. **Episode-to-entity extraction pattern** -- Raw session data (episodes) -> extracted facts (entities/edges) -> clustered themes (communities). Maps to: compaction handoff -> facts.jsonl -> milestone summaries
3. **Hybrid search (semantic + keyword + graph)** -- Even without a graph DB, combining embedding similarity with keyword matching improves retrieval precision
4. **Reranking pipeline** -- Even simple RRF over multiple retrieval signals beats single-signal retrieval

---

## 3. MemGPT / Letta (OS-Style Memory Management)

**Source:** [Letta Docs](https://docs.letta.com/concepts/memgpt/) | [Agent Memory Blog](https://www.letta.com/blog/agent-memory) | [Letta V1 Architecture](https://www.letta.com/blog/letta-v1-agent) | [Memory Benchmark](https://www.letta.com/blog/benchmarking-ai-agent-memory)

### Architecture

Operating system metaphor for memory management:

**Core Memory (RAM):**
- Structured, labeled blocks always injected into system prompt
- Each block has: label, description, value, character limit
- Examples: persona block, user preferences block, task objectives block
- Agent can read AND WRITE these blocks via tool calls

**Recall Memory (Conversation History):**
- Complete interaction history, searchable
- Automatically persisted to disk
- Equivalent to "scrollback buffer"

**Archival Memory (Disk):**
- External knowledge in vector/graph databases
- Retrieved on demand via search tools
- Agent explicitly moves data between core and archival

**Message Buffer (Working Memory):**
- Recent conversation messages
- Subject to eviction and summarization when context fills

### Memory Management

- **Paging**: Agent autonomously moves data between in-context (core) and out-of-context (archival) using tool calls
- **Summarization**: When context reaches capacity, recursive summarization compresses older messages
- **Sleep-Time Compute**: Asynchronous memory operations during idle periods -- agents refine memory blocks without impacting response latency

### V1 Architecture Changes (2025-2026)

- Deprecated: heartbeats, send_message tool, prompted reasoning tokens
- New: native model reasoning (GPT-5, Claude 4.5 Sonnet handle reasoning natively)
- Simplified system prompts; less framework overhead

### Benchmark Surprise: Filesystem Beats Specialized Memory

Letta attached conversation history as files and gave agents basic file tools (grep, search_files, open, close). **Result: 74.0% accuracy on LoCoMo vs Mem0g's 68.5%.** The hypothesis: agents are better at using familiar tools (filesystem operations) from their training data than specialized memory APIs.

### What Cortex Can Steal

1. **Core memory blocks** -- Cortex already has something like this (state.json, decisions.md). Formalizing it as "always-in-context structured blocks" with explicit read/write semantics is valuable
2. **Agent-driven memory management** -- Let the agent decide what to remember/forget rather than only extracting at compaction
3. **Sleep-time compute pattern** -- Async memory refinement during idle. Maps to: post-session background processing that improves fact quality
4. **Filesystem-as-memory insight** -- Cortex IS file-based. This validates the approach. The key is making facts greppable/searchable, not necessarily fancy retrieval
5. **Hierarchical eviction** -- Current context -> summarized context -> archived facts. This maps to Cortex's working session -> compaction handoff -> facts.jsonl

---

## 4. LangGraph Store / LangMem

**Source:** [LangMem Conceptual Guide](https://langchain-ai.github.io/langmem/concepts/conceptual_guide/) | [LangMem DeepWiki](https://deepwiki.com/langchain-ai/langmem) | [LangGraph Store DeepWiki](https://deepwiki.com/langchain-ai/langgraph/4.3-store-system) | [LangMem SDK Launch](https://blog.langchain.com/langmem-sdk-launch/)

### Architecture (Two Layers)

**Core API Layer** (stateless):
- `create_memory_manager`: Extract and consolidate memories from conversations
- `create_prompt_optimizer`: Refine system prompts based on feedback
- `create_thread_extractor`: Generate conversation summaries
- `summarize_messages`: Manage short-term context within token limits

**Stateful Integration Layer** (LangGraph BaseStore):
- `create_memory_store_manager`: Auto-persist extracted memories
- `create_manage_memory_tool`: Agent tools for CRUD on memories
- `create_search_memory_tool`: Semantic retrieval tools

### Memory Types

**Semantic Memory** -- Two representations:
- **Collections**: Unbounded individual documents, full CRUD, requires reconciliation logic. Each memory gets a UUID.
- **Profiles**: Single structured document per schema, updated in-place. Ideal for user preferences.

**Episodic Memory** -- Structured records capturing: observation, thoughts, action, result. Preserves full decision chains for experience replay.

**Procedural Memory** -- System prompts that evolve through feedback. `create_prompt_optimizer` uses metaprompt strategy to iteratively refine instructions based on agent trajectories + feedback scores.

### Extraction Pipeline

1. Format conversation + existing memories into LLM context
2. LLM extraction loop (up to max_steps iterations, parallel tool calling)
3. Three operation types: create (new UUID), update (preserve ID), delete (mark RemoveDoc)
4. Configurable flags: enable_inserts, enable_updates, enable_deletes

### Consolidation & Contradiction

When new info contradicts existing memories:
- System detects contradictory or supplementary information
- Updates preserve original memory ID while refining content
- Deletions mark memories as RemoveDoc
- Delegated to LLM reasoning within custom instructions (no rule-based heuristics)

### Processing Modes

**Hot Path (Conscious)**: Memory operations during active conversation. Adds latency but enables immediate context updates.

**Background (Subconscious)**: ReflectionExecutor runs after conversations. Deeper consolidation, no latency impact. "Higher recall of extracted information."

### Store System (LangGraph BaseStore)

- Hierarchical tuple-based namespaces: ("org", "{org_id}", "user", "{user_id}")
- TTL support: default_ttl, refresh_on_read, sweep_interval_minutes
- Vector search: PostgreSQL (pgvector, HNSW/IVFFlat), SQLite (sqlite-vec)
- Backends: InMemoryStore, AsyncPostgresStore, SqliteStore

### What Cortex Can Steal

1. **Hot path vs background path** -- Maps perfectly to Cortex: hot path = /cortex-remember command for explicit capture; background path = postcompact extraction
2. **Procedural memory as prompt optimization** -- System prompts that evolve based on feedback. Cortex could store "approach patterns" that refine skill system prompts over time
3. **TTL on memories** -- Time-to-live for facts. Older facts decay in relevance without manual cleanup
4. **Enable flags pattern** -- Configurable enable_inserts/enable_updates/enable_deletes per extraction context
5. **Namespace hierarchy** -- Maps to: ("cortex", "{milestone}", "{slug}", "{fact_type}") for scoped retrieval

---

## 5. CrewAI Memory

**Source:** [CrewAI Memory Docs](https://docs.crewai.com/en/concepts/memory) | [DeepWiki CrewAI Memory](https://deepwiki.com/crewAIInc/crewAI/7.2-memory-configuration-and-storage)

### Architecture

Unified Memory class replacing separate types. Uses LLM to analyze content on save (infers scope, categories, importance).

### Composite Scoring (most directly applicable to Cortex)

```
composite = semantic_weight * similarity + recency_weight * decay + importance_weight * importance
```

Where:
- **Similarity**: Vector distance normalized 0-1
- **Decay**: Exponential `0.5^(age_days / half_life_days)`
- **Importance**: 0-1 score assigned during encoding

Defaults: semantic=0.5, recency=0.3 (30-day half-life), importance=0.2

Tunable per use case:
- Sprint retrospectives: recency_weight=0.5, half_life=7 days
- Architecture knowledge base: importance_weight=0.5, half_life=180 days

### Memory Consolidation

- Similar existing records checked (cosine threshold 0.85)
- LLM decides: keep, update, delete, or insert
- Batch dedup at 0.98 cosine similarity using pure vector math (no LLM calls)
- `remember_many()` is non-blocking (background thread), `recall()` auto-drains pending writes

### Fact Extraction

`extract_memories()` breaks raw text into discrete, atomic statements. Prevents storing large blobs -- creates searchable individual facts.

### Staleness

Exponential decay: memories reach 50% relevance at configured half_life_days. Old info gradually loses priority without deletion. "Long tail" recall still possible.

### What Cortex Can Steal

1. **Composite scoring formula** -- Directly implementable with numpy. Blend semantic similarity + recency decay + importance for retrieval ranking
2. **Exponential decay for staleness** -- `0.5^(age_days / half_life)` is simple, tunable, and handles the "prefer X" contradiction problem (newer facts naturally outrank older contradicting facts)
3. **Configurable half-life per context** -- Different decay rates for different fact types (decisions decay fast, architectural patterns decay slow)
4. **Batch dedup at high threshold** -- 0.98 cosine similarity check before storing prevents near-duplicates without LLM calls
5. **Importance scoring** -- Explicit decisions get high importance; inferred patterns get low. This answers the clarify brief's open question about confidence scores

---

## 6. Procedural Memory Systems

### Voyager (Skill Library)

**Source:** [Voyager Project](https://voyager.minedojo.org/) | [Paper (arXiv:2305.16291)](https://arxiv.org/abs/2305.16291)

- Skills stored as **executable code** indexed by description embeddings
- Top-5 relevant skills retrieved for new tasks via cosine similarity
- Skills are compositional: complex skills built from simpler ones
- Eliminates catastrophic forgetting -- skills persist in library
- **Key insight**: Code-as-memory compresses multi-step procedures into retrievable, executable units

### Reflexion (Verbal Reinforcement Learning)

**Source:** [Paper (arXiv:2303.11366)](https://arxiv.org/abs/2303.11366) | [GitHub](https://github.com/noahshinn/reflexion)

- After each trial, agent writes verbal self-reflection
- Reflections stored in episodic memory buffer (bounded, usually 1-3 entries)
- Next trial includes prior reflections in context
- Results: +22% on AlfWorld, +20% on HotPotQA, +11% on HumanEval
- **Key insight**: Natural language "lessons learned" are sufficient feedback signal -- no weight updates needed

### ReMe (Remember Me, Refine Me)

**Source:** [Paper (arXiv:2512.10696)](https://arxiv.org/abs/2512.10696) | [GitHub](https://github.com/agentscope-ai/ReMe)

Three-mechanism framework:
1. **Multi-faceted distillation**: Extract success patterns, failure triggers, comparative insights
2. **Context-adaptive reuse**: Scenario-aware indexing (not just semantic similarity)
3. **Utility-based refinement**: Autonomously add valid memories, prune outdated ones

Key finding: **Smaller models + ReMe surpass larger baselines.** Memory-scaling effect validated.

Released `reme.library` -- fine-grained procedural memory dataset with structured success/failure patterns.

### Mem^p (Procedural Memory Framework)

**Source:** [Paper (arXiv:2508.06433)](https://arxiv.org/html/2508.06433v2)

Two storage formats:
- **Trajectory**: Complete execution traces stored verbatim
- **Script Abstraction**: High-level summaries distilled from trajectories

Three update strategies:
1. **Vanilla Addition**: Append all trajectories
2. **Validation Filtering**: Store only successful trajectories
3. **Reflection-Based Adjustment**: Revise failed memories by combining error analysis with originals

Update formula: U = Add(M_new) - Remove(M_obsolete) + Update(M_existing)

Key findings:
- Combined trajectory + script achieves optimal performance
- Excessive memories degrade performance (context pollution)
- Memory from stronger models transfers to weaker models (+5% accuracy)

### What Cortex Can Steal

1. **Lesson extraction at compaction** -- "Approach X failed because Y" and "Approach X succeeded because Y" as first-class fact types. Reflexion proves natural language lessons are effective.
2. **Success/failure tagging** -- ReMe's multi-faceted distillation: extract success patterns AND failure triggers separately. Map to fact types: lesson_success, lesson_failure
3. **Bounded lesson buffer** -- Reflexion uses only 1-3 reflections. For Cortex: retrieve top-3 most relevant lessons per task, not all lessons ever.
4. **Script abstraction** -- Mem^p shows that high-level summaries ("When doing X, first check Y, then Z") outperform raw trajectories. Cortex procedures should be abstracted, not verbatim session dumps.
5. **Context pollution guard** -- Too many retrieved facts hurt performance. Cortex needs a hard ceiling on retrieved facts (top-k with k tuned per context).

---

## 7. A-MEM (Agentic Memory / Zettelkasten)

**Source:** [Paper (arXiv:2502.12110)](https://arxiv.org/abs/2502.12110) | [GitHub](https://github.com/agiresearch/A-mem) | NeurIPS 2025

- Inspired by Zettelkasten note-taking method
- Each memory is an interconnected "note" with: content, contextual description, keywords, metadata, links to related notes
- **Self-organizing**: Memories actively generate their own descriptions and connections
- **Evolving**: New information can revise not only new entries but also update prior memories
- **Key insight**: Memory as a living, self-maintaining knowledge base rather than passive storage

### What Cortex Can Steal

1. **Interconnected facts** -- Facts can reference other facts (e.g., "decision D in slug-3" links to "lesson L that emerged from D's consequences in slug-7")
2. **Self-describing facts** -- Each fact carries its own contextual description and keywords, enabling retrieval without external metadata

---

## 8. Academic Survey Findings

### "Memory in the Age of AI Agents" (Dec 2025)

**Source:** [arXiv:2512.13564](https://arxiv.org/abs/2512.13564)

Taxonomy:
- **Factual Memory**: Knowledge about the world (decisions, preferences, facts)
- **Experiential Memory**: Past interactions and learned behaviors
- **Working Memory**: Current task context and intermediate states

Dynamic processes: Formation -> Evolution -> Retrieval

Three realization forms: token-level, parametric (in weights), latent (embedding space)

### Key Design Pattern: Episodic-to-Semantic Consolidation

Repeated experiences give rise to generalized knowledge. The progression: raw session data (episodic) -> extracted facts (semantic) -> abstracted lessons (procedural). This is exactly Cortex's compaction -> fact extraction -> lesson generalization pipeline.

---

## 9. Open Problems (Industry-Wide)

From the State of AI Agent Memory 2026 report and academic surveys:

1. **Memory staleness at scale** -- Distinguishing outdated (time-decayed) from stale (once-accurate, now wrong) remains unsolved
2. **Context poisoning** -- Hallucinations entering memory and compounding over time
3. **Context pollution** -- Too much retrieved memory degrades model performance
4. **Cross-session identity resolution** -- Linking facts across sessions/devices/auth boundaries
5. **Application-level evaluation** -- No standard benchmark for domain-specific memory quality
6. **Privacy/consent** -- User memory inspection, editing, deletion policies are ad-hoc

Drew Breunig's four failure modes apply directly to Cortex:
- **Context poisoning**: An incorrect fact from a hallucinated decision propagating forward
- **Context distraction**: Model over-focuses on retrieved facts vs current task
- **Context confusion**: Superfluous facts influencing reasoning
- **Context clash**: Contradictory facts within retrieved set

---

## 10. Synthesis: What This Means for Cortex Knowledge Engine

### Validated Design Decisions

The clarify brief's architecture aligns with industry consensus:
- Atomic fact extraction at compaction -- every system does this
- JSONL append-only storage -- adequate for <10K facts (CrewAI uses SQLite3 for similar scale)
- Semantic retrieval with embeddings -- universal pattern
- Pattern-based extraction (no LLM in hooks) -- unusual but viable. CrewAI's batch dedup uses pure vector math. Regex/pattern extraction for decisions.md format is defensible.

### Design Recommendations from Research

| Decision | Recommendation | Evidence |
|----------|---------------|----------|
| Contradiction handling | Recency-weighted scoring + explicit supersede metadata | CrewAI decay formula + Zep temporal invalidation |
| Fact types | decision, preference, pattern, procedure, lesson_success, lesson_failure | Mem0 semantic + Mem^p procedural + Reflexion lessons |
| Retrieval scoring | Composite: 0.5*semantic + 0.3*recency + 0.2*importance | CrewAI's tuned defaults, validated at scale |
| Top-k retrieval | Default 10, max 15. Context pollution observed above this. | Mem^p shows excessive memory degrades performance |
| Confidence scores | Yes. Explicit decisions = 1.0, inferred patterns = 0.5, lessons = 0.7 | Maps to CrewAI's importance scoring |
| Staleness | Exponential decay: 0.5^(age_days / half_life). Half-life varies by type: decisions=30d, patterns=90d, lessons=180d | CrewAI + Mem0 validated pattern |
| Fact supersession | Mark old fact superseded (not deleted), preserve for history | Zep bi-temporal + Mem0g invalidation pattern |
| Procedural memory | Store abstracted lessons, not raw trajectories | Mem^p shows script abstraction > raw trajectories |
| Batch dedup | 0.98 cosine threshold, pure vector math, no LLM | CrewAI production pattern |
| /cortex-remember | Yes, implement. Maps to LangMem "hot path" pattern | LangMem conscious vs subconscious formation |

### Architecture Mapping

```
Industry Pattern          -> Cortex Equivalent
---------------------------------------------------------
Episode (raw data)        -> Compaction handoff files (current-state.md, decisions.md)
Semantic extraction       -> postcompact hook fact extraction (pattern-based)
Vector store              -> .cortex/embeddings.npy (numpy pre-computed)
Fact store                -> .cortex/facts.jsonl (append-only)
Graph relationships       -> NOT NEEDED at current scale (<10K facts)
Composite scoring         -> numpy dot product + decay formula + importance
TTL/staleness             -> Exponential decay in retrieval scoring
Contradiction resolution  -> Newer facts outrank older via recency weight + supersede field
Procedural memory         -> lesson_success / lesson_failure fact types
Hot path capture          -> /cortex-remember command
Background extraction     -> postcompact hook -> async embedding
```

### The Letta Filesystem Insight

Letta's benchmark finding (filesystem 74.0% > Mem0g 68.5%) validates Cortex's file-based approach. Agents are better at using familiar tools than specialized memory APIs. Cortex's grep-able JSONL + numpy embeddings may outperform a "proper" vector DB for an LLM agent that knows how to search files.

### Critical Risk: Context Pollution

Every system warns about this. Retrieving too many facts hurts more than helps. Cortex must:
1. Hard cap top-k (default 10)
2. Score threshold (don't return facts below similarity 0.3)
3. Deduplicate near-identical facts before injection
4. Separate "always-in-context" facts (core memory blocks) from "retrieved-on-demand" facts

---

## Sources

- [Mem0 Paper: Building Production-Ready AI Agents with Scalable Long-Term Memory](https://arxiv.org/abs/2504.19413)
- [Mem0 Research Results](https://mem0.ai/research)
- [State of AI Agent Memory 2026](https://mem0.ai/blog/state-of-ai-agent-memory-2026)
- [Mem0 GitHub](https://github.com/mem0ai/mem0)
- [Mem0 API Documentation](https://docs.mem0.ai/api-reference/memory/add-memories)
- [Zep: Temporal Knowledge Graph Architecture for Agent Memory](https://arxiv.org/abs/2501.13956)
- [Graphiti (Zep's open-source graph engine)](https://github.com/getzep/graphiti)
- [Letta Docs (MemGPT)](https://docs.letta.com/concepts/memgpt/)
- [Letta: Agent Memory Design Patterns](https://www.letta.com/blog/agent-memory)
- [Letta V1 Architecture](https://www.letta.com/blog/letta-v1-agent)
- [Letta: Benchmarking AI Agent Memory](https://www.letta.com/blog/benchmarking-ai-agent-memory)
- [LangMem Conceptual Guide](https://langchain-ai.github.io/langmem/concepts/conceptual_guide/)
- [LangMem SDK Launch Blog](https://blog.langchain.com/langmem-sdk-launch/)
- [LangGraph Store System (DeepWiki)](https://deepwiki.com/langchain-ai/langgraph/4.3-store-system)
- [CrewAI Memory Documentation](https://docs.crewai.com/en/concepts/memory)
- [CrewAI Memory Deep Dive (SparkCo)](https://sparkco.ai/blog/deep-dive-into-crewai-memory-systems)
- [Voyager: Open-Ended Embodied Agent](https://voyager.minedojo.org/)
- [Reflexion: Verbal Reinforcement Learning](https://arxiv.org/abs/2303.11366)
- [ReMe: Dynamic Procedural Memory Framework](https://arxiv.org/abs/2512.10696)
- [Mem^p: Exploring Agent Procedural Memory](https://arxiv.org/html/2508.06433v2)
- [A-MEM: Agentic Memory for LLM Agents (NeurIPS 2025)](https://arxiv.org/abs/2502.12110)
- [Memory in the Age of AI Agents: A Survey](https://arxiv.org/abs/2512.13564)
- [AI Agent Memory Comparison (Medium)](https://yogeshyadav.medium.com/ai-agent-memory-systems-in-2026-mem0-zep-hindsight-memvid-and-everything-in-between-compared-96e35b818da8)
- [AI Agent Memory Comparative Analysis (DEV)](https://dev.to/foxgem/ai-agent-memory-a-comparative-analysis-of-langgraph-crewai-and-autogen-31dp)
