# Contract: readme-upgrade — execute

**ID:** readme-upgrade-001
**Slug:** readme-upgrade
**Phase:** execute
**Created:** 20260408T162517Z
**Status:** draft
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Update README.md so that it accurately represents Cortex's current 16-command surface, autonomy system, agents, intelligence features, and repo structure.

---

## Deliverables

- `README.md` — updated root-level README with all content gaps filled

---

## Scope

### In Scope

- Command table: add 2 missing commands, verify all 16 descriptions
- New subsections: Autonomy System, Agents, Intelligence Features
- Structure tree: update to match actual repo layout
- Line count: keep under 250

### Out of Scope

- Internal docs (CORTEX.md, COMMANDS.md, etc.)
- Tutorials or walkthrough examples
- DOWNSTREAM.md or other secondary docs
- Exhaustive hook/gate/agent documentation

---

## Write Roots

- `README.md`

---

## Done Criteria

- [ ] Command table lists exactly 16 commands matching skills/cortex-*/SKILL.md
- [ ] Every file/directory in the structure tree exists in the repo
- [ ] README total line count <= 250
- [ ] Autonomy system, agents, and intelligence features each have a subsection
- [ ] No README claims contradicted by actual repo state
- [ ] Section order preserved: problem, solution, quick start, structure, upstream, architecture reference

---

## Validators

- [ ] [external] `grep -c "| \`/cortex-" README.md` returns 16
- [ ] [external] Line count check: `wc -l README.md` returns <= 250
- [ ] [external] Structure tree file existence: extract all paths from the tree and verify each exists
- [ ] [external] Section order check: grep for section headers and verify ordering
- [ ] [judgment] New subsections (autonomy, agents, intelligence features) are concise, accurate, and point to docs/

---

## Eval Plan

docs/cortex/evals/readme-upgrade/eval-plan.md (pending)

---

## Approvals

- [ ] Contract approval
- [ ] Evals approval

---

## Completion Promise

<!-- CORTEX_PROMISE: readme-upgrade-001 COMPLETE -->

---

## Failed Approaches

<!-- None — initial contract -->

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Restore README.md from git: `git checkout HEAD -- README.md`

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
