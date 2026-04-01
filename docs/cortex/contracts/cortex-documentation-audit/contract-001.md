# Contract: cortex-documentation-audit — execute

<!-- ART-05: Contract Template — produced by /cortex-spec -->
<!-- IMPORTANT: A contract without the eval_plan field is incomplete and must not advance past spec state. -->

**ID:** cortex-documentation-audit-001
**Slug:** cortex-documentation-audit
**Phase:** execute
**Created:** 20260401T192000Z
**Status:** approved

---

## Objective

Patch all known documentation gaps in the Cortex repo so that operators can understand command behavior, hook behavior, and system state without reading source files.

---

## Deliverables

- Patched file: `CORTEX.md` (3 stale-reference fixes)
- Patched file: `docs/COMMANDS.md` (State Effects + Block Conditions rows for all 8 commands)
- Patched file: `docs/CONTINUITY.md` (3 missing state.json fields in schema table and example JSON)
- Patched file: `docs/EVALS.md` (--write-plan row in invocation table)
- Patched file: `docs/AGENTS.md` (--team composition section + cortex-scribe trigger hooks)
- New file: `docs/HOOKS.md` (full reference for all 12 installed hooks)

---

## Scope

### In Scope

- Patch `CORTEX.md`: command count fix (7→8, two locations) and DISCOVERY_LOOP.md file structure entry
- Patch `docs/COMMANDS.md`: add State Effects and Block Conditions rows to each of the 8 command entries
- Patch `docs/CONTINUITY.md`: add `reclarify_required`, `experiment_complete`, `eval_complete` to state.json schema
- Patch `docs/EVALS.md`: add `--write-plan` invocation row
- Patch `docs/AGENTS.md`: add `--team` composition section; add hook trigger list to cortex-scribe entry
- Create `docs/HOOKS.md`: full 12-hook reference

### Out of Scope

- Rewriting or modifying any SKILL.md or hook script
- cortex-stash and cortex-close surface documentation (design decision deferred)
- Installation / quick-start guide
- README audit
- GSD internals documentation
- Any writes to `skills/` directories

---

## Write Roots

- `CORTEX.md`
- `docs/COMMANDS.md`
- `docs/CONTINUITY.md`
- `docs/EVALS.md`
- `docs/AGENTS.md`
- `docs/HOOKS.md`

---

## Done Criteria

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

## Validators

- [ ] `grep -c "8 commands" CORTEX.md` returns ≥ 2
- [ ] `grep "DISCOVERY_LOOP" CORTEX.md` returns a match in the docs/ file structure section
- [ ] `grep "reclarify_required" docs/CONTINUITY.md` returns matches in both schema table and example JSON
- [ ] `grep "experiment_complete" docs/CONTINUITY.md` returns matches in both schema table and example JSON
- [ ] `grep "eval_complete" docs/CONTINUITY.md` returns matches in both schema table and example JSON
- [ ] `grep "write-plan" docs/EVALS.md` returns a match
- [ ] `grep -c "State Effects" docs/COMMANDS.md` returns 8
- [ ] `grep -c "Block Conditions" docs/COMMANDS.md` returns 8
- [ ] `test -f docs/HOOKS.md && echo exists` returns "exists"
- [ ] `grep -c "^### " docs/HOOKS.md` returns ≥ 12 (one heading per hook)

---

## Eval Plan

docs/cortex/evals/cortex-documentation-audit/eval-plan.md (pending)

---

## Approvals

- [x] Contract approval
- [ ] Evals approval

---

## Rollback Hints

- `git restore CORTEX.md` — reverts CORTEX.md patches
- `git restore docs/COMMANDS.md` — reverts State Effects and Block Conditions additions
- `git restore docs/CONTINUITY.md` — reverts state.json schema additions
- `git restore docs/EVALS.md` — reverts --write-plan row addition
- `git restore docs/AGENTS.md` — reverts --team section and scribe hook list
- `git rm docs/HOOKS.md` — removes new hooks reference file
- `.cortex/state.json`: reset `mode` to `research`, `approval_status` to `pending`, `active_contract` to `null`, `gates.spec_complete` to `false`
