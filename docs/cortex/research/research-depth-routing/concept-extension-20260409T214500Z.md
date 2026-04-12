# Research Dossier: research-depth-routing — concept (extension: agentic workflow)

**Slug:** research-depth-routing
**Phase:** concept (extension)
**Timestamp:** 20260409T214500Z
**Depth:** standard
**Provenance:** 3 Perplexity queries + 2 Tavily searches + 1 Jina URL read (Anthropic harness design) + Gemini cross-reference. All via power_search. Extension to concept-20260409T213000Z.md.

---

## Summary

An optional `--agentic` mode should add a **ReAct-style loop with a dedicated evaluator agent** on top of the classified taxonomy from the prior concept dossier. The loop is: **Think → Classify → Act (route + search) → Observe → Digest → Evaluate → Decide (continue/terminate)**. The evaluator is a separate LLM call with a skeptical system prompt that checks progress against the clarify brief's open questions — critically, the generator cannot self-terminate because generators confidently praise their own work (Anthropic finding). Hard cost/iteration circuit breakers override quality-based termination. Default mode remains linear classified routing; agentic mode is opt-in for complex exploratory research where the initial question set will evolve based on findings.

---

## Findings

- **The ReAct pattern (Reason → Act → Observe) is the canonical loop structure.** Thought ("I need population data") → Action (`Search("city population")`) → Observation ("8.4 million"). The cycle repeats, with the agent maintaining dialogue history to plan on-the-fly. Prompts enforce this format via templates. This maps directly to cortex-research: each iteration reasons about what's still unknown, routes to a provider, processes the result, and decides the next step. Source: Perplexity synthesis of ReAct literature.

- **gpt-researcher implements recursive breadth/depth exploration as its iteration model.** Default config: `breadth=4` parallel research paths, `depth=2` levels, `concurrency=4`. Each level halves breadth (`breadth // 2`) and decrements depth. Follow-up questions from each result spawn deeper searches: `next_query = f"Previous goal: {result['researchGoal']}\nFollow-ups: {' '.join(result['followUpQuestions'])}"`. This is tree exploration, not flat iteration. Source: docs.gptr.dev/blog/2025/02/26/deep-research.

- **Anthropic's generator + evaluator pattern is essential for quality-based termination.** From the harness design article: "agents tend to respond by confidently praising the work—even when, to a human observer, the quality is obviously mediocre." Separating the agent doing work from the agent judging it is "a strong lever." Tuning a standalone skeptical evaluator is "far more tractable than making a generator critical of its own work." Feedback loops run 5-15 iterations. Without separation, self-evaluation is unreliable. Source: anthropic.com/engineering/harness-design-long-running-apps.

- **Context resets beat compaction for long agentic loops.** Anthropic found that context compaction leaves "context anxiety" where agents prematurely wrap up near context limits. Full context reset with a structured handoff artifact is the solution. This means long cortex-research agentic sessions should reset between iteration phases, passing a structured state (clarify brief + answered questions + digest history) rather than summarizing in place. Claude Sonnet 4.5 "exhibited context anxiety strongly enough that compaction alone wasn't sufficient." Source: anthropic.com/engineering/harness-design-long-running-apps.

- **The Ralph loop pattern guards against premature termination.** A `for` loop that "kicks the agent back into context when it claims completion, and asks if it's really done." Useful for long-running tasks — the agent will admit the task is not up to spec and continue. For cortex-research agentic mode, this translates to: when the evaluator says all questions are answered, prompt it once more with "Are you absolutely sure all aspects of the clarify brief are comprehensively covered?" before actually terminating. Source: anthropic.com/research/long-running-Claude.

- **Production agents use hard iteration limits, not just quality-based termination.** gpt-researcher caps at 5-10 iterations + confidence score. AutoGPT: 5-20 iterations + utility threshold + explicit task-complete signal. BabyAGI: 3-5 task cycles + empty task list. LangChain ReAct: max_steps + convergence detection (repeated similar observations) + token counter. The pattern is consistent: **soft quality criteria layered on top of hard resource limits**. Source: Perplexity synthesis of production agent termination criteria.

- **Multi-agent decomposition gives 90.2% improvement on breadth-first tasks, but adds error propagation risk.** Linear single-pass is fast, predictable, low coordination overhead — but fails on exploratory/complex tasks. Iterative agentic outperforms linear by 90.2% on complex evals (Anthropic internal), but risks unpredictability, inter-agent misalignment, and error propagation. The trade-off is sharp: use linear for routine, iterative for discovery. Source: Perplexity synthesis + anthropic.com/engineering/multi-agent-research-system.

- **Structured state management prevents loop circularity.** Gemini cross-reference identified the key risk: without a `ResearchState` object tracking (a) which clarify-brief questions are marked `[answered]` vs `[open]`, (b) search history hashes to avoid re-fetching, (c) an evolving "current understanding" summary, the loop can generate redundant queries before hitting the hard limit. State must be maintained across iterations, not reconstructed from chat history. Source: Gemini cross-reference.

- **The digest step should be a separate LLM call, not inline reasoning.** Gemini cross-reference: "Digesting raw observations is a specialized task. A dedicated 'Digester' persona (even if it's the same model with a specific system prompt) can be tuned for conciseness, accuracy, and extracting key points relevant to the clarify brief." This also allows using a smaller/faster model for the digest step while keeping the generator on a capable model. Source: Gemini cross-reference, aligned with Anthropic generator/evaluator pattern.

---

## Trade-offs

### Option: Inline ReAct loop (single LLM plays all roles)
**Pros:** Simple implementation, single context, no orchestration complexity, one LLM call per iteration.
**Cons:** Self-evaluation is unreliable — generator confidently praises its own work. Cannot reliably terminate on quality. Context anxiety leads to premature wrap-up. Loop circularity is hard to detect from within the same context.
**Verdict:** rejected — the self-evaluation failure mode is fatal for quality-based termination.

### Option: Generator + Evaluator with separate LLM calls
**Pros:** Evaluator can be tuned skeptical independently. Termination based on objective progress check, not self-praise. Each iteration has clear role separation (generator reasons and acts, evaluator judges). Follows Anthropic's proven pattern.
**Cons:** 2x LLM calls per iteration (generator + evaluator). More orchestration complexity. Need to coordinate state between two personas.
**Verdict:** selected — the quality improvement from skeptical evaluation is worth the 2x call overhead. Cortex's agentic mode is opt-in specifically for cases where quality matters more than speed.

### Option: Three-agent (Generator + Evaluator + Planner)
**Pros:** Planner decomposes the clarify brief upfront, generator executes individual tasks, evaluator judges. Maximum separation of concerns.
**Cons:** 3x LLM calls per iteration. Overkill for research tasks — the clarify brief already serves as the plan. Adds coordination overhead with marginal quality gain.
**Verdict:** rejected — the clarify brief IS the plan. Adding a planner duplicates work the human already did at clarify time.

### Option: ReAct loop with structured ResearchState
**Pros:** Prevents circularity via hashed search history and explicit question status tracking. Makes state inspectable for debugging. Enables clean context resets (pass state, not chat history).
**Cons:** Adds state schema to maintain. Small runtime overhead.
**Verdict:** selected — Gemini's critique is correct; state management is non-negotiable for robust iteration.

### Option: Hard resource limits + soft quality termination
**Pros:** Hard limits prevent runaway cost. Quality termination allows early exit when the work is actually done. Resource limits are simple to enforce (iteration count, token count, wall time). Quality termination is the evaluator's job.
**Cons:** Requires both mechanisms — neither is sufficient alone.
**Verdict:** selected — this is the industry-standard pattern across gpt-researcher, AutoGPT, BabyAGI, and LangChain.

---

## Recommendations

### 1. Add `--agentic` flag to cortex-research

Opt-in mode. Default remains linear classified routing. When `--agentic` is set, the skill switches to the iterative loop described below.

### 2. Define the agentic loop structure

```
State: ResearchState {
  clarify_brief: { open_questions: [...], answered: [], coverage: {} }
  search_history: [{ query_hash, provider, result_hash, timestamp }]
  digest_history: [{ iteration, question_id, digest_text }]
  current_understanding: str  # evolving summary
  iteration: int
  total_cost: float
  hard_limits: { max_iterations: 8, max_cost_usd: 0.50, max_wall_time_s: 600 }
}

Loop:
  while not (hard_limit_hit OR evaluator_says_done):
    # 1. Generator thinks: what's the next question to pursue?
    next_question = generator.think(state)
    
    # 2. Generator classifies: what type is it?
    question_type = classify(next_question)  # factual/landscape/mechanism/comparison/codebase
    
    # 3. Route and act: use the classified taxonomy
    provider, strategy = route(question_type, depth)
    result = provider.search(next_question, strategy)
    
    # 4. Digest: separate LLM call with concise-extraction prompt
    digest = digester.extract(result, against=state.open_questions)
    
    # 5. Update state
    state.search_history.append(...)
    state.digest_history.append(...)
    state.current_understanding = merge(state.current_understanding, digest)
    state.iteration += 1
    
    # 6. Evaluate: separate LLM call with skeptical prompt
    evaluation = evaluator.assess(state)
    # evaluation = { done: bool, reason: str, gaps: [question_ids] }
    
    if evaluation.done:
      # Ralph loop: ask once more
      final_check = evaluator.ralph_check(state)
      if final_check.done:
        break
    
    # 7. Check hard limits
    if state.iteration >= state.hard_limits.max_iterations:
      break
    if state.total_cost >= state.hard_limits.max_cost_usd:
      break
    if elapsed_time() >= state.hard_limits.max_wall_time_s:
      break

Terminate with synthesis of digest_history + current_understanding.
```

### 3. Define the three LLM personas

**Generator (Think + Act):**
- System prompt: "You are a research generator. Given the current research state, identify the highest-value next question to pursue. Reference the open questions in the clarify brief. Classify the question by type (factual/landscape/mechanism/comparison/codebase). Output: { question: str, type: str, reasoning: str }"
- Uses the classified taxonomy from the prior concept dossier

**Digester (Observe → Extract):**
- System prompt: "You are a research digest extractor. Given raw search results and the clarify brief's open questions, produce a concise digest that identifies which questions the result addresses and the key findings. Output: { addressed_questions: [ids], key_findings: [str], gaps_revealed: [str] }"
- Can use a smaller/faster model (Haiku-class) to save cost

**Evaluator (Skeptical Assess):**
- System prompt: "You are a skeptical research evaluator. Review the research state and assess: (1) which clarify-brief questions are genuinely answered vs. still open, (2) is the current understanding coherent or contradictory, (3) is the loop going in circles (check search_history hashes), (4) should the loop terminate. Be skeptical — do NOT approve termination if any open question is partially answered. Output: { done: bool, reason: str, open_gaps: [question_ids], suggested_next: str }"
- Must be tuned skeptical — this is the core insight from Anthropic

### 4. Hard resource limits (circuit breakers)

These override quality-based termination. Defaults:

| Limit | Quick | Standard | Deep |
|-------|-------|----------|------|
| max_iterations | 3 | 5 | 8 |
| max_cost_usd | 0.10 | 0.25 | 0.50 |
| max_wall_time_s | 120 | 300 | 600 |

Exceeding any limit triggers immediate termination with a warning in the dossier: `Loop terminated by {limit_type} — {N} questions remain unanswered.`

### 5. Ralph loop for termination guard

When the evaluator says "done", make one additional check: `"Are you absolutely sure all aspects of the clarify brief are comprehensively covered? Review each open question individually."` If the evaluator still says done, terminate. If it finds a gap, continue the loop.

### 6. Context reset strategy for long loops

At iteration 5+ (approximately when context anxiety kicks in for Claude Sonnet 4.5), reset the generator's context. Pass the structured `ResearchState` (not chat history) to a fresh generator instance. The digest history and current understanding summary carry continuity without the bloat of full raw search results.

### 7. When to recommend agentic mode

**Use agentic mode (--agentic flag) when:**
- Clarify brief has 6+ open questions
- Clarify brief mentions words like "explore", "analyze", "investigate", "discover", "survey"
- Complexity is `complex` AND depth is `deep`
- Initial research passes are likely to surface new questions not in the original brief

**Use default (classified linear) mode when:**
- Clarify brief has 3-5 focused questions
- All questions are `factual` or `mechanism` type (can be planned upfront)
- Complexity is `standard` or `trivial`
- Speed matters more than depth

### 8. Cost visibility during the loop

Print running cost after each iteration: `[iter 3/8] $0.14 / $0.25 budget | 4/7 questions answered`. This lets the user Ctrl-C if the loop is going off the rails and they're watching.

---

## Question Coverage

| # | Question | Type | Status | Addressed by |
|---|----------|------|--------|--------------|
| 1 | What is the ReAct pattern for research agents? | factual | ✓ answered | Finding 1 |
| 2 | How do iterative research loops decide when to continue vs stop? | mechanism | ✓ answered | Findings 1, 6 |
| 3 | Example implementations of digest-then-decide research flows | pattern | ✓ answered | Finding 2 (gpt-researcher recursive) + Finding 3 (Anthropic generator/evaluator) |
| 4 | What are the termination criteria for research agent loops? | factual | ✓ answered | Finding 6 |
| 5 | Linear vs iterative agentic research — when is each appropriate? | comparison | ✓ answered | Finding 7 |

All 5 questions answered. Coverage 5/5.

---

## Adjacent Findings

- **Context anxiety is a measurable Claude Sonnet 4.5 behavior that compaction alone cannot fix.** Anthropic observed that Claude Sonnet 4.5 "exhibited context anxiety strongly enough that compaction alone wasn't sufficient to enable strong long task performance, so context resets became essential to the harness design." This means that for long cortex-research agentic sessions, the existing PostCompact hook is not enough — resets are needed between iteration phases. This is a design constraint that affects the iteration count before a reset is needed (~5 iterations is the empirical breaking point). Source: anthropic.com/engineering/harness-design-long-running-apps.

- **Generators reliably skew positive when evaluating their own work, even on objective tasks.** Anthropic's finding applies beyond subjective design tasks: "even on tasks that do have verifiable outcomes, agents still sometimes exhibit poor judgment that impedes their performance while completing the task." This means self-evaluation is unreliable as a termination oracle even for factual research questions where there's a "correct" answer. The evaluator separation is not optional — it's load-bearing for quality. Source: anthropic.com/engineering/harness-design-long-running-apps.

- **The Ralph loop pattern ("are you really done?") empirically surfaces premature terminations.** From Anthropic: "the agent will admit the task is not up to spec, and continue working until it is." This is a cheap guard — one extra LLM call at the end of the loop — that catches the specific failure mode where the evaluator is about to terminate but hasn't actually verified all questions. Worth building in as the default terminal check. Source: anthropic.com/research/long-running-Claude.

---

## Open Questions

- How should the agentic mode's ResearchState be persisted across session boundaries? Probably in `.cortex/research-state/{slug}.json` — but needs implementation research to resolve format and lifecycle.
- Should the digest and evaluator personas use a smaller/cheaper model (Haiku) while the generator uses the main model (Sonnet/Opus)? Cost savings could be significant, but quality trade-offs need measurement.
- What happens when the hard limit is hit mid-iteration? Terminate immediately with partial results, or complete the current iteration first?
- Should the agentic loop be available at all depth levels, or only `--depth deep`? Intuition says quick agentic is incoherent (too few iterations to benefit from loop structure), but this needs validation.
- How does agentic mode interact with `--team` flag? Currently `--team` invokes an agent team. Agentic mode is a different kind of agent orchestration. Do they compose, conflict, or are they alternatives?
- What's the telemetry for agentic loops? Track iterations, cost, termination reason, coverage %, and feed into facts.jsonl for cross-session learning about what question types benefit from agentic mode.

---

## Sources

### Web sources (via power_search)

**Perplexity (targeted factual questions):**
- Perplexity RESEARCH: "ReAct pattern for research agents" — Thought/Action/Observation loop, continue vs terminate criteria
- Perplexity RESEARCH: "Termination criteria for research agents" — gpt-researcher (5-10 iter + confidence), AutoGPT (5-20 + utility), BabyAGI (3-5 + empty queue), LangChain (max_steps + convergence)
- Perplexity RESEARCH: "Linear vs iterative agentic research comparison" — trade-off matrix, 90.2% improvement on complex tasks

**Tavily (pattern/mechanism searches):**
- Tavily SEARCH: "iterative research agent loop implementation" → anthropic.com/engineering/harness-design-long-running-apps, docs.temporal.io, medium.com (Claude Code traffic tracing)
- Tavily SEARCH: "gpt-researcher deep research implementation" → docs.gptr.dev/blog/2025/02/26/deep-research (recursive breadth/depth), gdplabs.gitbook.io (research flow)

**Jina URL reads:**
- anthropic.com/engineering/harness-design-long-running-apps — three-agent architecture (planner/generator/evaluator), context anxiety, generator self-praise failure mode, 5-15 iteration feedback loops, context resets vs compaction

### Cross-reference
- Gemini GENERATE — challenged self-evaluation termination, demanded structured ResearchState, flagged digest-step-quality concern, recommended separate LLM call for digest, validated generator+evaluator separation as critical

### Extension base
- `docs/cortex/research/research-depth-routing/concept-20260409T213000Z.md` — prior concept dossier establishing the 5-type classified taxonomy that the agentic loop builds on
