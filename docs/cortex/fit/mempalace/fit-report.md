# Fit Report: mempalace

**Slug:** mempalace
**Timestamp:** 20260409T200000Z
**Evaluated against:** Cortex lifecycle intelligence layer (file-based, single-user, Claude Code)
**Confidence:** low — no research dossier; reasoning from README, community analysis, and system map only
**Status:** pending-human-decision

---

## Tech Radar Ring

**Ring:** Assess

**Justification:** Fills the cross-session verbatim recall gap, but ChromaDB dependency conflicts with Cortex's no-external-service principle.

---

## Gap

MemPalace fills capabilities Cortex entirely lacks:

- **Verbatim conversation storage and retrieval.** Cortex's `facts.jsonl` extracts structured facts (decisions, lessons, observations) but discards the actual conversation. MemPalace stores raw exchanges and makes them searchable via semantic search. Six months of debugging sessions, architecture debates, and rationale discussions are currently lost when sessions end — MemPalace would preserve them.

- **Temporal knowledge graph.** Cortex has no graph structure over its facts. MemPalace's `knowledge_graph.py` (SQLite-backed) tracks entities, relationships, and temporal evolution. This would let queries like "what did we decide about auth in March?" return structured results rather than grep hits.

- **MCP server interface for memory.** Cortex has no MCP server. MemPalace exposes 19 MCP tools for memory operations (store, recall, search, organize). This would give Claude Code native tool access to persistent memory without custom hooks.

---

## Overlap

- **`facts.jsonl` + `cortex-retrieve.py` vs. MemPalace's semantic search.** Both store text and retrieve by relevance. `facts.jsonl` uses JSONL with optional embeddings (`cortex-embed.py` + `fact-embeddings.npy`); MemPalace uses ChromaDB with built-in vector search. MemPalace's retrieval is more mature (96.6% R@5 on LongMemEval) but the intent is similar — persistent knowledge retrieval across sessions.

- **Session-start context injection vs. MemPalace's recall tools.** The `cortex-session-start.sh` hook hydrates context from disk artifacts. MemPalace's MCP recall tools serve the same function — bringing past context into the current session. The delivery mechanism differs (hook injection vs. tool calls) but the goal overlaps.

- **`docs/cortex/system-map.md` vs. MemPalace's palace metaphor (wings/rooms).** Both provide spatial/structural organization of knowledge. The system map organizes architectural components; MemPalace's palace organizes conversation memories. Different content, similar organizational principle.

---

## Unique Contribution

- **The diary pattern.** MemPalace distinguishes between "drawers" (verbatim content) and "diary entries" (agent notes/reflections). This separation of raw data from interpreted observations has no Cortex analogue. `facts.jsonl` mixes both — a decision fact and an observation fact have the same schema. The diary pattern could improve fact quality by separating provenance.

---

## Conflict

- **ChromaDB dependency vs. "no database, no external service" anti-goal.** Owner-intent explicitly states: "Cortex will never require a database, external service, or network dependency for core operation. It is a file-based system." MemPalace requires ChromaDB (a vector database) as its storage backend. This is a hard architectural conflict. Mitigation: ChromaDB runs locally and is embeddable — it's not a cloud service — but it IS a database, which the anti-goal prohibits for core operation.

- **MCP server model vs. hook-based architecture.** Cortex integrates via Claude Code hooks and skills (`.claude/hooks/`, `.claude/skills/`). MemPalace integrates via MCP server (tool definitions exposed over a protocol). These are different integration models. Running both would mean two parallel context systems — hooks injecting Cortex state, MCP tools injecting MemPalace memories — with no coordination between them.

- **"Store everything" philosophy vs. "extract structured facts" philosophy.** MemPalace stores raw verbatim conversations. Cortex's `postcompact.js` deliberately extracts structured facts and discards the raw conversation. These are opposing design philosophies. Adopting both creates ambiguity about what the source of truth is — raw conversations or extracted facts.

---

## Strategic Direction

**Alignment:** partially aligned

MemPalace's trajectory (persistent cross-session memory, local-first, open-source) aligns with Cortex's Objective 3 (Zero context loss) and the file-based anti-goal spirit. But MemPalace is evolving toward a general-purpose memory platform (multi-user, multi-agent, Slack/ChatGPT imports), while Cortex is intentionally scoped to one user working with one AI on engineering tasks. The trajectories converge on the "no context loss" goal but diverge on scope and architecture.

---

## Pre-Populated Clarify Brief Fields

**Proposed goal:** Integrate MemPalace's verbatim conversation storage and temporal knowledge graph into Cortex so that debugging sessions, architecture rationale, and decision context survive across sessions without manual fact extraction.

**Constraints:**
- Must not introduce ChromaDB as a core dependency — either adapt to file-based storage or isolate as an optional layer
- Must not create a parallel context system — MemPalace memory and Cortex artifacts must coordinate, not compete
- Must reconcile "store everything" with Cortex's structured fact extraction — define which system is source of truth for what
- MCP server integration must coexist with hook-based architecture without creating two uncoordinated context paths

**Open questions:**
- Can MemPalace's ChromaDB backend be swapped for a file-based store (e.g., JSONL + lightweight embeddings) without losing the 96.6% retrieval quality?
- Would MemPalace's knowledge graph subsystem (`knowledge_graph.py`, SQLite) be useful standalone — detached from the palace metaphor and ChromaDB?
- How would MemPalace's MCP tools interact with the session-start hook and system map pointer injection? Would they complement or conflict?
- Is the diary pattern (separating raw data from agent notes) valuable enough to adopt independently of the rest of MemPalace?
- MemPalace is 3 days old with known issues (shell injection in hooks, unpinned ChromaDB, overstated claims corrected). Is it mature enough for even a trial?

---

## Human Decision

**Status:** pending-human-decision

To advance: change status to `approved` or `rejected` and add a one-line note.

- [ ] Approved — proceed to `/cortex-clarify mempalace`
- [ ] Rejected — archive this report, no further action

**Decision note:** _(fill in when deciding)_
