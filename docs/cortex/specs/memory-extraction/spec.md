# Spec: memory-extraction

**Slug:** memory-extraction
**Timestamp:** 20260403T225500Z
**Status:** draft

---

## 1. Problem

Cortex's postcompact hook writes a flat markdown summary containing only metadata (slug, mode, contract path) but drops all session intelligence — decisions made, approaches tried, patterns discovered, constraints identified during work. After compaction, the system loses the nuanced context that informed recent work. This forces users to re-derive decisions and re-discover patterns that were already established, wasting tokens and degrading continuity quality. The precompact hook similarly captures only metadata, missing the richer intelligence available in Cortex artifacts (decisions.md, STATE.md accumulated context, CONTEXT.md implementation decisions, recent git history).

---

## 2. Scope

### In Scope

- Enhance cortex-precompact.sh to capture richer data from Cortex artifacts (decisions.md, STATE.md, CONTEXT.md files, recent git log)
- Rewrite cortex-postcompact.sh as Node.js for reliable JSON manipulation
- Design and implement a 6-category fact schema (decision, preference, constraint, pattern, blocker, context_pointer)
- Extract atomic facts from the enriched precompact snapshot using pattern-based extraction (regex, structural parsing)
- Store facts in `.cortex/facts.jsonl` (append-only, content-hash deduplication)
- Preserve existing postcompact behavior (last-compact-summary.md and next-prompt.md still written)

### Out of Scope

- Embedding/vector infrastructure (future semantic retrieval milestone)
- Query interface for extracted facts (retrieval is separate)
- Replacing the existing auto-memory system in ~/.claude/projects/*/memory/
- Modifying any hooks other than precompact and postcompact
- Cross-project fact sharing
- LLM-based extraction (hooks cannot make API calls)
- Fact TTL or automatic pruning (v1 is append-only)

---

## 3. Architecture Decision

**Chosen approach:** Enhance both precompact and postcompact hooks. Precompact captures richer artifact data. Postcompact (rewritten as Node.js) extracts atomic facts from the enriched snapshot and existing Cortex artifacts, appending them to a single `.cortex/facts.jsonl` file with content-hash deduplication.

**Rationale:** Pattern-based extraction from existing Cortex artifacts is reliable without LLM calls, stays within the <5s hook performance budget, and produces a format (JSONL) that future embedding systems can consume directly. Node.js is chosen over bash for the postcompact hook because JSON manipulation in bash is fragile and error-prone.

### Alternatives Considered

- **LLM-based extraction via API call:** Rejected — hooks cannot make network calls, and latency would exceed the 5-second budget.
- **SQLite database for fact storage:** Rejected — adds a dependency (better-sqlite3), and JSONL is simpler, more portable, and equally suitable for future embedding ingestion.
- **Modify only postcompact, not precompact:** Rejected — precompact currently captures only metadata. Without enriching the precompact snapshot, the postcompact hook has insufficient source material.
- **Store facts in per-session files:** Rejected — a single append-only file is simpler to query (grep) and deduplicate than scattered per-session files.

---

## 4. Interfaces

- `.claude/hooks/cortex-precompact.sh` — Enhanced to read additional Cortex artifacts (decisions.md, STATE.md, CONTEXT.md files, git log). Writes enriched snapshot to `.cortex/compaction/precompact-{timestamp}.md`.
- `.claude/hooks/cortex-postcompact.sh` → `.claude/hooks/cortex-postcompact.js` — Rewritten as Node.js. Reads enriched precompact snapshot + Cortex artifacts. Writes facts to `.cortex/facts.jsonl`. Still writes `last-compact-summary.md` and `next-prompt.md`.
- `.cortex/facts.jsonl` — New file. Append-only fact store. Each line is a JSON object conforming to the fact schema.
- `schemas/memory-fact.schema.json` — New file. JSON Schema for the fact format.
- `runtime-manifest.json` — Updated hook entry (postcompact .sh → .js).

---

## 5. Dependencies

- **Node.js** — Required for postcompact.js. Already available in all Cortex environments (used by resolve-autonomy.js, token-ledger.js).
- **crypto module (Node.js built-in)** — For MD5 content hashing in deduplication. No external packages.
- **fs, path, os modules (Node.js built-in)** — File operations. No external packages.
- **cortex-precompact.sh** — Must run before cortex-postcompact.js (PreCompact event fires before PostCompact).
- **Existing Cortex artifacts** — decisions.md, STATE.md, current-state.md, CONTEXT.md files must exist in their standard locations.

---

## 6. Risks

- **Extraction quality without LLM** — Pattern-based extraction may miss nuanced decisions expressed in non-standard formats. Mitigation: Design extraction patterns around known Cortex artifact structures (which are template-driven and consistent). Accept that extraction is best-effort, not perfect.
- **Fact store unbounded growth** — Without pruning, facts.jsonl grows indefinitely. Mitigation: Typical project produces <100 facts per milestone. At ~200 bytes per fact, 10,000 facts = ~2MB. Pruning can be added in a future milestone if needed.
- **PostCompact hook timing** — If precompact snapshot isn't written before postcompact runs, extraction has no source material. Mitigation: PreCompact events are guaranteed to fire before PostCompact in Claude Code's hook lifecycle.
- **Breaking existing postcompact behavior** — Rewriting the hook could break last-compact-summary.md and next-prompt.md generation. Mitigation: Preserve exact existing output as the first step in the new hook, then add fact extraction as an additional step.

---

## 7. Sequencing

1. **Design fact schema** — Create `schemas/memory-fact.schema.json` defining the 6 fact categories and required fields. Verify: schema file exists and validates.

2. **Enhance precompact hook** — Modify cortex-precompact.sh to read decisions.md, STATE.md accumulated context, recent CONTEXT.md files, and `git log --oneline -20`. Write enriched snapshot. Verify: enriched snapshot contains all source sections.

3. **Rewrite postcompact hook** — Create cortex-postcompact.js (Node.js). Preserve existing behavior (last-compact-summary.md, next-prompt.md). Add fact extraction from enriched snapshot + Cortex artifacts. Write to `.cortex/facts.jsonl` with content-hash dedup. Verify: facts.jsonl populated, existing outputs preserved.

4. **Update runtime-manifest.json** — Change postcompact hook entry from .sh to .js. Verify: manifest points to correct file.

---

## 8. Tasks

- [ ] Create `schemas/memory-fact.schema.json` with 6 fact categories and required fields
- [ ] Enhance `cortex-precompact.sh` to read decisions.md and append to snapshot
- [ ] Enhance `cortex-precompact.sh` to read STATE.md accumulated context and append to snapshot
- [ ] Enhance `cortex-precompact.sh` to read recent CONTEXT.md files and append to snapshot
- [ ] Enhance `cortex-precompact.sh` to include `git log --oneline -20` in snapshot
- [ ] Create `cortex-postcompact.js` with existing behavior preserved (summary + next-prompt)
- [ ] Add fact extraction logic: parse decisions from decisions.md and STATE.md
- [ ] Add fact extraction logic: parse constraints and preferences from CONTEXT.md sections
- [ ] Add fact extraction logic: parse recent git commits as context_pointer facts
- [ ] Add fact extraction logic: parse blockers from STATE.md
- [ ] Implement content-hash deduplication before appending to facts.jsonl
- [ ] Update `runtime-manifest.json` to point postcompact to .js file
- [ ] Update `.claude/settings.json` hook command path (postcompact .sh → .js)

---

## 9. Acceptance Criteria

- [ ] Precompact snapshot includes decisions.md content, STATE.md accumulated context, CONTEXT.md decisions, and git log
- [ ] Postcompact hook writes facts to `.cortex/facts.jsonl` in valid JSONL format
- [ ] Each fact has required fields: id, type, slug, text, source, extracted_at
- [ ] Facts are categorized into 6 types: decision, preference, constraint, pattern, blocker, context_pointer
- [ ] Duplicate facts (same content hash) are not appended
- [ ] Existing postcompact outputs preserved: last-compact-summary.md and next-prompt.md still written correctly
- [ ] Hook completes in <5 seconds on a typical project
- [ ] `schemas/memory-fact.schema.json` exists and validates against sample facts
- [ ] runtime-manifest.json updated to reference cortex-postcompact.js
