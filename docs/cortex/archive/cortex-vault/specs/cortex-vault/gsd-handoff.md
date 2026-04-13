# GSD Handoff: cortex-vault

<!-- ART-04: GSD Handoff Template — produced by /cortex-spec -->

**Slug:** cortex-vault
**Timestamp:** 2026-04-13T14:30:00Z
**Status:** draft

---

## Objective

Wire the existing memory vault (`~/memory/vault/`) into Cortex's intelligence phases so that session start injects top-5 cross-slug vault facts into `additionalContext` and gate transitions (clarify brief, research dossier, spec) write typed facts back to the vault via a new `cortex-vault-extractor.py` script calling `add_fact()` directly.

---

## Deliverables

- `scripts/cortex/cortex-vault-extractor.py` — new Python extractor, path-based artifact detection, 9 extraction categories, idempotency guard, subprocess write to vault
- `.claude/hooks/cortex-session-start.sh` — modified (vault injection block after line 40)
- `~/.claude/skills/cortex-clarify/SKILL.md` — modified (Phase 4c insertion)
- `~/.claude/skills/cortex-research/SKILL.md` — modified (Phase 2.9 insertion)
- `~/.claude/skills/cortex-spec/SKILL.md` — modified (Phase 2c insertion)

---

## Requirements

- None formalized

---

## Tasks

- [ ] Write `scripts/cortex/cortex-vault-extractor.py` with CLI (`--artifact <path> --slug <slug>`), path-pattern artifact type detection (clarify/→brief, research/→dossier, specs/spec.md→spec), section-level extraction for all 9 categories, per-category `add_fact()` field values (confidence, importance, memory_type as defined in spec §2), idempotency guard by `(session_id, topic, content[:50])`, and soft-fail on vault unavailability
- [ ] Implement vault write via direct import: `sys.path.insert(0, os.path.expanduser("~/memory/vault/scripts/")); from fact_store import add_fact` — fact_store.py has no relative imports; its `__main__` is a test harness not a CLI — subprocess is incorrect
- [ ] Modify `.claude/hooks/cortex-session-start.sh`: add `VAULT_FACTS` block after line 40, add budget check (`max(0, 9500 - len(existing_content))`), add `VAULT MEMORY (cross-session):` section to `$EXTRA` block
- [ ] Run `python3` budget check to verify total `additionalContext` remains under 10,000 characters
- [ ] Edit `~/.claude/skills/cortex-clarify/SKILL.md` — insert Phase 4c (extractor call after clarify brief write, before Phase 5)
- [ ] Edit `~/.claude/skills/cortex-research/SKILL.md` — insert Phase 2.9 (extractor call after dossier write, matching existing Phase 2.9 pattern)
- [ ] Edit `~/.claude/skills/cortex-spec/SKILL.md` — insert Phase 2c (extractor call after spec write, matching existing Phase 2c pattern)
- [ ] Run idempotency test: call extractor twice on same artifact, verify no duplicate facts in vault
- [ ] Run soft-fail test: rename vault temporarily, verify hook and extractor complete without crashing

---

## Acceptance Criteria

- [ ] `cortex-session-start.sh` calls `recall_query.py` and injects vault facts into `additionalContext` under a distinct `VAULT MEMORY` section header
- [ ] Total `additionalContext` length after vault injection remains under 10,000 characters
- [ ] Vault read uses `--top-k 5 --project cortex` to scope retrieval to Cortex-relevant facts
- [ ] Vault read soft-fails gracefully (empty string, no error) when vault index is absent or query returns nothing
- [ ] `scripts/cortex/cortex-vault-extractor.py` exists and accepts `--artifact <path> --slug <slug>` arguments
- [ ] Extractor correctly identifies artifact type using path-pattern truth table: `clarify/`→brief, `research/`+not `current-understanding.md`→dossier, `specs/spec.md`→spec; any other path→error
- [ ] Extractor calls `add_fact()` for each extracted typed fact with exact per-category field values as specified in spec §2
- [ ] Extraction is idempotent: re-running extractor on same artifact path and slug does not create duplicate facts
- [ ] Vault write soft-fails gracefully (logged warning, no exception) when vault is unavailable
- [ ] `cortex-clarify` Phase 4c calls `cortex-vault-extractor.py` after writing the clarify brief
- [ ] `cortex-research` Phase 2.9 calls `cortex-vault-extractor.py` after writing the research dossier
- [ ] `cortex-spec` Phase 2c calls `cortex-vault-extractor.py` after writing the spec

---

## Contract Link

docs/cortex/contracts/cortex-vault/contract-001.md
