# GSD Handoff: readme-upgrade

**Slug:** readme-upgrade
**Timestamp:** 20260408T162517Z
**Status:** draft

---

## Objective

Update the Cortex README to accurately represent all 16 commands, the autonomy system, 4 specialized agents, intelligence features, and current repo structure — keeping it under 250 lines as a concise entry point.

---

## Deliverables

- Updated `README.md` at repo root with all content gaps filled

---

## Requirements

- None formalized

---

## Tasks

- [ ] Add `/cortex-intent` and `/cortex-ship` rows to command table
- [ ] Review and update all existing command descriptions for accuracy
- [ ] Add "Autonomy System" subsection under The Solution
- [ ] Add "Agents" subsection under The Solution
- [ ] Add "Intelligence Features" list under The Solution
- [ ] Update structure tree to match actual repo layout
- [ ] Verify line count <= 250 and run all validators

---

## Acceptance Criteria

- [ ] Command table lists exactly 16 commands, matching all 16 SKILL.md files in skills/cortex-*/
- [ ] Every file/directory referenced in the structure tree exists in the repo
- [ ] README total line count is <= 250
- [ ] Autonomy system, agents, and intelligence features each have a dedicated subsection
- [ ] No claims in the README are contradicted by actual repo state
- [ ] README retains the existing section order: problem, solution, quick start, structure, upstream, architecture reference

---

## Contract Link

docs/cortex/contracts/readme-upgrade/contract-001.md
