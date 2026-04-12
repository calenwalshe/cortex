# Spec: readme-upgrade

**Slug:** readme-upgrade
**Timestamp:** 20260408T162517Z
**Status:** draft

---

## 1. Problem

The published Cortex README has 11 factual gaps where the system has outgrown the documentation. The command table lists 14 of 16 commands (missing `/cortex-intent` and `/cortex-ship`), the structure tree is stale (missing 7+ entries), and major subsystems — autonomy (13 gates), agents (4 specialized), hooks (20 scripts), knowledge engine, owner intent, experiment mode — have zero representation. New users and evaluators see a README that materially understates what the system does.

---

## 2. Scope

### In Scope

- Update the command table to list all 16 commands with accurate descriptions
- Add concise subsections for autonomy system, agents, and hooks under "The Solution"
- Add a compact "Intelligence Features" list covering adjacent discovery, knowledge engine, repair loops, complexity tiers
- Update the structure tree to reflect actual repo layout
- Keep total README under 250 lines

### Out of Scope

- Rewriting internal docs (CORTEX.md, COMMANDS.md, CONTINUITY.md, EVALS.md)
- Adding tutorials, walkthrough examples, or getting-started guides
- Updating DOWNSTREAM.md or other secondary docs
- Exhaustive documentation of every hook, gate, or agent — README summarizes, docs/ has details
- Changing the README's fundamental narrative structure (problem/solution/quick-start/structure/upstream)

---

## 3. Architecture Decision

**Chosen approach:** In-place content refresh within existing section structure, plus 3 new compact subsections under "The Solution" (Autonomy, Agents, Intelligence Features).

**Rationale:** The existing structure is sound and familiar to anyone who's already read it. Adding subsections is lower-risk than restructuring. Each new subsection is 5-10 lines with a doc pointer — keeps the README an entry point, not a manual.

### Alternatives Considered
- **Full restructure with new section hierarchy:** Rejected — unnecessary churn, existing structure works
- **Split into README + FEATURES.md:** Rejected — splits the entry point, new users would miss features
- **Minimal update (just fix command table):** Rejected — leaves major subsystems invisible

---

## 4. Interfaces

- **README.md** (root of repo) — the only file this spec writes. Cortex owns it.
- **command-registry.json** — read-only reference for command names, syntax, and descriptions
- **skills/cortex-*/SKILL.md** — read-only reference to verify command existence
- **.claude/agents/*.md** — read-only reference for agent roster
- **.claude/hooks/** — read-only reference for hook count and categories
- **docs/*.md** — read-only reference for doc pointers in the structure tree

---

## 5. Dependencies

- No library or service dependencies — this is a pure documentation edit
- Depends on the current repo state being accurate (all skills, agents, hooks present as verified in research)

---

## 6. Risks

- **README grows too long and becomes a manual** — Mitigation: hard cap at 250 lines; each new subsection max 10 lines with doc pointers
- **Structure tree becomes stale again after next feature** — Mitigation: auto-doc-sync hook already monitors drift; structure tree includes comment noting it's generated from repo state
- **Command descriptions drift from SKILL.md** — Mitigation: descriptions are kept to one-line summaries; COMMANDS.md is the authoritative reference

---

## 7. Sequencing

1. Update command table: add `/cortex-intent` and `/cortex-ship` rows, verify all 16 descriptions match current SKILL.md
2. Add "Autonomy System" subsection under The Solution (~8 lines)
3. Add "Agents" subsection under The Solution (~5 lines)
4. Add "Intelligence Features" compact list under The Solution (~10 lines covering adjacent discovery, knowledge engine, repair loops, complexity tiers, experiment mode)
5. Update structure tree to match actual repo layout
6. Verify line count is under 250
7. Run validators (command count check, structure tree file existence check)

---

## 8. Tasks

- [ ] Add `/cortex-intent` row to command table
- [ ] Add `/cortex-ship` row to command table
- [ ] Review and update all 14 existing command descriptions for accuracy
- [ ] Add "Autonomy System" subsection (3 presets, gate concept, dry-run, pointer to docs/)
- [ ] Add "Agents" subsection (4 agents, role-based scopes, pointer to AGENTS.md)
- [ ] Add "Intelligence Features" list (adjacent discovery, knowledge engine, repair loops, complexity tiers, hooks)
- [ ] Update structure tree: add missing docs (DISCOVERY_LOOP.md, HOOKS.md), expand skills list, add command-registry.json, add config/
- [ ] Update hooks description in structure tree from "3 categories" to accurate count/categories
- [ ] Verify total line count <= 250
- [ ] Run all validators

---

## 9. Acceptance Criteria

- [ ] Command table lists exactly 16 commands, matching all 16 SKILL.md files in skills/cortex-*/
- [ ] Every file/directory referenced in the structure tree exists in the repo
- [ ] README total line count is <= 250
- [ ] Autonomy system, agents, and intelligence features each have a dedicated subsection
- [ ] No claims in the README are contradicted by actual repo state
- [ ] README retains the existing section order: problem, solution, quick start, structure, upstream, architecture reference
