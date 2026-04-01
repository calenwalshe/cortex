# Spec: cortex-documentation-audit

<!-- ART-03: Spec Template — produced by /cortex-spec -->

**Slug:** cortex-documentation-audit
**Timestamp:** 20260401T192000Z
**Status:** approved

---

## 1. Problem

Cortex's documentation has gaps and stale references that force operators to read SKILL.md source files to understand command behavior. The 12 installed hooks have zero dedicated documentation. CORTEX.md counts 7 commands when there are 8, CONTINUITY.md omits 3 production state.json fields, and EVALS.md omits the `--write-plan` invocation flag. COMMANDS.md has no per-command state effects or block conditions — a reader cannot tell which state.json fields each command reads or writes, or what causes a command to refuse to run. The result: any operator setting up or extending Cortex cannot rely on the docs alone and must audit source files to understand the system they are operating.

---

## 2. Scope

### In Scope

- Patch CORTEX.md: fix "7 commands" → "8 commands" (2 locations), add DISCOVERY_LOOP.md to docs/ file structure
- Update `docs/CONTINUITY.md`: add `reclarify_required`, `experiment_complete`, and `eval_complete` to the state.json schema table and example JSON block
- Update `docs/EVALS.md`: add `--write-plan` row to the invocation table
- Update `docs/AGENTS.md`: document `--team` flag composition (which agents, what each does, how they coordinate); note which hooks trigger cortex-scribe
- Update `docs/COMMANDS.md`: add State Effects row and Block Conditions row to each of the 8 command entries
- Write `docs/HOOKS.md` from scratch: full reference for all 12 hooks (trigger event, conditions, inputs, outputs, side effects, async/sync, state.json interaction)

### Out of Scope

- Rewriting or refactoring any skill implementation (SKILL.md or hook scripts)
- External documentation site or web publishing
- GSD internals documentation
- Auto-generating docs from code
- User-facing tutorials for end-users of projects that use Cortex
- Deciding whether cortex-stash and cortex-close belong in the documented surface (deferred — separate design decision required)
- Installation / quick-start guide (deferred — README audit needed first)
- Any writes to `skills/` directories or hook script files

---

## 3. Architecture Decision

**Chosen approach:** Minimal additive patches to existing documentation files, plus one new `docs/HOOKS.md`. Each existing file is patched in-place; no restructuring, no file splitting.

**Rationale:** COMMANDS.md is already the right length and well-organized — adding depth inline is less disruptive than restructuring. The hook documentation gap is large enough to warrant its own file rather than appending to CONTINUITY.md. Keeping all other changes additive (new rows, new sections) minimizes risk of introducing new inaccuracies while fixing existing ones.

### Alternatives Considered

- **Per-command reference pages (replace COMMANDS.md with individual files):** Rejected — COMMANDS.md is already well-organized and right-sized. Splitting would break existing internal references without adding operator value.
- **Full surface expansion (add cortex-stash and cortex-close to COMMANDS.md):** Deferred — adding them conflates two categories (intelligence spine vs. lifecycle utilities). A surface definition decision must happen first.
- **Single consolidated state-effects reference section at the bottom of COMMANDS.md:** Rejected — inline rows per command keep state effects co-located with the command they describe, reducing the chance a reader misses them.

---

## 4. Interfaces

- **`CORTEX.md`** — master reference, owned by Cortex repo. This spec **writes** 3 targeted patches (command count, COMMANDS.md description, DISCOVERY_LOOP.md entry).
- **`docs/COMMANDS.md`** — 8-command IO reference, owned by Cortex repo. This spec **writes** State Effects and Block Conditions rows into each of the 8 command entries.
- **`docs/CONTINUITY.md`** — continuity strategy reference, owned by Cortex repo. This spec **writes** 3 new field descriptions to the state.json schema section.
- **`docs/EVALS.md`** — eval lifecycle reference, owned by Cortex repo. This spec **writes** one new row to the invocation table.
- **`docs/AGENTS.md`** — agent roster reference, owned by Cortex repo. This spec **writes** a `--team` composition section and scribe-trigger hook list.
- **`docs/HOOKS.md`** — new file, owned by Cortex repo. This spec **creates** the full 12-hook reference.
- **`~/.claude/hooks/cortex-*.sh`** (12 scripts) — hook implementations. This spec **reads only** as the authoritative source of truth for hook behavior.
- **`.cortex/state.json`** — production state schema. This spec **reads only** as the source of truth for field names and types.
- **`skills/*/SKILL.md`** (8 command skills) — skill implementations. This spec **reads only** as the authoritative source of truth for state effects and block conditions.

---

## 5. Dependencies

- **SKILL.md files for 8 commands** (`skills/cortex-clarify/`, `skills/cortex-research/`, `skills/cortex-spec/`, `skills/cortex-experiment/`, `skills/cortex-investigate/`, `skills/cortex-review/`, `skills/cortex-audit/`, `skills/cortex-status/`) — read to extract state effects and block conditions before documenting them
- **`~/.claude/hooks/cortex-*.sh`** (12 scripts) — read to extract trigger events, conditions, inputs, outputs, and side effects for HOOKS.md
- **`.cortex/state.json`** — read to verify field names, types, and current production schema
- **Research dossier** `docs/cortex/research/cortex-documentation-audit/concept-20260401T191500Z.md` — already audited all doc files; hook enumeration and gap analysis sourced from this artifact

---

## 6. Risks

- **Documented behavior contradicts actual skill behavior** — Mitigation: read each SKILL.md in full before writing state effects and block conditions; do not infer from memory — only write what the source file confirms
- **HOOKS.md becomes stale as hooks evolve** — Mitigation: add a "Last audited: {date}" header to HOOKS.md and a maintenance note instructing authors to update it when hook scripts change
- **Scope creep into stash/close surface decision** — Mitigation: this spec explicitly defers that decision; any executor must treat cortex-stash and cortex-close as out of scope and add a note directing readers to their SKILL.md files rather than adding full entries
- **Missing hook scripts at audit time** — Mitigation: enumerate `~/.claude/hooks/cortex-*.sh` freshly at execution time; do not rely on the research dossier's count of 12 as final

---

## 7. Sequencing

1. Read `.cortex/state.json` to confirm current field names → verify schema against research findings before writing
2. Patch CORTEX.md (3 targeted changes) → checkpoint: `grep "8 commands" CORTEX.md` returns matches in both locations
3. Update `docs/CONTINUITY.md` state.json schema → checkpoint: schema table and example JSON both include `reclarify_required`, `experiment_complete`, `eval_complete`
4. Update `docs/EVALS.md` invocation table → checkpoint: `--write-plan` row present in table
5. Update `docs/AGENTS.md` → checkpoint: `--team` composition section present; cortex-scribe trigger hooks listed
6. Read all 8 SKILL.md files → extract state effects and block conditions → add rows to each command entry in COMMANDS.md → checkpoint: each of the 8 entries has State Effects and Block Conditions rows
7. Enumerate and read all 12 hook scripts → write `docs/HOOKS.md` → checkpoint: file exists and all 12 hooks have entries
8. Self-review: verify each acceptance criterion passes before committing

---

## 8. Tasks

- [ ] Read `.cortex/state.json` to confirm field names (`reclarify_required`, `experiment_complete`, `eval_complete`) exist in production
- [ ] Patch CORTEX.md: change "7 commands" → "8 commands" in intro paragraph
- [ ] Patch CORTEX.md: update `COMMANDS.md` description in file structure from "7-command reference" → "8-command reference"
- [ ] Patch CORTEX.md: add `DISCOVERY_LOOP.md` entry to the `docs/` section of the file structure
- [ ] Update `docs/CONTINUITY.md`: add `reclarify_required`, `experiment_complete`, and `eval_complete` to the state.json schema table
- [ ] Update `docs/CONTINUITY.md`: add the 3 new fields to the example JSON block
- [ ] Update `docs/EVALS.md`: add `--write-plan` row to the invocation table (mechanism: `/cortex-research --write-plan`)
- [ ] Read `skills/cortex-clarify/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-clarify` entry in COMMANDS.md
- [ ] Read `skills/cortex-research/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-research` entry in COMMANDS.md
- [ ] Read `skills/cortex-spec/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-spec` entry in COMMANDS.md
- [ ] Read `skills/cortex-experiment/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-experiment` entry in COMMANDS.md
- [ ] Read `skills/cortex-investigate/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-investigate` entry in COMMANDS.md
- [ ] Read `skills/cortex-review/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-review` entry in COMMANDS.md
- [ ] Read `skills/cortex-audit/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-audit` entry in COMMANDS.md
- [ ] Read `skills/cortex-status/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-status` entry in COMMANDS.md
- [ ] Update `docs/AGENTS.md`: add `--team` flag composition section (agents invoked, what each does, how they coordinate)
- [ ] Update `docs/AGENTS.md`: add list of hooks that trigger cortex-scribe to its invocation section
- [ ] Enumerate `~/.claude/hooks/cortex-*.sh` to confirm the full hook set (do not assume 12)
- [ ] Read all hook scripts in full; write `docs/HOOKS.md` covering all hooks with: trigger event, conditions, inputs, outputs (files written), side effects, async/sync, state.json interaction
- [ ] Add "Last audited: 2026-04-01" header and maintenance note to `docs/HOOKS.md`
- [ ] Self-review all changes against acceptance criteria before committing

---

## 9. Acceptance Criteria

- [ ] CORTEX.md contains "8 commands" in the intro paragraph (not "7 commands")
- [ ] CORTEX.md `docs/` file structure section description of COMMANDS.md reads "8-command reference"
- [ ] CORTEX.md `docs/` file structure section lists `DISCOVERY_LOOP.md`
- [ ] `docs/CONTINUITY.md` state.json schema table includes `reclarify_required`, `experiment_complete`, and `eval_complete` with type and description
- [ ] `docs/CONTINUITY.md` example JSON block includes all three new fields
- [ ] `docs/EVALS.md` invocation table includes a row for `--write-plan` identifying `/cortex-research --write-plan` as the mechanism
- [ ] `docs/AGENTS.md` documents `--team` flag composition: which agents are invoked, what each does, and how they coordinate
- [ ] `docs/AGENTS.md` cortex-scribe invocation section lists which hooks trigger it
- [ ] `docs/COMMANDS.md` includes a State Effects row for each of the 8 command entries
- [ ] `docs/COMMANDS.md` includes a Block Conditions row for each of the 8 command entries
- [ ] `docs/HOOKS.md` exists and includes an entry for each of the 12 installed hooks
- [ ] Each HOOKS.md entry documents: trigger event, conditions, inputs, outputs (files written), side effects, async/sync flag, state.json interaction
- [ ] No statement in the updated docs contradicts the corresponding SKILL.md or hook script source of truth
