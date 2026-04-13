# Contract: research-depth-routing — execute

**ID:** research-depth-routing-001
**Slug:** research-depth-routing
**Phase:** execute
**Created:** 20260410T001500Z
**Status:** draft
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Refactor `/cortex-research` to use question-type classification at clarify time + type-driven provider routing at research time, with depth controlling per-question budget. Add optional `--agentic` flag for iterative ReAct research loops with Generator/Digester/Evaluator personas.

---

## Deliverables

- `templates/cortex/clarify-brief.md` — modified with YAML frontmatter `questions:` schema
- `templates/cortex/research-dossier.md` — modified with `## Question Coverage` section
- `.claude/skills/cortex-clarify/SKILL.md` — modified Phase 3 to populate classifications
- `.claude/skills/cortex-research/SKILL.md` — refactored routing, budget matrix, source authority, `--agentic` path, ResearchState persistence
- `.claude/skills/cortex-close/SKILL.md` — modified Phase 4 to archive research-state
- `.cortex/research-state/` — new directory with `archive/` subdirectory

---

## Scope

### In Scope

- 5-type taxonomy (factual, landscape, mechanism, comparison, codebase)
- YAML frontmatter classification in clarify brief
- Type routing table with explicit `power_search` calls per type
- Budget matrix (depth × type → concrete numbers)
- Source authority ranking (high/medium/low domain tiers)
- `--agentic` flag with ReAct loop (Generator/Digester/Evaluator personas)
- ResearchState JSON persistence with atomic writes and archive-on-synthesis
- Hard circuit breakers (max_iterations, max_cost_usd, max_wall_time_s)
- Backward compatibility for briefs without frontmatter
- `/cortex-close` archive cleanup
- Trust existing `power_search` fallback chains

### Out of Scope

- New search providers
- Changes to dossier synthesis logic (Findings/Recommendations/Open Questions)
- Modifying adjacent discovery pipeline
- Parallel multi-agent agentic execution
- `--agentic` at `--depth quick` (incompatible by design)
- Changing `Complexity:` field semantics

---

## Write Roots

- `templates/cortex/clarify-brief.md`
- `templates/cortex/research-dossier.md`
- `.claude/skills/cortex-research/SKILL.md`
- `.claude/skills/cortex-clarify/SKILL.md`
- `.claude/skills/cortex-close/SKILL.md`
- `.cortex/research-state/`
- `docs/cortex/specs/research-depth-routing/`
- `docs/cortex/contracts/research-depth-routing/`
- `docs/cortex/research/research-depth-routing/`

---

## Done Criteria

- [ ] `templates/cortex/clarify-brief.md` contains a YAML frontmatter block with `questions:` array schema and inline documentation of the 5-type taxonomy
- [ ] `cortex-clarify` Phase 3 instructions include classifying open questions into one of: factual, landscape, mechanism, comparison, codebase
- [ ] `templates/cortex/research-dossier.md` contains `## Question Coverage` section with per-question status and provider columns
- [ ] `cortex-research` Phase 1 contains a type routing table with explicit `search()` calls per type
- [ ] `cortex-research` Phase 1.5 contains a budget matrix where depth controls per-question budget (not provider choice)
- [ ] `cortex-research` Phase 2 is reorganized with execution paths per type (factual/landscape/mechanism/comparison/codebase)
- [ ] `cortex-research` Phase 2.5 contains source authority ranking with high/medium/low domain tier lists
- [ ] `cortex-research` argument parser accepts `--agentic` flag and rejects `--agentic --depth quick` with explicit error
- [ ] `cortex-research` contains an agentic execution path with three distinct LLM persona prompts (Generator, Digester, Evaluator)
- [ ] `cortex-research` agentic path has hard limit circuit breakers (max_iterations, max_cost_usd, max_wall_time_s) defined per depth level
- [ ] `cortex-research` agentic path uses atomic write pattern (tmp + rename) for ResearchState persistence
- [ ] `cortex-research` agentic path archives (not deletes) ResearchState on synthesis
- [ ] `cortex-research` has backward compatibility: clarify briefs without frontmatter fall back to inline LLM classification with deprecation note
- [ ] `cortex-close` Phase 4 archives `.cortex/research-state/archive/{slug}-*.json` files alongside other slug artifacts
- [ ] End-to-end test produces a research dossier with populated Question Coverage table

---

## Validators

- [ ] [external] `grep -q 'questions:' templates/cortex/clarify-brief.md` — frontmatter schema present in template
- [ ] [external] `grep -q 'factual\|landscape\|mechanism\|comparison\|codebase' .claude/skills/cortex-clarify/SKILL.md` — classification instructions present
- [ ] [external] `grep -q 'Question Coverage' templates/cortex/research-dossier.md` — coverage section in dossier template
- [ ] [external] `grep -q 'type routing table' .claude/skills/cortex-research/SKILL.md` — Phase 1 routing table present
- [ ] [external] `grep -q 'budget matrix\|per-question budget' .claude/skills/cortex-research/SKILL.md` — budget matrix present
- [ ] [external] `grep -q 'source authority\|high.*medium.*low' .claude/skills/cortex-research/SKILL.md` — authority ranking present
- [ ] [external] `grep -q '\-\-agentic' .claude/skills/cortex-research/SKILL.md` — agentic flag documented
- [ ] [external] `grep -q 'Generator\|Digester\|Evaluator' .claude/skills/cortex-research/SKILL.md` — three personas present
- [ ] [external] `grep -q 'max_iterations\|max_cost_usd\|max_wall_time' .claude/skills/cortex-research/SKILL.md` — hard limits present
- [ ] [external] `grep -q 'atomic\|tmp.*rename\|os.rename' .claude/skills/cortex-research/SKILL.md` — atomic write pattern present
- [ ] [external] `grep -q 'research-state/archive' .claude/skills/cortex-close/SKILL.md` — close skill archives research-state
- [ ] [external] `test -d .cortex/research-state` — state directory exists (created during execution or init)
- [ ] [judgment] The type routing table has exactly 5 types with explicit `search()` call signatures per type
- [ ] [judgment] The budget matrix provides concrete numbers (not hand-wavy "more" / "less") for each depth × type cell
- [ ] [judgment] End-to-end test dossier has Question Coverage table showing status and provider actually used per question

---

## Eval Plan

docs/cortex/evals/research-depth-routing/eval-plan.md (pending)

---

## Approvals

- [ ] Contract approval
- [ ] Evals approval

---

## Completion Promise

<!-- CORTEX_PROMISE: research-depth-routing-001 COMPLETE -->

---

## Failed Approaches

<!-- N/A — initial contract -->

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Revert `templates/cortex/clarify-brief.md` (remove YAML frontmatter block)
- Revert `templates/cortex/research-dossier.md` (remove `## Question Coverage` section)
- Revert `.claude/skills/cortex-clarify/SKILL.md` (remove classification instructions)
- Revert `.claude/skills/cortex-research/SKILL.md` to pre-refactor state (restore original depth routing)
- Revert `.claude/skills/cortex-close/SKILL.md` (remove research-state archive step)
- Delete `.cortex/research-state/` directory if created
- Existing clarify briefs and research dossiers remain compatible — no data migration needed
- Git: `git diff HEAD~1 -- templates/cortex/ .claude/skills/` to see all modifications

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
