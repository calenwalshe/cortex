# GSD Handoff: memory-bank-archive

<!-- ART-04: GSD Handoff Template — produced by /cortex-spec -->

**Slug:** memory-bank-archive
**Timestamp:** 20260331T001500Z
**Status:** draft

---

## Objective

Build a `/cortex-close` skill and supporting scaffolding so that completed Cortex slugs can be archived to a cold path (`docs/cortex/archive/{slug}/`), their close recorded in `decisions.md`, and the active surface reset to "not started" — giving every slug a complete, auditable lifecycle from clarify to archive.

---

## Deliverables

- `skills/cortex-close/SKILL.md` — the `/cortex-close` command implementing the full archive lifecycle
- `docs/cortex/archive/.gitkeep` — scaffolds the cold path directory in git
- `scripts/cortex/scaffold_runtime.sh` — patched to include `archive` in `DOCS_SUBDIRS`
- `templates/cortex/decisions.md` — patched to include `## Archive Index` section
- `docs/cortex/handoffs/decisions.md` — live file updated to include `## Archive Index` section

---

## Requirements

- None formalized

---

## Tasks

- [ ] Create `docs/cortex/archive/.gitkeep` to track the cold path directory in git
- [ ] Add `archive` to `DOCS_SUBDIRS` array in `scripts/cortex/scaffold_runtime.sh`
- [ ] Add `## Archive Index` section to `templates/cortex/decisions.md` with entry format: `- {ISO8601} | {slug} | closed | contract: {path} | eval-plan: {path}`
- [ ] Add `## Archive Index` section to live `docs/cortex/handoffs/decisions.md` (align with updated template)
- [ ] Write `skills/cortex-close/SKILL.md` with the following lifecycle:
  1. Read `.cortex/state.json` — get slug, active_contract, artifacts[], eval-plan path
  2. Prompt user to type the slug name to confirm (block if input does not match)
  3. Warn (do not block) if no eval-plan exists for the slug
  4. Copy all `artifacts[]` paths to `docs/cortex/archive/{slug}/` preserving subdirectory structure
  5. Append timestamped entry to `docs/cortex/handoffs/decisions.md` (slug, timestamp, contract path, eval-plan path)
  6. Reset `docs/cortex/handoffs/current-state.md` to "not started" state
  7. Update `.cortex/state.json`: mode=done, slug=null, active_contract=null, gates reset to all-false

---

## Acceptance Criteria

- [ ] `skills/cortex-close/SKILL.md` exists and is non-empty
- [ ] `scripts/cortex/scaffold_runtime.sh` `DOCS_SUBDIRS` array includes `archive`
- [ ] `templates/cortex/decisions.md` contains an `## Archive Index` section with documented entry format
- [ ] `docs/cortex/archive/` exists on disk (`.gitkeep` or content present)
- [ ] `/cortex-close` invocation requires the user to type the slug name before proceeding (slug confirmation gate documented in SKILL.md)
- [ ] `/cortex-close` copies all `artifacts[]` paths from `state.json` to `docs/cortex/archive/{slug}/` preserving the source subdirectory structure
- [ ] `/cortex-close` appends a timestamped entry to `docs/cortex/handoffs/decisions.md` containing: slug, close timestamp, active contract path, eval-plan path
- [ ] `/cortex-close` updates `state.json` to: `mode = done`, `slug = null`, `active_contract = null`, gates reset
- [ ] `/cortex-close` resets `docs/cortex/handoffs/current-state.md` to "not started" state
- [ ] If the active slug has no eval-plan at close time, `/cortex-close` emits a WARNING but does not block
- [ ] Running `/cortex-status` after a successful `/cortex-close` returns a clean "not started" state

---

## Contract Link

docs/cortex/contracts/memory-bank-archive/contract-001.md
