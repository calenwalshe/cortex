# Contract: memory-bank-archive — execute

<!-- ART-05: Contract Template — produced by /cortex-spec -->

**ID:** memory-bank-archive-001
**Slug:** memory-bank-archive
**Phase:** execute
**Created:** 20260331T001500Z
**Status:** approved

---

## Objective

Build the `/cortex-close` skill and supporting scaffolding so that completed Cortex slugs can be archived to a cold path, their close recorded in `decisions.md`, and the active surface reset to "not started".

---

## Deliverables

- Skill file: `skills/cortex-close/SKILL.md`
- Directory marker: `docs/cortex/archive/.gitkeep`
- Patch: `scripts/cortex/scaffold_runtime.sh` (add `archive` to `DOCS_SUBDIRS`)
- Patch: `templates/cortex/decisions.md` (add `## Archive Index` section)
- Patch: `docs/cortex/handoffs/decisions.md` (add `## Archive Index` section to live file)

---

## Scope

### In Scope

- `skills/cortex-close/SKILL.md` — full close lifecycle with slug confirmation, artifact copy, decisions.md append, state reset
- `docs/cortex/archive/.gitkeep` — cold path scaffolding
- `scripts/cortex/scaffold_runtime.sh` `DOCS_SUBDIRS` patch
- `templates/cortex/decisions.md` archive index section
- `docs/cortex/handoffs/decisions.md` archive index section (live file alignment)

### Out of Scope

- Changes to any existing hook (`cortex-phase-guard.sh`, `cortex-session-end.sh`, `cortex-precompact.sh`, `cortex-postcompact.sh`)
- A `/cortex-unarchive` command
- Automatic archive on contract close
- Moving artifacts (copy-only)
- Modifications to `.planning/STATE.md` or GSD state

---

## Write Roots

- `skills/cortex-close/`
- `docs/cortex/archive/`
- `docs/cortex/handoffs/decisions.md`
- `scripts/cortex/scaffold_runtime.sh`
- `templates/cortex/decisions.md`

---

## Done Criteria

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

## Validators

- [ ] `test -f skills/cortex-close/SKILL.md` — skill file exists
- [ ] `grep -q 'archive' scripts/cortex/scaffold_runtime.sh` — scaffold patched
- [ ] `grep -q 'Archive Index' templates/cortex/decisions.md` — template patched
- [ ] `test -e docs/cortex/archive/.gitkeep` — archive directory scaffolded
- [ ] Manual review of `skills/cortex-close/SKILL.md` — confirm slug confirmation gate, artifact copy logic, decisions.md append, state reset steps are all present

---

## Eval Plan

docs/cortex/evals/memory-bank-archive/eval-plan.md

---

## Approvals

- [x] Contract approval
- [x] Evals approval

---

## Rollback Hints

- Delete `skills/cortex-close/SKILL.md`
- Delete `docs/cortex/archive/.gitkeep` (and directory if empty)
- Revert `scripts/cortex/scaffold_runtime.sh` (remove `archive` from `DOCS_SUBDIRS`)
- Revert `templates/cortex/decisions.md` (remove `## Archive Index` section)
- Revert `docs/cortex/handoffs/decisions.md` (remove `## Archive Index` section)
