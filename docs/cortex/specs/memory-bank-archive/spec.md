# Spec: memory-bank-archive

<!-- ART-03: Spec Template — produced by /cortex-spec -->

**Slug:** memory-bank-archive
**Timestamp:** 20260331T001500Z
**Status:** approved

---

## 1. Problem

The Cortex system has no terminal lifecycle state. After a slug moves through clarify → research → spec → execute, there is no `done` mode, no mechanism to move completed artifacts to a cold path, and no way to clear the active surface so `/cortex-status` shows a clean slate for the next slug. Every slug accumulates indefinitely in the same live directories — making it impossible to distinguish work-in-progress from completed, archived work without reading every artifact. This blocks starting new slugs with confidence and makes the handoff surface noisy.

---

## 2. Scope

### In Scope

- A new `skills/cortex-close/SKILL.md` implementing the `/cortex-close` command
- Adding `archive` to `DOCS_SUBDIRS` in `scripts/cortex/scaffold_runtime.sh` so new installs scaffold the directory
- Adding an `## Archive Index` section to `templates/cortex/decisions.md` with a per-entry format
- Creating `docs/cortex/archive/` on disk (with `.gitkeep` so it is tracked)
- The `/cortex-close` command must: (1) require slug confirmation, (2) copy all `artifacts[]` paths to `docs/cortex/archive/{slug}/` preserving subdirectory structure, (3) append a timestamped entry to `decisions.md`, (4) update `state.json` (mode=done, slug=null, active_contract=null, gates reset), (5) reset `current-state.md` to "not started" state

### Out of Scope

- Moving (rather than copying) artifacts — archive is copy-only; source paths remain intact
- Automatic archive triggered by contract close — archive is always an explicit human action
- Modifying `.planning/STATE.md` or any GSD phase state
- Deleting or rotating source artifacts after archiving
- Archiving partial slugs (slug must be done before archive)
- A `/cortex-unarchive` command — archive is one-way; git history is the recovery path
- Changes to existing hooks (`cortex-phase-guard.sh`, `cortex-session-end.sh`, `cortex-precompact.sh`, `cortex-postcompact.sh`) — all confirmed mode-agnostic and require no changes

---

## 3. Architecture Decision

**Chosen approach:** New `/cortex-close` SKILL.md that sets `mode = done`, copies artifacts, writes to `decisions.md`, then resets state last.

**Rationale:** Archive is a consequential, one-way action — a named command makes intent explicit and auditable. Consistent with how `/cortex-clarify`, `/cortex-spec`, etc. are each separate skills. Writing the archive copy first (before updating `state.json`) ensures that a mid-run failure leaves artifacts safely copied even if state is stale. The phase-guard's `*) exit 0` fallthrough means `done` mode is already permitted for writes to `docs/cortex/` without any guard changes.

### Alternatives Considered

- **`--archive` flag on `/cortex-status`:** Rejected — `cortex-status` has a documented non-destructive guarantee; adding a one-way destructive action violates that contract and makes the flag invisible in the skill surface overview.
- **Human sets `mode = done` before invoking `/cortex-close`:** Rejected — two-step ceremony with no guard preventing `/cortex-close` being called in the wrong mode. The close command should own the mode transition as its first atomic action.
- **Flat archive per slug (`archive/{slug}/` with all files directly):** Rejected — loses subdirectory context; mirrored structure is marginally more complex but keeps clarify briefs, specs, and contracts distinguishable at a glance.

---

## 4. Interfaces

- **`skills/cortex-close/SKILL.md`** — new file; owned by this spec; written by this spec's implementation tasks
- **`scripts/cortex/scaffold_runtime.sh`** — existing script; owned by Cortex framework; patched (add `archive` to `DOCS_SUBDIRS` array)
- **`templates/cortex/decisions.md`** — existing template; owned by Cortex framework; patched (add `## Archive Index` section)
- **`docs/cortex/handoffs/decisions.md`** — live decisions file; append-only; written by `/cortex-close` at close time
- **`.cortex/state.json`** — runtime state; read by `/cortex-close` for `artifacts[]`, `slug`, `active_contract`; written at close time (mode, slug, active_contract, gates reset)
- **`docs/cortex/handoffs/current-state.md`** — active surface; written by `/cortex-close` to "not started" state
- **`docs/cortex/archive/{slug}/`** — cold path; created by `/cortex-close`; artifact copies land here preserving subdirectory structure

---

## 5. Dependencies

- **`.cortex/state.json` `artifacts[]` array** — canonical list of paths to copy at close time; no other artifact discovery is needed
- **`docs/cortex/handoffs/decisions.md`** — must exist before `/cortex-close` appends to it; scaffolded by `scaffold_runtime.sh`
- **`cortex-phase-guard.sh`** (`*) exit 0` fallthrough) — confirmed to permit writes during `done` mode; no changes required
- **Cortex hook infrastructure** (session-end, precompact, postcompact) — all confirmed mode-agnostic; no changes required

---

## 6. Risks

- **Partial archive if `/cortex-close` fails mid-run** — Mitigation: copy archive artifacts first, update `state.json` and `current-state.md` last; a failed run leaves artifacts safely copied and state still pointing at the slug, so re-running is safe.
- **`decisions.md` append corrupts existing content** — Mitigation: `/cortex-close` appends only to the `## Archive Index` section; it reads the file, appends a formatted entry, and rewrites — never truncates. Initial archive index section is scaffolded by the template update.
- **`docs/cortex/archive/` not gitignored causes repo bloat from duplicate artifact blobs** — Mitigation: document that `docs/cortex/archive/` is intentionally tracked in git (archives are small markdown files); evaluate gitignore policy after first real use.
- **User invokes `/cortex-close` on a slug with outstanding done_criteria** — Mitigation: `/cortex-close` requires user to type the slug name as confirmation; the skill prompt warns if done_criteria are unchecked but does not block (user override is explicit).

---

## 7. Sequencing

1. Create `docs/cortex/archive/` with `.gitkeep` — confirms the cold path exists on disk before any close operation can reference it.
2. Patch `scripts/cortex/scaffold_runtime.sh` to add `archive` to `DOCS_SUBDIRS` — ensures new installs get the directory automatically.
3. Patch `templates/cortex/decisions.md` to add `## Archive Index` section with entry format — establishes the schema before any entries are written.
4. Update live `docs/cortex/handoffs/decisions.md` with the `## Archive Index` section — aligns the live file with the updated template so the first `/cortex-close` run can append cleanly.
5. Write `skills/cortex-close/SKILL.md` with full close lifecycle — the core deliverable; references the archive directory, decisions.md format, and state.json reset sequence established in steps 1–4.

---

## 8. Tasks

- [ ] Create `docs/cortex/archive/.gitkeep` to scaffold the cold path directory
- [ ] Add `archive` to `DOCS_SUBDIRS` array in `scripts/cortex/scaffold_runtime.sh`
- [ ] Add `## Archive Index` section to `templates/cortex/decisions.md` with entry format: `- {ISO8601} | {slug} | closed | contract: {path} | eval-plan: {path}`
- [ ] Add `## Archive Index` section to live `docs/cortex/handoffs/decisions.md`
- [ ] Write `skills/cortex-close/SKILL.md` implementing the full `/cortex-close` lifecycle: slug confirmation, artifact copy (preserving subdirectory structure), decisions.md append, state.json reset, current-state.md reset

---

## 9. Acceptance Criteria

- [ ] `skills/cortex-close/SKILL.md` exists and is non-empty
- [ ] `scripts/cortex/scaffold_runtime.sh` `DOCS_SUBDIRS` array includes `archive`
- [ ] `templates/cortex/decisions.md` contains an `## Archive Index` section with documented entry format
- [ ] `docs/cortex/archive/` exists on disk (`.gitkeep` or content present)
- [ ] `/cortex-close` invocation requires the user to type the slug name before proceeding (slug confirmation gate documented in SKILL.md)
- [ ] `/cortex-close` copies all `artifacts[]` paths from `state.json` to `docs/cortex/archive/{slug}/` preserving the source subdirectory structure (e.g., a clarify brief at `docs/cortex/clarify/{slug}/foo.md` lands at `docs/cortex/archive/{slug}/clarify/{slug}/foo.md` — or the appropriate mirrored path)
- [ ] `/cortex-close` appends a timestamped entry to `docs/cortex/handoffs/decisions.md` containing: slug, close timestamp, active contract path, eval-plan path
- [ ] `/cortex-close` updates `state.json` to: `mode = done`, `slug = null`, `active_contract = null`, gates reset
- [ ] `/cortex-close` resets `docs/cortex/handoffs/current-state.md` to "not started" state (matching the template initial state)
- [ ] If the active slug has no eval-plan at close time, `/cortex-close` emits a WARNING but does not block
- [ ] Running `/cortex-status` after a successful `/cortex-close` returns a clean "not started" state
