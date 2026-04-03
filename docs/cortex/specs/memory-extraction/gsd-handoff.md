# GSD Handoff: memory-extraction

**Slug:** memory-extraction
**Timestamp:** 20260403T225500Z
**Status:** draft

---

## Objective

Enhance the Cortex precompact and postcompact hooks so that compaction events extract atomic facts (decisions, preferences, patterns, constraints, blockers, context pointers) from Cortex artifacts and store them in `.cortex/facts.jsonl` — preserving session intelligence that the current flat markdown summary silently drops. Postcompact is rewritten as Node.js for reliable JSON handling. Existing postcompact outputs (last-compact-summary.md, next-prompt.md) are preserved.

---

## Deliverables

- Enhanced `.claude/hooks/cortex-precompact.sh` — reads decisions.md, STATE.md, CONTEXT.md, git log
- New `.claude/hooks/cortex-postcompact.js` — replaces .sh, extracts facts, preserves existing outputs
- New `schemas/memory-fact.schema.json` — fact format schema
- New `.cortex/facts.jsonl` — append-only fact store (created on first compaction)
- Modified `runtime-manifest.json` — updated postcompact hook reference

---

## Requirements

- None formalized

---

## Tasks

**Phase 1 — Schema:**
- [ ] Create `schemas/memory-fact.schema.json` with 6 fact categories

**Phase 2 — Precompact Enhancement:**
- [ ] Read decisions.md and append to precompact snapshot
- [ ] Read STATE.md accumulated context and append to snapshot
- [ ] Read recent CONTEXT.md files and append to snapshot
- [ ] Include `git log --oneline -20` in snapshot

**Phase 3 — Postcompact Rewrite:**
- [ ] Create cortex-postcompact.js preserving existing behavior
- [ ] Extract decision facts from decisions.md and STATE.md
- [ ] Extract constraint/preference facts from CONTEXT.md sections
- [ ] Extract context_pointer facts from git log
- [ ] Extract blocker facts from STATE.md
- [ ] Implement content-hash deduplication

**Phase 4 — Integration:**
- [ ] Update runtime-manifest.json (postcompact .sh → .js)
- [ ] Update settings.json hook command path

---

## Acceptance Criteria

- [ ] Precompact snapshot includes decisions.md content, STATE.md accumulated context, CONTEXT.md decisions, and git log
- [ ] Postcompact hook writes facts to `.cortex/facts.jsonl` in valid JSONL format
- [ ] Each fact has required fields: id, type, slug, text, source, extracted_at
- [ ] Facts are categorized into 6 types: decision, preference, constraint, pattern, blocker, context_pointer
- [ ] Duplicate facts (same content hash) are not appended
- [ ] Existing postcompact outputs preserved: last-compact-summary.md and next-prompt.md still written correctly
- [ ] Hook completes in <5 seconds on a typical project
- [ ] `schemas/memory-fact.schema.json` exists and validates against sample facts
- [ ] runtime-manifest.json updated to reference cortex-postcompact.js

---

## Contract Link

docs/cortex/contracts/memory-extraction/contract-001.md
