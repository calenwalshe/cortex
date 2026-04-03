# Contract: memory-extraction — execute

**ID:** memory-extraction-001
**Slug:** memory-extraction
**Phase:** execute
**Created:** 20260403T225500Z
**Status:** draft
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Enhance Cortex compaction hooks to extract atomic facts from session artifacts and store them in structured JSONL format, so that post-compaction context recovery preserves decisions, preferences, and patterns instead of losing them to a flat markdown summary.

---

## Deliverables

- Enhanced `.claude/hooks/cortex-precompact.sh` — enriched snapshot with decisions.md, STATE.md, CONTEXT.md, git log
- New `.claude/hooks/cortex-postcompact.js` — fact extraction + existing behavior preserved
- New `schemas/memory-fact.schema.json` — JSON Schema for fact format
- Modified `runtime-manifest.json` — postcompact hook reference update

---

## Scope

### In Scope

- Precompact hook enhancement (read additional Cortex artifacts)
- Postcompact hook rewrite (bash → Node.js, add fact extraction)
- Fact schema design (6 categories, required fields, content-hash dedup)
- JSONL fact store at `.cortex/facts.jsonl`
- Runtime manifest update

### Out of Scope

- Embedding/vector infrastructure
- Fact query/retrieval interface
- Cross-project fact sharing
- LLM-based extraction
- Fact TTL or automatic pruning
- Modifying any hooks other than precompact and postcompact

---

## Write Roots

- `.claude/hooks/` — cortex-precompact.sh, cortex-postcompact.js
- `schemas/` — memory-fact.schema.json
- `runtime-manifest.json`

---

## Done Criteria

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

## Validators

- [ ] [external] `test -f schemas/memory-fact.schema.json` exits 0
- [ ] [external] `grep "cortex-postcompact.js" runtime-manifest.json` returns match
- [ ] [external] `test -f .claude/hooks/cortex-postcompact.js` exits 0
- [ ] [external] `node -c .claude/hooks/cortex-postcompact.js` exits 0 (syntax check)
- [ ] [external] `grep "decisions.md\|STATE.md\|CONTEXT.md\|git log" .claude/hooks/cortex-precompact.sh` returns matches
- [ ] [external] `grep "facts.jsonl" .claude/hooks/cortex-postcompact.js` returns match
- [ ] [external] `grep "createHash\|md5\|content.*hash" .claude/hooks/cortex-postcompact.js` returns match (dedup logic)
- [ ] [judgment] Existing postcompact outputs (last-compact-summary.md, next-prompt.md) are functionally equivalent to current behavior

---

## Eval Plan

docs/cortex/evals/memory-extraction/eval-plan.md

---

## Approvals

- [ ] Contract approval
- [ ] Evals approval

---

## Failed Approaches

N/A — initial contract

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Restore `.claude/hooks/cortex-precompact.sh` from git: `git checkout HEAD~N -- .claude/hooks/cortex-precompact.sh`
- Delete `.claude/hooks/cortex-postcompact.js`
- Restore `.claude/hooks/cortex-postcompact.sh` from git (if removed)
- Delete `schemas/memory-fact.schema.json`
- Revert `runtime-manifest.json` postcompact entry back to .sh
- Delete `.cortex/facts.jsonl` if created

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1

---

## Completion Promise

<!-- The executing agent MUST emit this signal when all done criteria are satisfied: -->
<!-- CORTEX_PROMISE: memory-extraction-001 COMPLETE -->
