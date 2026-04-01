# GSD Handoff: cortex-documentation-audit

<!-- ART-04: GSD Handoff Template — produced by /cortex-spec -->
<!-- This is a GSD-ready work order. The human imports this into GSD explicitly. -->
<!-- Cortex NEVER calls GSD commands — that is always a human step. -->

**Slug:** cortex-documentation-audit
**Timestamp:** 20260401T192000Z
**Status:** draft

---

## Objective

Patch all known documentation gaps in the Cortex repo so that any operator can understand command behavior, hook behavior, and system state without reading SKILL.md or hook source files — specifically: fix 3 stale references in CORTEX.md, add State Effects and Block Conditions rows to all 8 command entries in COMMANDS.md, patch 3 missing state.json fields into CONTINUITY.md, fix a missing --write-plan row in EVALS.md, document --team composition in AGENTS.md, and create docs/HOOKS.md covering all 12 installed hooks.

---

## Deliverables

- Patched file: `CORTEX.md` (3 targeted changes)
- Patched file: `docs/COMMANDS.md` (State Effects + Block Conditions rows added to all 8 command entries)
- Patched file: `docs/CONTINUITY.md` (3 state.json fields added to schema table and example JSON)
- Patched file: `docs/EVALS.md` (--write-plan row added to invocation table)
- Patched file: `docs/AGENTS.md` (--team composition section + cortex-scribe trigger hooks)
- New file: `docs/HOOKS.md` (full 12-hook reference)

---

## Requirements

- None formalized

---

## Tasks

- [ ] Read `.cortex/state.json` to confirm field names (`reclarify_required`, `experiment_complete`, `eval_complete`) exist in production
- [ ] Patch CORTEX.md: change "7 commands" → "8 commands" in intro paragraph
- [ ] Patch CORTEX.md: update COMMANDS.md description in file structure from "7-command reference" → "8-command reference"
- [ ] Patch CORTEX.md: add `DISCOVERY_LOOP.md` entry to the `docs/` section of the file structure
- [ ] Update `docs/CONTINUITY.md`: add `reclarify_required`, `experiment_complete`, and `eval_complete` to the state.json schema table and example JSON block
- [ ] Update `docs/EVALS.md`: add `--write-plan` row to the invocation table (mechanism: `/cortex-research --write-plan`)
- [ ] Read `skills/cortex-clarify/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-clarify` entry in COMMANDS.md
- [ ] Read `skills/cortex-research/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-research` entry in COMMANDS.md
- [ ] Read `skills/cortex-spec/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-spec` entry in COMMANDS.md
- [ ] Read `skills/cortex-experiment/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-experiment` entry in COMMANDS.md
- [ ] Read `skills/cortex-investigate/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-investigate` entry in COMMANDS.md
- [ ] Read `skills/cortex-review/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-review` entry in COMMANDS.md
- [ ] Read `skills/cortex-audit/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-audit` entry in COMMANDS.md
- [ ] Read `skills/cortex-status/SKILL.md` and add State Effects + Block Conditions rows to the `/cortex-status` entry in COMMANDS.md
- [ ] Update `docs/AGENTS.md`: add `--team` flag composition section; add hook trigger list to cortex-scribe invocation section
- [ ] Enumerate `~/.claude/hooks/cortex-*.sh` to confirm complete hook set; read all hook scripts
- [ ] Write `docs/HOOKS.md` covering all hooks with: trigger event, conditions, inputs, outputs, side effects, async/sync, state.json interaction; add "Last audited: 2026-04-01" header
- [ ] Self-review all changes against acceptance criteria before committing

---

## Acceptance Criteria

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

---

## Contract Link

docs/cortex/contracts/cortex-documentation-audit/contract-001.md
