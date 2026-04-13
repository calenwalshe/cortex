# Spec: research-depth-routing

**Slug:** research-depth-routing
**Timestamp:** 20260410T001500Z
**Status:** draft

---

## 1. Problem

The current `/cortex-research` skill maps depth levels directly to providers (quick→Perplexity, standard→Tavily, deep→gpt-researcher), producing shotgun research runs where the researcher issues 15-20 searches of uneven quality instead of routing each question to its optimal tool. Users get dossiers with many low-authority sources (LinkedIn threads, Reddit comments) when high-authority sources (arXiv, official docs) would have served the same question with one Perplexity call. The classifier that should pick the right tool per question doesn't exist, there's no coverage tracking to know when to stop, and the agentic option for iterative digest-decide loops doesn't exist at all. This wastes money, wastes time, and degrades dossier quality.

---

## 2. Scope

### In Scope

- Add a `questions:` YAML frontmatter array to the clarify brief template, where each entry has `id`, `text`, and `type` (factual / landscape / mechanism / comparison / codebase)
- Modify `cortex-clarify` Phase 3 to populate the `questions:` frontmatter with LLM-classified open questions during clarification
- Replace the depth→provider mapping in `cortex-research` Phase 1 with a type→provider routing table (explicit `power_search` calls per type)
- Add a budget matrix where depth controls per-question budget (iterations, URL reads, cross-reference) instead of provider choice
- Add source authority ranking (high/medium/low domain tiers) applied before Jina URL reads
- Add `## Question Coverage` section to the research dossier template with per-question status tracking
- Add optional `--agentic` flag that runs a ReAct loop with Generator/Digester/Evaluator personas from the concept-extension dossier
- Persist `ResearchState` JSON at `.cortex/research-state/{slug}.json` during agentic runs, archive on synthesis
- Add hard circuit breakers for agentic mode (max iterations, max cost USD, max wall time seconds)
- Backward compatibility: clarify briefs without `questions:` frontmatter fall back to inline LLM classification with a deprecation note
- Update `/cortex-close` to archive `.cortex/research-state/archive/{slug}-*.json` files alongside other slug artifacts
- Trust existing `power_search` fallback chains (perplexity → gemini_grounded → gemini for RESEARCH; tavily → gemini_grounded for SEARCH) — do not reinvent error handling

### Out of Scope

- Rewriting the entire `cortex-research` skill — changes are scoped to Phase 1 (routing), Phase 2 (execution), and the argument parser
- Adding new search providers — working with existing `power_search` providers only
- Changing the dossier synthesis logic (Findings/Recommendations/Open Questions sections remain the same)
- Modifying the adjacent discovery pipeline (Outside-In, I&W, filter pipeline) — those remain untouched
- Building a search quality evaluation framework — source authority ranking is a lightweight domain heuristic, not a scored system
- Changing the `Complexity:` field semantics — complexity still drives depth override; the two fields are orthogonal
- Agentic mode at `--depth quick` (incompatible by design — too few iterations to benefit from loop structure)
- Parallel multi-agent execution in agentic mode — loop is sequential, not parallel

---

## 3. Architecture Decision

**Chosen approach:** **Question-type classification at clarify time + type-driven provider routing at research time, with depth controlling per-question budget rather than provider choice.** Classification lives in a YAML frontmatter `questions:` array. An optional `--agentic` flag adds a ReAct loop (Generator/Digester/Evaluator) on top of the classified routing for complex exploratory research. State persists at `.cortex/research-state/{slug}.json` with atomic writes and archive-on-synthesis.

**Rationale:** The current depth→provider coupling conflates two orthogonal dimensions: which tool fits the question (routing) and how hard to search (effort). Separating them lets `quick factual` and `deep factual` both use Perplexity — just with different budgets. Research shows the sweet spot is 5 question types (Bu et al. functional taxonomy, confirmed by Gemini cross-reference). YAML frontmatter is robust against typos and parseable with stdlib `yaml.safe_load`. The agentic mode is opt-in because linear classified routing is already a big improvement over the current shotgun approach, and most research sessions don't need iteration. Deferring complexity until users explicitly request it keeps the default path simple.

### Alternatives Considered

- **6-type taxonomy (factual, landscape, how-it-works, pattern, comparison, codebase):** Rejected — Gemini cross-reference showed how-it-works and pattern route to the same provider stack, so the distinction is operational noise. Merged into `mechanism`.
- **Inline `[type]` tags on each question:** Rejected — fragile parsing, typo-prone, clutters narrative. YAML frontmatter is the robust choice.
- **Default unclassified questions to `mechanism`:** Rejected — Gemini flagged this as a cost landmine (most expensive route). Default to `factual` (cheapest, ~$0.02/call) instead. If a factual call returns thin results, the researcher re-routes.
- **Delete ResearchState on synthesis:** Rejected — loses debugging trail if synthesis fails. Archive instead.
- **Implement custom fallback chains in cortex-research:** Rejected — `power_search` already has natural fallback chains (perplexity → gemini_grounded → gemini). Use them; don't reinvent.
- **Make `--agentic` the default for `--depth deep`:** Rejected — agentic has higher cost variance and complexity. Opt-in keeps the default path predictable.
- **Three-agent architecture for agentic mode (Planner + Generator + Evaluator):** Rejected — the clarify brief already serves as the plan. Adding a planner duplicates work.

---

## 4. Interfaces

- **`.claude/skills/cortex-research/SKILL.md`** — Existing skill. Modified: Phase 1 (replace depth routing table with type routing table), Phase 2 (reorganize execution by type, not depth path), argument parser (add `--agentic` flag), add new Phase 1.5 (budget allocation matrix), add new Phase 2.5 (source authority ranking before Jina reads).
- **`.claude/skills/cortex-clarify/SKILL.md`** — Existing skill. Modified: Phase 3 (populate `questions:` YAML frontmatter with classified open questions). Backward compatible — existing briefs without frontmatter still work.
- **`.claude/skills/cortex-close/SKILL.md`** — Existing skill. Modified: Phase 4 (archive `.cortex/research-state/archive/{slug}-*.json` files into `docs/cortex/archive/{slug}/research-state/`).
- **`templates/cortex/clarify-brief.md`** — Existing template. Modified: add YAML frontmatter block at top with `questions:` array schema.
- **`templates/cortex/research-dossier.md`** — Existing template. Modified: add `## Question Coverage` section after `## Findings`.
- **`.cortex/research-state/{slug}.json`** — New file. Owned by agentic mode. Written atomically by cortex-research, read by the ReAct loop, archived on synthesis.
- **`.cortex/research-state/archive/{slug}-{timestamp}.json`** — New file. Archive of completed agentic state, cleaned up by `/cortex-close`.
- **`power_search` library** — External dependency. Read-only usage of `search()`, `Intent` enum, and `usage` tracker. No modifications to power_search.
- **`docs/cortex/clarify/{slug}/*.md`** — Read by cortex-research Phase 0 to extract `questions:` frontmatter.

---

## 5. Dependencies

- **`power_search` library** — Existing, unchanged. Provides `search(query, intent, provider, ...)`, `Intent` enum, natural fallback chains, usage tracking at `~/.power-search/usage.db`. All search/extract/generate calls route through this.
- **`pyyaml` (stdlib-adjacent)** — Used for `yaml.safe_load()` when parsing the clarify brief frontmatter. Widely available in Python environments; the existing cortex-postcompact.js and cortex-health.py already assume a Python + common libs environment.
- **Claude Code skill infrastructure** — Skill files at `.claude/skills/`, argument parsing, hook integration.
- **Existing Cortex artifact conventions** — clarify briefs at `docs/cortex/clarify/{slug}/`, research dossiers at `docs/cortex/research/{slug}/`, state at `.cortex/state.json`.
- **`docs/cortex/research/research-depth-routing/concept-20260409T213000Z.md`** — concept dossier (5-type taxonomy, budget principle)
- **`docs/cortex/research/research-depth-routing/concept-extension-20260409T214500Z.md`** — agentic loop design (ReAct + personas)
- **`docs/cortex/research/research-depth-routing/implementation-20260410T000000Z.md`** — implementation details (concrete calls, state schema, budget matrix)

---

## 6. Risks

- **Question classification accuracy is the single point of failure for routing quality** — Mitigation: (a) the classifier IS the researcher, so re-classification mid-research is cheap when a call returns thin results; (b) default to `factual` (cheapest route) when in doubt; (c) unknown types are a hard error, not a silent default, so typos are caught immediately.
- **Agentic mode can have runaway cost if hard limits don't fire** — Mitigation: three independent hard limits (max_iterations, max_cost_usd, max_wall_time_s) with atomic state writes after each iteration. If any limit triggers, terminate and synthesize with partial coverage. The evaluator runs every iteration and can also terminate early on completion.
- **The generator in agentic mode will self-praise and terminate prematurely** — Mitigation: generator cannot self-terminate. The evaluator (separate LLM call with skeptical system prompt) is the only agent allowed to set `done: true`. Ralph loop guard ("are you really done?") runs before actual termination.
- **ResearchState JSON corruption during interrupted writes** — Mitigation: atomic write pattern — write to `{path}.tmp`, then `os.rename()` to final path. Rename is atomic on POSIX filesystems.
- **Backward compat for existing clarify briefs (e.g., intelligence-loop-memory) degrades quality** — Mitigation: if frontmatter is missing, fall back to inline LLM classification of the Open Questions section. Print a deprecation note recommending `/cortex-clarify` regeneration, but don't block the research run.
- **Existing `power_search` fallback chains silently route to expensive providers without visibility** — Mitigation: log the actually-used provider in the dossier's source list per call. If Perplexity failed and the chain fell through to Gemini grounded, that's visible in the sources section.
- **Source authority ranking is a domain-based heuristic that will miss legitimate non-standard sources** — Mitigation: it's a sort order, not a filter. Low-authority URLs are still read if high/medium pool is exhausted within the budget. The heuristic only prevents reading LinkedIn when arXiv exists on the same question.

---

## 7. Sequencing

1. **Update clarify brief template** (`templates/cortex/clarify-brief.md`) — add YAML frontmatter block with `questions:` array schema and inline documentation. No skill changes yet. Artifact: updated template.
2. **Update cortex-clarify skill** (`.claude/skills/cortex-clarify/SKILL.md`) — modify Phase 3 to classify open questions into the 5-type taxonomy and populate the frontmatter. Artifact: updated skill file. Checkpoint: generating a new clarify brief produces valid frontmatter.
3. **Update research dossier template** (`templates/cortex/research-dossier.md`) — add `## Question Coverage` section with the per-question status table. Artifact: updated template.
4. **Refactor cortex-research Phase 1 (routing)** (`.claude/skills/cortex-research/SKILL.md`) — replace the depth table with the type routing table, add the budget matrix. Artifact: updated skill file (routing section).
5. **Refactor cortex-research Phase 2 (execution)** — reorganize execution by type with explicit power_search calls per path. Add source authority ranking step before Jina reads. Artifact: updated skill file (execution section).
6. **Add cortex-research backward compatibility** — when clarify brief has no frontmatter, run inline LLM classification with deprecation note. Artifact: updated skill file (Phase 0 handling).
7. **Add cortex-research `--agentic` flag and ReAct loop** — argument parser addition, agentic execution path with Generator/Digester/Evaluator personas, hard limit circuit breakers. Artifact: updated skill file (new agentic path).
8. **Add ResearchState persistence** — atomic write helpers, archive-on-synthesis logic, schema v1. Artifact: state persistence pseudocode in skill + directory creation in `.cortex/research-state/`.
9. **Update cortex-close skill** (`.claude/skills/cortex-close/SKILL.md`) — add research-state archive cleanup in Phase 4. Artifact: updated skill file.
10. **End-to-end test** — run the refactored flow on a test slug: clarify with classification → research with type routing → synthesis with coverage table. Confirm token count, cost, and coverage metrics match expectations. Artifact: test run results documented in a new research dossier for this slug as empirical validation.

---

## 8. Tasks

- [ ] Modify `templates/cortex/clarify-brief.md`: add YAML frontmatter block at top with `slug`, `timestamp`, `status`, `complexity`, and `questions:` array schema
- [ ] Modify `.claude/skills/cortex-clarify/SKILL.md` Phase 3: populate `questions:` frontmatter with classified open questions using the 5-type taxonomy (factual, landscape, mechanism, comparison, codebase)
- [ ] Modify `templates/cortex/research-dossier.md`: add `## Question Coverage` section after `## Findings` with the per-question status table format
- [ ] Modify `.claude/skills/cortex-research/SKILL.md` Phase 1: replace depth routing table with type routing table containing explicit `power_search` calls per type
- [ ] Modify `.claude/skills/cortex-research/SKILL.md` Phase 1.5: add budget matrix (depth × type → concrete numbers for iterations, URL reads, cross-reference)
- [ ] Modify `.claude/skills/cortex-research/SKILL.md` Phase 2: reorganize execution by type with explicit `search()` calls for each path (factual → Perplexity, landscape → Tavily multi, mechanism → Tavily + Jina, comparison → Perplexity + Gemini, codebase → Agent Explore)
- [ ] Modify `.claude/skills/cortex-research/SKILL.md` Phase 2.5: add source authority ranking step (high/medium/low domain tiers) applied before Jina URL reads
- [ ] Modify `.claude/skills/cortex-research/SKILL.md` Phase 0: add backward compatibility for clarify briefs without `questions:` frontmatter — run inline LLM classification with deprecation note
- [ ] Modify `.claude/skills/cortex-research/SKILL.md` argument parser: add `--agentic` flag with `--depth quick` incompatibility check
- [ ] Modify `.claude/skills/cortex-research/SKILL.md`: add agentic execution path with Generator/Digester/Evaluator personas, hard limit circuit breakers (max_iterations, max_cost_usd, max_wall_time_s by depth), and Ralph loop termination guard
- [ ] Modify `.claude/skills/cortex-research/SKILL.md`: add ResearchState persistence at `.cortex/research-state/{slug}.json` with atomic write pattern (tmp + rename) and archive-on-synthesis to `.cortex/research-state/archive/{slug}-{timestamp}.json`
- [ ] Modify `.claude/skills/cortex-research/SKILL.md`: log actually-used provider in dossier source section for each call (visibility into fallback chain usage)
- [ ] Modify `.claude/skills/cortex-close/SKILL.md` Phase 4: archive `.cortex/research-state/archive/{slug}-*.json` files into `docs/cortex/archive/{slug}/research-state/` during slug close
- [ ] End-to-end test: generate a clarify brief with classification, run research with type routing, verify dossier has populated Question Coverage table

---

## 9. Acceptance Criteria

- [ ] `templates/cortex/clarify-brief.md` contains a YAML frontmatter block with `questions:` array schema and inline documentation explaining the 5-type taxonomy
- [ ] `cortex-clarify` Phase 3 instructions include classifying open questions into one of: factual, landscape, mechanism, comparison, codebase (grep for "questions:" and type list in skill file confirms the instruction)
- [ ] `templates/cortex/research-dossier.md` contains `## Question Coverage` section with status column (answered/partial/unanswered) and provider column
- [ ] `cortex-research` Phase 1 contains a type routing table with explicit `search()` calls per type (grep for "type routing" in skill file)
- [ ] `cortex-research` Phase 1.5 contains a budget matrix where depth controls per-question budget (not provider choice)
- [ ] `cortex-research` Phase 2 reorganized with execution paths per type (factual, landscape, mechanism, comparison, codebase)
- [ ] `cortex-research` Phase 2.5 contains source authority ranking with high/medium/low domain tier lists applied before Jina reads
- [ ] `cortex-research` argument parser accepts `--agentic` flag and rejects `--agentic --depth quick` combination with an explicit error
- [ ] `cortex-research` contains an agentic execution path with three distinct LLM persona prompts (Generator, Digester, Evaluator)
- [ ] `cortex-research` agentic path has hard limit circuit breakers (max_iterations, max_cost_usd, max_wall_time_s) defined per depth level
- [ ] `cortex-research` agentic path uses atomic write pattern (tmp + rename) for ResearchState persistence
- [ ] `cortex-research` agentic path archives (not deletes) ResearchState on synthesis
- [ ] `cortex-research` has backward compatibility: clarify briefs without frontmatter fall back to inline LLM classification with a deprecation note
- [ ] `cortex-close` Phase 4 archives `.cortex/research-state/archive/{slug}-*.json` files alongside other slug artifacts
- [ ] End-to-end test produces a research dossier with a populated Question Coverage table showing status per question and provider actually used
- [ ] Test run's total cost (for a standard-depth 5-question research) is under $0.15 (empirical baseline from the implementation dossier: ~$0.13 for 9 targeted calls)
