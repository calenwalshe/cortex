# GSD Handoff: research-depth-routing

**Slug:** research-depth-routing
**Timestamp:** 20260410T001500Z
**Status:** draft

---

## Objective

Refactor `/cortex-research` from a depth→provider mapping (which produces shotgun 15-20 query runs of uneven quality) to a question-type classification at clarify time plus type-driven provider routing at research time, with depth controlling per-question budget. Add an optional `--agentic` flag for iterative ReAct-style research loops using Generator/Digester/Evaluator personas for complex exploratory work.

---

## Deliverables

- Modified template: `templates/cortex/clarify-brief.md` — adds YAML frontmatter `questions:` array schema
- Modified template: `templates/cortex/research-dossier.md` — adds `## Question Coverage` section
- Modified skill: `.claude/skills/cortex-clarify/SKILL.md` — Phase 3 classifies open questions
- Modified skill: `.claude/skills/cortex-research/SKILL.md` — new type routing table, budget matrix, source authority ranking, backward compat, `--agentic` flag + ReAct loop + ResearchState persistence
- Modified skill: `.claude/skills/cortex-close/SKILL.md` — archives research-state files on slug close
- New directory: `.cortex/research-state/` with `archive/` subdirectory for agentic state

---

## Requirements

- None formalized

---

## Tasks

- [ ] Add YAML frontmatter block with `questions:` array to `templates/cortex/clarify-brief.md`
- [ ] Update `.claude/skills/cortex-clarify/SKILL.md` Phase 3 to populate classifications using the 5-type taxonomy (factual, landscape, mechanism, comparison, codebase)
- [ ] Add `## Question Coverage` section to `templates/cortex/research-dossier.md` with per-question status and provider columns
- [ ] Replace `cortex-research` Phase 1 depth table with type routing table containing explicit `search()` calls per type
- [ ] Add `cortex-research` Phase 1.5 budget matrix (depth × type → concrete numbers)
- [ ] Reorganize `cortex-research` Phase 2 execution paths per type
- [ ] Add `cortex-research` Phase 2.5 source authority ranking before Jina reads
- [ ] Add backward compatibility for existing clarify briefs without frontmatter
- [ ] Add `--agentic` flag to `cortex-research` argument parser with `--depth quick` incompatibility check
- [ ] Add agentic execution path with Generator/Digester/Evaluator personas and ReAct loop
- [ ] Add hard circuit breakers per depth (max_iterations, max_cost_usd, max_wall_time_s)
- [ ] Add ResearchState JSON persistence with atomic writes and archive-on-synthesis
- [ ] Log actually-used provider in dossier source list for fallback chain visibility
- [ ] Update `cortex-close` Phase 4 to archive research-state files
- [ ] Run end-to-end test: classify → route → synthesize with coverage table

---

## Acceptance Criteria

- [ ] clarify-brief template has YAML frontmatter with `questions:` array schema
- [ ] cortex-clarify classifies open questions into one of 5 types (factual/landscape/mechanism/comparison/codebase)
- [ ] research-dossier template has `## Question Coverage` section
- [ ] cortex-research Phase 1 has type routing table with explicit `search()` calls
- [ ] cortex-research Phase 1.5 has budget matrix where depth controls per-question budget
- [ ] cortex-research Phase 2 reorganized with execution paths per type
- [ ] cortex-research Phase 2.5 has source authority ranking with domain tiers
- [ ] cortex-research accepts `--agentic` and rejects `--agentic --depth quick` with an explicit error
- [ ] cortex-research has three distinct LLM persona prompts (Generator, Digester, Evaluator)
- [ ] Agentic path has hard limit circuit breakers defined per depth
- [ ] Agentic path uses atomic write pattern for ResearchState
- [ ] Agentic path archives (not deletes) ResearchState on synthesis
- [ ] Backward compatibility for briefs without frontmatter (inline classification + deprecation note)
- [ ] cortex-close Phase 4 archives research-state files alongside other slug artifacts
- [ ] End-to-end test produces dossier with populated Question Coverage table
- [ ] Test run total cost under $0.15 for standard-depth 5-question research

---

## Contract Link

docs/cortex/contracts/research-depth-routing/contract-001.md
