# Research Dossier: research-depth-routing — implementation

**Slug:** research-depth-routing
**Phase:** implementation
**Timestamp:** 20260410T000000Z
**Depth:** standard
**Provenance:** 3 Perplexity queries (state persistence, pricing, plus prior concept research) + direct codebase reads of existing skills + Gemini cross-reference challenging the implementation plan. All via power_search.

---

## Summary

The implementation requires changes to **two skill files, two templates, and one new optional state directory.** The classification uses **YAML frontmatter in the clarify brief** (not inline tags) for robustness and validation. The type table is explicit with concrete provider sequences and budget numbers — no hand-wavy "Perplexity for factual." The default for missing classifications is `factual` (cheapest), not `mechanism` (expensive). The agentic loop persists `ResearchState` at `.cortex/research-state/{slug}.json` and **archives** it on synthesis (not deletes) for debugging. All classifications are validated against a canonical type list before routing — unknown types error out rather than silently defaulting. Provider failures fall back along a chain (Perplexity → Tavily → Gemini grounded) per intent type.

---

## Findings

- **Current cortex-research skill has depth→provider coupling at lines 50-57.** The skill maps quick→Perplexity, standard→Tavily+Jina+Gemini, deep→gpt-researcher as a flat table. This is the exact code that needs refactoring. Phase 2 is broken into Quick Path, Standard Path, and Deep Path sub-sections, each with hardcoded provider calls. The refactor replaces these with a type-driven routing function called from a shared execution flow. Source: `.claude/skills/cortex-research/SKILL.md` lines 50-160.

- **Current cortex-clarify skill has no classification output.** The clarify brief template has "Open Questions" and "Next Research Steps" sections that are flat bulleted lists. No typing, no structured metadata. Source: `templates/cortex/clarify-brief.md` lines 63-79; `.claude/skills/cortex-clarify/SKILL.md` Phase 3 field population table.

- **Real cost data from power_search usage.db (historical):** Tavily $4.06 cumulative, Perplexity $2.85, Gemini grounded $2.11, Firecrawl $0.15, Gemini GENERATE $0.04, Jina $0.004. Gemini GENERATE is essentially free. Jina is ~40x cheaper than Tavily per call. Tavily and Perplexity are the primary cost drivers. Source: `power_search.usage.by_provider()`.

- **Perplexity 2026 pricing has multiple tiers with different unit economics.** Sonar: $1/M input, $1/M output. Sonar Pro: $3/M input, $15/M output. Sonar Deep Research: $2/$8 per M tokens + $5/1K searches. Search API (raw results): $5/1K requests. For cortex-research's use case, the `Intent.RESEARCH` path uses Sonar-level pricing (~$0.015-0.025/call based on empirical usage). This informs the budget matrix. Source: Perplexity API docs via Perplexity synthesis.

- **LangGraph's TypedDict + checkpointer pattern is the production standard for research state.** `class ResearchState(TypedDict)` with annotated fields, mutated immutably by nodes, checkpointed to disk via `compile(checkpointer=True)`. The pattern enables "time travel" for state inspection and cross-session resumption. For cortex (which is file-based, not a runtime), the equivalent is a JSON file at `.cortex/research-state/{slug}.json` written/read by the skill's pseudocode loop. Source: Perplexity synthesis of LangGraph/CrewAI/AutoGen patterns.

- **Gemini cross-reference flags default-to-mechanism as a cost landmine.** "Defaulting to `[mechanism]` if classification is missing is risky. `[mechanism]` often implies the most expensive deep research. This could silently incur high costs for simple, unclassified questions." Fix: default to `factual` (Perplexity single call, ~$0.02) instead of `mechanism` (Tavily + multiple Jina reads, ~$0.03-0.05). Cheapest default is the safe default. Source: Gemini cross-reference.

- **Gemini cross-reference demands concrete type tables, not pseudo-rules.** "What are the canonical question types? For each type, what is the explicit sequence of tools/providers and their parameters?" The concept dossier had a 5-type table with provider names but no parameters. Implementation needs exact calls: `factual → search(q, intent=RESEARCH, provider='perplexity', max_tokens=2500)`. Source: Gemini cross-reference.

- **Gemini flags state deletion as dangerous.** "Deleting ResearchState JSON on synthesis might be too aggressive. If synthesis fails or is interrupted, the intermediate research state is lost." Fix: move completed state to `.cortex/research-state/archive/{slug}-{timestamp}.json` rather than delete. Keeps debugging trail; archive can be cleaned by `/cortex-close`. Source: Gemini cross-reference.

- **YAML frontmatter is more robust than inline `[type]` tags for classification.** Gemini: "Inline tags: Fragile. Prone to human error, typos, and difficult parsing. Could clutter the brief. YAML frontmatter: Robust, machine readable, supports validation." The existing clarify brief already has metadata at the top (`Slug:`, `Timestamp:`, etc.). Adding a structured `questions:` block at the top with typed entries fits the existing pattern better than inline tags scattered through the body. Source: Gemini cross-reference.

- **Provider fallback chains already exist in power_search but are not exposed.** From power_search SKILL.md: "Deep research: perplexity → gemini_grounded → gemini" and "Web search: gemini_grounded → tavily → perplexity". These chains handle provider failures automatically when calling `search()` without forcing a specific provider. For cortex-research's classified routing, we should use the natural chain for each intent rather than forcing single providers. Source: `~/projects/claude-power-search/SKILL.md` routing table.

---

## Trade-offs

### Option: YAML frontmatter for classification in clarify brief
**Pros:** Machine-parseable, validatable against schema, doesn't clutter the narrative body of the brief, follows existing frontmatter-like patterns (current brief has `**Slug:**`, `**Timestamp:**` header fields).
**Cons:** Less visually integrated with the Open Questions section — reader has to cross-reference top frontmatter with bottom questions. Slightly higher authoring friction.
**Verdict:** selected — robustness wins. Add a `questions:` array in an actual YAML frontmatter block at the top of the clarify brief.

### Option: Inline `[type]` tags on each question
**Pros:** Classification lives next to the question. Simple to write. Low-ceremony.
**Cons:** Fragile parsing. Typos break routing. No schema validation. Clutters the narrative.
**Verdict:** rejected — Gemini's critique is right.

### Option: Default unclassified questions to `factual`
**Pros:** Cheapest route (~$0.02/call via Perplexity). Safe fallback that won't blow up the budget. Perplexity handles a wide range of questions competently.
**Cons:** Some questions genuinely need mechanism-level depth and will be under-served.
**Verdict:** selected — cheap default is the safe default. If a `factual` route returns thin results, the researcher can re-route, as discussed in the concept dossier (classifier is the researcher, so reclassification is cheap).

### Option: Default unclassified questions to `mechanism`
**Pros:** Higher-quality default for complex questions.
**Cons:** Most expensive route ($0.03-0.05/call with multiple Jina reads). Silently incurs high costs for simple questions.
**Verdict:** rejected per Gemini's critique.

### Option: Archive state on synthesis (`.cortex/research-state/archive/`)
**Pros:** Debugging trail preserved. Failed synthesis can be recovered. Archive cleaned automatically by `/cortex-close`.
**Cons:** Small disk footprint accumulation. Needs explicit cleanup mechanism.
**Verdict:** selected — cleanup is a solved problem (tie into /cortex-close).

### Option: Delete state on synthesis
**Pros:** Zero persistent footprint.
**Cons:** Loses debugging trail. Synthesis interruptions lose work.
**Verdict:** rejected.

### Option: Use power_search's natural fallback chains (don't force providers)
**Pros:** Leverages existing infrastructure. Provider failures handled automatically. Simpler skill code.
**Cons:** Less explicit control over which provider gets used. Could mask cost issues (fallback to expensive provider unnoticed).
**Verdict:** selected with monitoring — use natural chains, but log which provider actually served each call in the dossier's source section. This gives fallback robustness without losing visibility.

### Option: Block --agentic with --depth quick
**Pros:** Prevents the contradictory combination. Saves users from incoherent config.
**Cons:** Removes flexibility. Some users might have valid reasons (e.g., tight budget but still want iteration).
**Verdict:** selected — block the combination, print a clear error: `--agentic requires --depth standard or --depth deep`.

---

## Recommendations

### 1. Add YAML frontmatter `questions` block to clarify brief template

Modify `templates/cortex/clarify-brief.md` to include a frontmatter block at the top:

```markdown
---
slug: {SLUG}
timestamp: {TIMESTAMP}
status: {STATUS}
complexity: {COMPLEXITY}
questions:
  - id: q1
    text: "What question-type taxonomies exist in information retrieval?"
    type: factual
  - id: q2
    text: "How do iterative research loops decide when to continue vs stop?"
    type: mechanism
  - id: q3
    text: "Compare Perplexity vs gpt-researcher on targeted questions"
    type: comparison
---

# Clarify Brief: {SLUG}
...
```

The legacy header fields (`**Slug:**`, `**Timestamp:**`) remain in the body for backward compatibility and human readability. The frontmatter is the machine-readable source of truth.

### 2. Update cortex-clarify skill to populate the frontmatter

In `.claude/skills/cortex-clarify/SKILL.md` Phase 3, add a step: "For each open question derived during clarification, classify it by type and add to the frontmatter `questions:` array. Use the canonical type list: factual, landscape, mechanism, comparison, codebase. If a question is genuinely multi-intent, decompose it into separate typed sub-questions (per Anthropic multi-agent decomposition pattern)."

### 3. Define the canonical type table in cortex-research SKILL.md

Replace the current depth routing table (lines 50-57) with a type routing table:

```markdown
### Phase 1: Question Type Routing

Read the clarify brief frontmatter. Extract the `questions:` array. For each question, route to the appropriate execution path using this table:

| Type | Intent | Primary Call | Fallback Chain | When to use |
|------|--------|--------------|----------------|-------------|
| factual | Intent.RESEARCH | `search(q, provider="perplexity", max_tokens=2500)` | perplexity → gemini_grounded → gemini | Specific answers with citations: "What is X?", "What's the benchmark score?" |
| landscape | Intent.SEARCH | `search(q, provider="tavily", depth="advanced", max_results=7)` | tavily → gemini_grounded → perplexity | Broad surveys: "What AI memory systems exist?", "Survey of X approaches" |
| mechanism | Intent.SEARCH + Intent.READ_URL | `tavily_results = search(q, provider="tavily", depth="advanced", max_results=5)` then `for url in top_urls[:2]: search(url, intent=Intent.READ_URL)` | tavily → gemini_grounded; jina → firecrawl for reads | Understanding how a system/pattern works: "How does MemGPT work?" |
| comparison | Intent.RESEARCH + Intent.GENERATE | `perplexity_result = search(q, provider="perplexity")` then `gemini_challenge = search(perplexity_result, intent=Intent.GENERATE, provider="gemini")` | perplexity → gemini_grounded; gemini for GENERATE | Trade-offs: "X vs Y for use case Z" |
| codebase | NOT web research | `Agent(subagent_type="Explore", prompt=q)` or direct Read/Grep/Glob | Fall back to Read tool directly | Internal project analysis: "Where does Cortex lose context?" |

**Unclassified questions default to `factual`.** Missing types are NOT auto-defaulted — they error out with: `Unknown question type '{type}' in clarify brief. Valid types: factual, landscape, mechanism, comparison, codebase.`
```

### 4. Define the budget matrix (depth × type → concrete numbers)

Replace the adjacent discovery depth table with a complete budget matrix:

```markdown
### Phase 1.5: Budget Allocation

Depth controls the budget per classified question (not provider choice).

| Depth | factual | landscape | mechanism | comparison | codebase |
|-------|---------|-----------|-----------|------------|----------|
| Quick | 1 Perplexity call (~$0.02) | 1 Tavily search, 1 Jina read (~$0.02) | 1 Tavily search, 1 Jina read (~$0.02) | 1 Perplexity call (~$0.02) | 1 Agent call |
| Standard | 1 Perplexity + 1 verification search (~$0.04) | 1 Tavily (7 results) + 2 Jina reads (~$0.02) | 1 Tavily (5 results) + 2 Jina reads (~$0.02) | 1 Perplexity + 1 Gemini cross-ref (~$0.02) | 1 Agent call + direct file reads |
| Deep | 1 Perplexity + 1 follow-up + Gemini verify (~$0.06) | 1 Tavily (7 results) + 3 Jina reads + 1 follow-up (~$0.04) | 1 Tavily (7 results) + 3 Jina reads + 1 follow-up (~$0.04) | 1 Perplexity + 1 Gemini + 1 Tavily edge-case (~$0.04) | 2 Agent calls + direct reads |

Per-question budget enforcement: if a call exceeds its cost budget, log a warning and skip to the next question. Per-session budget cap: sum across all classified questions + adjacent discovery budget.
```

### 5. Add source authority ranking before Jina reads

In the mechanism and landscape paths, after receiving Tavily results, apply this filter before spending Jina reads:

```python
AUTHORITY_TIERS = {
    "high": ["arxiv.org", "anthropic.com", "letta.com", "*.gov", "openai.com",
             "python.org", "docs.*", "github.com/explore"],  # official docs
    "medium": ["dev.to", "medium.com", "substack.com", "engineering.*.com"],  # quality blogs
    "low": ["linkedin.com", "reddit.com", "twitter.com", "*.wordpress.com"],  # social/forums
}

def rank_urls_by_authority(urls):
    # Returns urls sorted: high first, then medium, then low
    # Read high first; only read low if high+medium exhausted the budget
```

Budget Jina reads against the high-authority pool first. Never read LinkedIn when arxiv exists on the same question.

### 6. Add `## Question Coverage` section to research dossier template

Modify `templates/cortex/research-dossier.md` to include a new section after Findings:

```markdown
## Question Coverage

| # | Question ID | Type | Status | Addressed by | Provider Used |
|---|-------------|------|--------|--------------|----------------|
| 1 | q1 | factual | ✓ answered | Finding 3 | perplexity |
| 2 | q2 | mechanism | ✓ answered | Findings 4, 5 | tavily → jina (arxiv.org, letta.com) |
| 3 | q3 | comparison | partial | Finding 7 | perplexity (gemini cross-ref skipped due to budget) |
```

Status values: `✓ answered`, `partial`, `✗ unanswered`. The table is the skill's self-eval.

### 7. Add optional `--agentic` flag with ResearchState persistence

Modify `.claude/skills/cortex-research/SKILL.md` argument section:

```markdown
- `--agentic` — Enable iterative ReAct loop with Generator/Digester/Evaluator personas. Default: off. Requires `--depth standard` or `--depth deep`. Incompatible with `--depth quick`.
```

When `--agentic` is set, the skill enters the loop described in the concept-extension dossier. State is persisted:

```python
# Pseudocode for state persistence
STATE_PATH = f".cortex/research-state/{slug}.json"
ARCHIVE_PATH = f".cortex/research-state/archive/{slug}-{timestamp}.json"

def save_state(state: dict):
    os.makedirs(os.path.dirname(STATE_PATH), exist_ok=True)
    # Atomic write: tmp file + rename
    tmp = STATE_PATH + ".tmp"
    with open(tmp, 'w') as f:
        json.dump(state, f, indent=2)
    os.rename(tmp, STATE_PATH)

def archive_state():
    if os.path.exists(STATE_PATH):
        os.makedirs(os.path.dirname(ARCHIVE_PATH), exist_ok=True)
        os.rename(STATE_PATH, ARCHIVE_PATH)

def load_state() -> dict | None:
    if os.path.exists(STATE_PATH):
        with open(STATE_PATH) as f:
            return json.load(f)
    return None
```

The ResearchState schema (persisted to JSON):

```json
{
  "slug": "research-depth-routing",
  "iteration": 3,
  "started_at": "2026-04-10T00:00:00Z",
  "last_updated": "2026-04-10T00:03:42Z",
  "clarify_brief_path": "docs/cortex/clarify/research-depth-routing/20260409T212000Z-clarify-brief.md",
  "depth": "deep",
  "hard_limits": {
    "max_iterations": 8,
    "max_cost_usd": 0.50,
    "max_wall_time_s": 600
  },
  "cost_accumulated": 0.14,
  "wall_time_s": 222,
  "questions": [
    {"id": "q1", "text": "...", "type": "factual", "status": "answered", "findings": ["finding-1"]},
    {"id": "q2", "text": "...", "type": "mechanism", "status": "partial", "findings": ["finding-3"]},
    {"id": "q3", "text": "...", "type": "comparison", "status": "open", "findings": []}
  ],
  "search_history": [
    {"iteration": 1, "question_id": "q1", "query_hash": "ab12...", "provider": "perplexity", "cost": 0.02, "result_hash": "cd34..."},
    {"iteration": 2, "question_id": "q2", "query_hash": "ef56...", "provider": "tavily", "cost": 0.016, "result_hash": "gh78..."}
  ],
  "digest_history": [
    {"iteration": 1, "question_id": "q1", "digest": "Perplexity returned...", "addressed_questions": ["q1"], "gaps_revealed": []}
  ],
  "current_understanding": "Evolving summary of what's known so far...",
  "evaluator_decisions": [
    {"iteration": 2, "done": false, "reason": "q2 and q3 still open", "suggested_next": "Read letta.com/blog/agent-memory"}
  ]
}
```

Archive on synthesis, don't delete.

### 8. Update `/cortex-close` to clean up research-state archive

Add to `.claude/skills/cortex-close/SKILL.md` Phase 4:

```markdown
4a. If `.cortex/research-state/archive/{slug}-*.json` files exist, move them to `docs/cortex/archive/{slug}/research-state/` alongside other archived artifacts for this slug.
```

### 9. Backward compatibility for clarify briefs without frontmatter

At Phase 0 of the refactored cortex-research: "If the clarify brief has no `questions:` frontmatter array, treat it as an untyped brief. Extract open questions from the body's `## Open Questions` section and classify them inline using the LLM before proceeding. Print a deprecation note: `Clarify brief lacks questions frontmatter — classifying inline. Regenerate the brief with /cortex-clarify for typed routing.`"

This keeps existing clarify briefs (like the intelligence-loop-memory one) working while encouraging migration.

### 10. Explicit error handling and fallback

Add to the new Phase 2:

```markdown
**Error handling:**

- **Provider failure:** Use power_search's natural fallback chains (perplexity → gemini_grounded → gemini for RESEARCH; tavily → gemini_grounded for SEARCH). If all providers in the chain fail, skip the question with status `✗ unanswered (provider failure)` and continue to the next.
- **Unknown type in classification:** Error out immediately with the list of valid types. Do not silently default.
- **Budget exhaustion mid-question:** Complete the current call (to avoid half-done work), log a warning, and skip remaining questions with status `skipped (budget exhausted)`.
- **Parsing failure on clarify brief frontmatter:** Fall back to backward-compat mode (see recommendation 9).
- **Agentic loop iteration failure:** Increment iteration counter anyway (prevents infinite retry on the same broken state), log the error to digest_history, and let the evaluator decide whether to continue or abort.
```

---

## Question Coverage

| # | Question | Type | Status | Addressed by | Provider Used |
|---|----------|------|--------|--------------|---------------|
| 1 | What does the current cortex-research SKILL.md look like exactly? | codebase | ✓ answered | Finding 1 | Direct Read tool |
| 2 | What does the current cortex-clarify SKILL.md look like? | codebase | ✓ answered | Finding 2 | Direct Read tool |
| 3 | How is power_search actually invoked — what's the exact API signature? | codebase | ✓ answered | Finding 9 (power_search SKILL.md read) | Direct Read |
| 4 | How should the ResearchState JSON schema be structured? | pattern | ✓ answered | Finding 5 + Recommendation 7 | perplexity (LangGraph/CrewAI) |
| 5 | What are the concrete cost numbers per provider? | factual | ✓ answered | Findings 3, 4 | power_search.usage + perplexity |
| 6 | How do existing skills read/write state files? | codebase | ✓ answered | cortex-map SKILL.md read pattern | Direct Read |

All 6 questions answered. Coverage 6/6.

---

## Adjacent Findings

- **Gemini GENERATE is effectively free and underutilized.** Historical usage: $0.04 total across all Cortex sessions, compared to $2.85 for Perplexity and $4.06 for Tavily. Gemini cross-reference calls cost essentially nothing yet provide skeptical second opinions. This means: add Gemini cross-reference more aggressively in the budget matrix — there's no cost reason not to. Specifically, add it to the standard and deep paths of mechanism and landscape types, not just comparison. Source: `power_search.usage.by_provider()`.

- **Provider cost asymmetry is ~1000x between cheapest and most expensive.** Jina reads at $0.0006 vs Tavily at $0.016 vs Perplexity RESEARCH at $0.020 vs Perplexity Deep Research at $0.41/query. The cost spread means small routing mistakes can produce large bill differences. A factual question misrouted to Perplexity Deep Research costs 20x more than a correct Perplexity Sonar routing. This validates the need for explicit type tables — fuzzy provider selection is expensive. Source: Perplexity pricing synthesis + power_search usage.

- **The existing power_search fallback chains already solve provider failure handling.** From `~/projects/claude-power-search/SKILL.md`: "Deep research: perplexity → gemini_grounded → gemini" and "Web search: gemini_grounded → tavily → perplexity". The cortex-research skill should trust these chains instead of implementing its own fallback logic. This reduces implementation complexity and avoids reinventing error handling. Source: power_search SKILL.md routing table.

---

## Open Questions

- Should per-question cost budgets be hard (kill at limit) or soft (warn and continue)? Proposed: soft for within-budget warnings, hard for session-level cap. Needs validation during implementation.
- How should the budget matrix interact with multi-agent research (`--team` flag)? Currently `--team` is undocumented in the skill — needs separate spec decision.
- What's the atomic test for "Gemini GENERATE should be more aggressive"? Probably: measure dossier quality with and without Gemini cross-reference, compare at evals phase.
- Should the ResearchState JSON schema be versioned? If the schema changes mid-project, how do old state files migrate? Proposed: add `"schema_version": 1` field, bump on breaking changes.
- Should the YAML frontmatter in the clarify brief use a proper YAML parser or line-by-line extraction? Python's `yaml` module is stdlib (ships with pyyaml), so proper parsing is cheap. Recommend: use `yaml.safe_load()` with error handling.
- How does the classification flow interact with the existing `Complexity:` field (trivial/standard/complex)? Proposed: complexity still determines depth override (trivial → skip research, complex → force deep); type classifications route questions within that depth. The two are orthogonal — complexity is about overall slug effort, type is about per-question strategy.

---

## Sources

### Web sources (via power_search)

**Perplexity (targeted factual + mechanism questions):**
- Perplexity RESEARCH: "Research state persistence patterns in LangGraph/CrewAI/AutoGen" → TypedDict schema, checkpointer pattern, StateGraph compilation (~$0.0255)
- Perplexity RESEARCH: "Current provider pricing 2026" → Perplexity Sonar tier breakdown, Sonar Deep Research $0.41/query avg (~$0.0142)

**Codebase reads (direct file reads):**
- `.claude/skills/cortex-research/SKILL.md` lines 40-180 — current depth routing implementation
- `.claude/skills/cortex-clarify/SKILL.md` Phase 3 — current field population (no classification)
- `.claude/skills/cortex-map/SKILL.md` lines 1-40 — mode-based flag pattern to follow
- `templates/cortex/clarify-brief.md` — current structure, need to add frontmatter
- `~/projects/claude-power-search/SKILL.md` — power_search API, routing table, fallback chains
- `.cortex/` directory listing — state file locations, existing patterns

**Empirical data:**
- `power_search.usage.by_provider()` — real cost totals: tavily $4.06, perplexity $2.85, gemini_grounded $2.11, firecrawl $0.15, gemini $0.04, jina $0.004
- Prior dossiers in this slug: concept ($0.13) and concept-extension (~$0.08) used as empirical baseline

### Cross-reference
- Gemini GENERATE — flagged default-to-mechanism as cost landmine (fixed: default to factual), demanded concrete type tables with exact parameters (fixed: Recommendation 3), challenged state deletion (fixed: archive instead), validated YAML frontmatter over inline tags

### Base
- `docs/cortex/research/research-depth-routing/concept-20260409T213000Z.md` — concept dossier establishing 5-type taxonomy
- `docs/cortex/research/research-depth-routing/concept-extension-20260409T214500Z.md` — extension establishing agentic loop with Generator/Digester/Evaluator
