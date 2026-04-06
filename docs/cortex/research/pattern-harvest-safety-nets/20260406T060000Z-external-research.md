# External Research: Safety Net Patterns in AI Agent Systems

**Slug:** pattern-harvest-safety-nets  
**Date:** 2026-04-06  
**Scope:** Exhaustive external research across context management, circuit breakers, convergence detection, and iteration budgets  

---

## Track 1: Context Window Management

### 1.1 Claude Code Compaction System (Production-Tested)

**Source:** [Anthropic Engineering — Effective Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents), [Claude API Docs — Compaction](https://platform.claude.com/docs/en/build-with-claude/compaction), [Morph — Claude Code Auto-Compact](https://www.morphllm.com/claude-code-auto-compact), [Decode Claude — Compaction Deep Dive](https://decodeclaude.com/compaction-deep-dive/)

**Three-tier compaction system:**

| Tier | Trigger | Action |
|------|---------|--------|
| 1 — Lightweight cleanup | Ongoing | Clear old tool results, keep only 5 most recent |
| 2 — API-level compaction | Server-side | Provider-native compaction strategies |
| 3 — Full summarization | `/compact` or auto-trigger | Full conversation summary + context reconstruction |

**Trigger thresholds:**
- Auto-compact fires at ~95% of 200K context window (~190K tokens)
- Warning state appears around ~80% usage (~160K tokens)
- Some reports suggest effective trigger at ~83.5% (~167K tokens)
- Internal buffer reserves 33K-45K tokens (16.5-22.5% of context) for the compaction process itself
- Configurable via `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` env var (1-100)

**Context budget breakdown (200K window):**

| Component | Tokens | Survives Compaction? |
|-----------|--------|---------------------|
| System prompt + tools | ~20,000 | Yes |
| MCP tool schemas | 900-51,000 | Yes |
| CLAUDE.md files | 300-2,000 | Yes (reloaded from disk) |
| Auto memory (MEMORY.md) | ~200 lines | First 200 lines only |
| Completion buffer | ~10,000 | Reserved, unavailable |
| **Usable conversation space** | **100K-140K** | **Summarized** |

**Post-compaction reconstruction sequence:**
1. Boundary marker
2. Compressed summary
3. 5 most recently read files (50K token cap)
4. Loaded skills
5. Tool definitions
6. CLAUDE.md project instructions

**Known degradation patterns post-compaction:**
- Forgotten file edits (specific changes compressed to generic descriptions)
- Repeated work (stack traces and hypotheses lost)
- Lost debugging state (narrowed hypotheses disappear)
- Contradictory changes (earlier architectural decisions overwritten)
- "Re-reading loop": agents spend ~60% of time re-searching after compaction, accelerating next compaction

**Key insight from Anthropic:** Context is a finite resource with diminishing marginal returns. "Context rot" creates a performance gradient, not a hard cliff — models remain capable but show reduced precision as tokens accumulate.

### 1.2 Praetorian Deterministic Orchestration Context Gates (Production-Tested)

**Source:** [Praetorian — Deterministic AI Orchestration](https://www.praetorian.com/blog/deterministic-ai-orchestration-a-platform-architecture-for-autonomous-development/)

**Three-tier threshold blocking:**

| Context Usage | State | Action |
|---------------|-------|--------|
| < 75% | Normal | Proceed |
| 75-85% | Warning | Recommend compaction |
| > 85% | **Hard Block** | Refuse to spawn new agents until `precompact-context.sh` runs |

For a 200K window: 150K = should compact, 160K = must compact, 170K = hard block.

**Monitoring mechanism:** Parses session JSONL files (`~/.claude/projects/<hash>/<session>.jsonl`), reading `cache_read`, `cache_create`, `input` usage fields after each exchange.

**Gateway Pattern for token efficiency:** Intent-based context loading instead of eager loading. Agents invoke gateway skills that route to specific library skills on-demand, reducing startup from 71,800 tokens (36% of context) to 0 tokens at startup. Prevents loading all 304+ library tool definitions.

**Loop detection:** If 3 consecutive iterations produce >90% similar outputs, system detects stuck state and escalates.

**Three-level loop system:**
- Level 1 (Intra-Task): Max 10 iterations on single shell commands
- Level 2 (Inter-Phase): Feedback loop blocks exit until review/testing pass
- Level 3 (Orchestrator): Re-invokes entire phases if macro-goals missed

### 1.3 Aider Context Management (Production-Tested)

**Source:** [Aider — Repository Map](https://aider.chat/docs/repomap.html), [Aider — Options Reference](https://aider.chat/docs/config/options.html)

**Token budget allocation:**
- `--map-tokens`: Defaults to 1K tokens for repo map; dynamically expands when no files added to chat
- `--max-chat-history-tokens`: Soft limit triggering summarization; defaults to model's max
- Graph ranking algorithm: Nodes = source files, edges = dependencies; selects most relevant portions
- Separate model configurable for summarization tasks (cheaper model for compression)

### 1.4 Cursor & Windsurf (Production-Tested)

**Source:** [DevToolsAcademy — Cursor vs Windsurf](https://www.devtoolsacademy.com/blog/cursor-vs-windsurf/)

- Cursor: Effective context ~120K tokens (includes chat history, system prompts, AI response)
- Windsurf: Effective context ~100K tokens
- Both struggle past 50 active files
- Windsurf: Indexing Engine builds semantic map of entire codebase; Fast Context is proprietary retrieval layer
- Both require fresh chat sessions to avoid hitting token limits in long sessions
- No published automatic compaction — user must manually start new sessions

### 1.5 ContextBudget: Academic Budget-Aware Management (Research)

**Source:** [ContextBudget — arXiv 2604.01664](https://arxiv.org/html/2604.01664v1)

**Budget-conditioned state representation:** `bt = (st, rt, |ot|)` where rt = remaining budget, |ot| = pending observation token length. Deferred loading — agent assesses capacity before incorporating observations.

**Progressive training curriculum:**
- Stage 1: 8,192 tokens → Stage 5: 4,096 tokens (60 steps each, 300 total)
- Three compression actions: Null (skip), Partial (selective), Full (all segments)

**Results:** 143% improvement over baselines on 32-objective tasks; 41.7% reduction in compression calls on simple tasks.

### 1.6 Production Token Allocation Guidelines

**Source:** [GetMaxim — Context Engineering for AI Agents](https://www.getmaxim.ai/articles/context-engineering-for-ai-agents-production-optimization-strategies/)

**Recommended budget allocation:**

| Component | Budget Share |
|-----------|-------------|
| System instructions | 10-15% |
| Tool context | 15-20% |
| Knowledge context | 30-40% |
| Output buffer | 25-50% |

**Monitoring thresholds:** Never exceed 85% during active work. Check status every 5-10 exchanges. Compact at 70%, don't wait for auto-compaction at 75-92%.

---

## Track 2: Repair/Retry Circuit Breakers

### 2.1 Resilience4j Defaults (Industry Standard, Production-Tested)

**Source:** [Resilience4j — CircuitBreaker](https://resilience4j.readme.io/docs/circuitbreaker)

The gold standard for circuit breaker configuration. Default values:

| Parameter | Default | Meaning |
|-----------|---------|---------|
| failureRateThreshold | **50%** | Circuit opens when 50%+ calls fail |
| slowCallRateThreshold | **100%** | All calls must be slow to trigger |
| slowCallDurationThreshold | **60,000ms** | Definition of "slow" |
| waitDurationInOpenState | **60,000ms** | How long circuit stays open |
| permittedNumberOfCallsInHalfOpenState | **10** | Probe requests to test recovery |
| slidingWindowSize | **100** | Calls tracked for rate calculation |
| minimumNumberOfCalls | **100** | Min calls before circuit can trip |
| slidingWindowType | COUNT_BASED | Count vs time-based window |

### 2.2 LLM-Specific Circuit Breaker Implementations

**Source:** [GitHub — hanzalagithub/llm-circuit-breaker](https://github.com/hanzalagithub/llm-circuit-breaker), [GitHub — 0jonjo/ruby_circuitbreaker](https://github.com/0jonjo/ruby_circuitbreaker)

**LLM Circuit Breaker (JavaScript):**
- `failureThreshold`: 5 failures before opening
- `resetTimeout`: 30,000ms before half-open probe
- `successThreshold`: 3 successes to close circuit

**Ruby Circuit Breaker:**
- `CIRCUIT_THRESHOLD`: 3 failures
- `FAILURE_COOLDOWN_S`: 30 seconds

**LLMProxy (Go):**
- Failure rate threshold: 0.01-1.0 range (0.5 = 50% triggers circuit)
- Statistical window for rate calculation

### 2.3 Five Production Error Handling Patterns (Production-Tested)

**Source:** [Kevin Tan — AI Agent Error Handling: 5 Production Patterns](https://blog.jztan.com/ai-agent-error-handling-patterns/)

**Pattern 1 — Circuit Breakers for LLM Quality:**
- Threshold: **3 consecutive failures** triggers circuit opening
- Reset timeout: **60 seconds** before half-open probe
- Tracks OUTPUT QUALITY validation failures, not just HTTP errors
- Implementation: `BeforeToolCallEvent` blocks when open; `AfterToolCallEvent` inspects results

**Pattern 2 — Validation Gates:**
- Block deletes exceeding 100 records
- Three layers: schema validation, sanity checks, boundary checks
- Intercepts via `BeforeToolCallEvent` before any side effect

**Pattern 3 — Saga Rollbacks:**
- Step classification: read-only (safe), reversible, compensatable, final (irreversible)
- Multi-agent graph routes to rollback nodes on failure

**Pattern 4 — Budget Guardrails:**
- Max tokens: **100,000 per execution**
- Max reasoning cycles: **20 maximum**
- Enforced via `AfterInvocationEvent` hook with hard limits

**Pattern 5 — Human Escalation:**
- Risk matrix: low risk + high confidence = autonomous; medium = flag for review; high = immediate escalation
- Destructive operations ALWAYS require human approval regardless of confidence

### 2.4 FAILURE.md Protocol (Open Standard)

**Source:** [FAILURE.md](https://failure.md/)

**Four failure modes with specific thresholds:**

| Mode | Detection | Response |
|------|-----------|----------|
| Graceful Degradation | Non-critical tool unavailable | Continue with reduced capability, log |
| Partial Failure | Component failure | **max_retries: 3**, backoff: 5s, 15s, 60s → escalate |
| Cascading Failure | 3 failures in 60s OR 2+ health checks failing OR resource doubling in 10min | Circuit breaker → FAILSAFE.md |
| Silent Failure | Output produced despite errors | **0 allowed** — all must be flagged and quarantined |

- Health check interval: **30 seconds**
- Cascading detection: 3 failures within 60 seconds
- Escalation path: root cause → isolate → notify → execute response → verify → resume or escalate

### 2.5 Manus 1.5 Agent Retry Configuration (Production-Tested)

**Source:** [Skywork — Observability for Manus 1.5 Agents](https://skywork.ai/blog/ai-agent/observability-manus-1-5-agents-best-practices/)

**Recommended retry parameters:**
- Initial delay: **250-750ms**
- Backoff factor: **x2**
- Jitter: Full jitter
- Per-attempt timeout: **5-10s** (match provider SLA)
- Max attempts: **3-5 for reads**, fewer for writes unless idempotent
- Only retry on: 429/5xx/timeouts; respect Retry-After headers

**Error budgets:** SLI tracks task success; alerts use 14.4x/6x burn-rate patterns; on burn, throttle retries and freeze non-critical changes.

### 2.6 LangGraph Retry Policies (Production-Tested)

**Source:** [LangChain — LangGraph Retry Policies](https://dev.to/aiengineering/a-beginners-guide-to-handling-errors-in-langgraph-with-retry-policies-h22), [LangChain — Persistence](https://docs.langchain.com/oss/python/langgraph/persistence)

- Default `max_attempts`: **3**
- Retry policy is graph-level, not per-node
- After retries exhausted: failure is final; routing depends on graph design
- Checkpoint persistence: stores pending writes from successful nodes at failed superstep
- On resume: doesn't re-run successful nodes, picks up from last checkpoint

### 2.7 Pydantic AI Durable Execution (Production-Tested)

**Source:** [Pydantic AI — Durable Execution](https://ai.pydantic.dev/durable_execution/overview/)

Three backends for crash-recovery:

| Backend | Mechanism | Key Feature |
|---------|-----------|-------------|
| **Temporal** | Replay-based recovery; saves key inputs/decisions | `TemporalAgent.run()` wraps agent in durable workflow |
| **DBOS** | Postgres-backed state; lightweight | Steps execute as DBOS transactions |
| **Prefect** | Task-level caching + retry | Cache key prevents re-execution; resume from failure point |

All three: model requests, tool calls, and MCP communication wrapped as durable steps. Full streaming and MCP support.

### 2.8 Exponential Backoff vs Hard Cutoff Decision Framework

**Source:** [AWS — Timeouts, Retries and Backoff with Jitter](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/), [Athenic Blog — AI Agent Retry Strategies](https://getathenic.com/blog/ai-agent-retry-strategies-exponential-backoff)

**When to use exponential backoff:** Rate limits, server-side errors, network failures. Start with 1-2s base, double per retry, stop after 5-7 attempts. AWS research: jitter reduces retry storms by 60-80%.

**When to use hard cutoff (circuit breaker):** Persistent failures, provider outage, cascading risk. Three states: Closed → Open → Half-Open.

**Best practice — layered approach:**
1. Exponential backoff for transient errors
2. Circuit breakers for persistent failures
3. Fallback models for LLM unavailability
4. Human escalation for unrecoverable errors

### 2.9 Resilient-LLM Library (Open Source)

**Source:** [GitHub — gitcommitshow/resilient-llm](https://github.com/gitcommitshow/resilient-llm)

- Default retries: **3 attempts**
- Backoff factor: **2** (exponential)
- Rate limiting: token bucket (configurable requests/min, tokens/min)
- Auto-switches providers on failure
- Respects `Retry-After` headers dynamically

### 2.10 Nx Self-Healing CI (Production-Tested)

**Source:** [Nx — Self-Healing CI](https://nx.dev/docs/features/ci-features/self-healing-ci)

- Flaky test detection: same test, same commit SHA, different results
- Auto-retry flaky tasks transparently
- Three confidence tiers for auto-fix: High (auto-apply), Medium (review), Low (manual)
- Genuine bugs get AI-proposed fixes; flaky tests get retried

---

## Track 3: Convergence/Stall Detection

### 3.1 Ralph Loop — ASDLC Pattern (Production-Tested)

**Source:** [ASDLC.io — Ralph Loop](https://asdlc.io/patterns/ralph-loop/), [LinearB — Ralph Loop Agentic Engineering](https://linearb.io/blog/ralph-loop-agentic-engineering-geoffrey-huntley)

**Core principle:** External verification, not agent self-assessment. The agent cannot declare itself finished.

**Convergence mechanism:**
- Stop hook intercepts agent exit attempts
- Evaluates against machine-verifiable criteria (test suites, Docker builds, TypeScript compilation)
- Agent must emit explicit completion promise (e.g., `<promise>DONE</promise>`)
- Without verified external success, stop hook re-injects original prompt

**Iteration limits:** 20-50 iterations maximum (hard caps)

**Convergence probability:** `P(C) = 1 - (1 - p_success)^n` — success likelihood approaches 1 as iterations accumulate.

**Context rot mitigation:** At **60-80% context capacity**, forced rotation to fresh context. State transfer via structured progress files containing: completed tasks, failed approaches (preventing repetition), architectural decisions, modified files.

**Anti-patterns that indicate stall:**
- Vague prompts → divergence with "endless superficial changes"
- No iteration caps → infinite loops and cost overruns
- Missing architectural verification → logic drift without detection

### 3.2 Praetorian Loop Detection (Production-Tested)

**Source:** [Praetorian — Deterministic AI Orchestration](https://www.praetorian.com/blog/deterministic-ai-orchestration-a-platform-architecture-for-autonomous-development/)

**Similarity-based stall detection:**
- If **3 consecutive iterations produce >90% similar outputs**, system detects stuck state
- Escalates rather than continuing to burn tokens
- Eight-layer defense in depth for loop prevention

### 3.3 DoVer Framework — Intervention-Based Debugging (Research)

**Source:** [Saulius.io — Automatic Debugging and Failure Detection](https://saulius.io/blog/automatic-debugging-and-failure-detection-in-ai-agent-systems)

**Four-stage pipeline:**
1. Trial Segmentation: Break execution logs into plan-execute cycles
2. Failure Hypothesis Generation: LLM generates candidate hypotheses
3. Intervention Generation: Minimal edits to isolate cause
4. Intervention Execution: Replay with intervention, compare outcomes

**Key finding:** Best method correctly identifies failing agent only ~53.5% of the time; exact failing step only **14.2%** of the time. Even GPT-4 achieved below 10% on step attribution.

### 3.4 220-Loop Dataset Analysis (Empirical)

**Source:** [DEV Community — How to Tell If Your AI Agent Is Stuck](https://dev.to/boucle2026/how-to-tell-if-your-ai-agent-is-stuck-with-real-data-from-220-loops-4d4h)

**From 220 analyzed loops:**
- 55% productive, 45% exhibited problems (stagnation, stuck, failing)
- Five diagnostic regimes: Productive, Stagnating, Stuck, Failing, Recovering
- Six signal categories: Friction, Failure, Waste, Stagnation, Silence, Surprise
- Top recurring problem appeared **29 times across 40 loops** (72.5% recurrence)
- Only 50% of automated responses successfully reduced their target signal
- One problematic detector generated **13.3x amplification** of signals
- Mechanical fingerprint counting prevents rationalization drift vs agent self-reporting

### 3.5 Deduplication Thresholds for Failure Signatures

**Source:** [NousResearch/hermes-agent — Cognitive Memory Operations](https://github.com/NousResearch/hermes-agent/issues/509)

**Cosine similarity thresholds for dedup:**
- Intra-batch deduplication: **>=0.98** similarity (pure math, no LLM cost)
- Consolidation threshold: **0.85** cosine similarity
- Single threshold insufficient — secondary signal needed beyond similarity

### 3.6 SWE-Agent Stuck Detection (Production-Tested)

**Source:** [SWE-agent GitHub Issues](https://github.com/SWE-agent/SWE-agent/issues/971)

- Known issue: agents get stuck in infinite loops without making tool calls
- Claude observed getting stuck with windowed edit functionality
- Without loop detection, context filtering, or basic verification: repeated failed reasoning steps accumulate until budget or timeout
- Cost-conservative limit: **$1 per instance** or **50 turns** (with Claude 3.7)
- TRAIL framework creates turn-level execution traces for diagnosing where agents get stuck

### 3.7 The Art of Repair — Convergence in APR (Academic)

**Source:** [arXiv 2505.02931 — The Art of Repair](https://arxiv.org/html/2505.02931)

**Iteration-output trade-off findings:**
- Maximum 10 patches per bug (developer threshold for review)
- Base models: benefit from iterative refinement; optimal with moderate iterations
- Fine-tuned models: best with fewer iterations, more initial outputs; performance **decreases** with more iterations
- Last 4-5 patches contribute <10% of solutions for fine-tuned models
- Complex benchmarks (Defects4J) show greater iteration benefits than simple ones (HumanEval-Java)
- Problem difficulty should influence strategy selection

### 3.8 OpenHands Context Overflow Loop (Production Bug)

**Source:** [OpenHands GitHub Issue #6357](https://github.com/OpenHands/OpenHands/issues/6357)

**Root cause:** History truncation (halving) doesn't reset agent internal state. Agent enters infinite loop after truncation because `self.state.start_id` isn't updated.

**Lesson:** Context compaction must be coupled with agent state reset. Truncation without state management causes worse problems than hitting the limit.

---

## Track 4: Iteration Budgets

### 4.1 OpenHands AgentController (Production-Tested)

**Source:** [OpenHands GitHub Issues](https://github.com/All-Hands-AI/OpenHands/issues/6857), [DeepWiki — OpenHands Agent Configuration](https://deepwiki.com/OpenHands/OpenHands/6.3-agent-configuration)

**`max_iterations` implementation:**
- Configurable per-agent iteration limit
- Multi-agent delegation concern: parent + child agents create **MAX_ITERATIONS x MAX_ITERATIONS** worst case
- Dynamic extension: `_handle_message_action` extends limit by `initial_max_iterations` on each new user message
- GLOBAL_MAX_ITERATIONS proposed but not yet standard
- Known bug: `AgentController` loses `_initial_max_iterations` attribute on subsequent requests

### 4.2 SWE-Agent Configuration (Production-Tested)

**Source:** [SWE-agent Documentation](https://swe-agent.com/latest/usage/competitive_runs/)

**Two budget dimensions:**
- `per_instance_cost_limit`: Dollar cap per instance (recommended: **$1** with Claude 3.7)
- Turn limit: Step count cap (recommended: **50 turns**)
- Without limits: "average cost will converge to infinity"
- Mini-SWE-agent: `step_limit` and `cost_limit` in agent config

### 4.3 Google ADK Loop Agents (Production-Tested)

**Source:** [Google ADK — Loop Agents](https://adk.dev/agents/workflow-agents/loop-agents/)

- `max_iterations` parameter on `LoopAgent` (example: **5**)
- Loop agent does NOT inherently decide when to stop
- Two termination strategies:
  1. Hard cap via `max_iterations`
  2. Sub-agent escalation via `tool_context.actions.escalate = True`
- Checker agent pattern: Critic evaluates quality → Refiner improves or exits
- Exact phrase matching for quality signal (e.g., `"No major issues found."`)

### 4.4 n8n AI Agent Node (Production-Tested)

**Source:** [n8n GitHub Issue #22771](https://github.com/n8n-io/n8n/issues/22771), [n8n Community](https://community.n8n.io/t/agent-has-stopped-due-to-max-iterations-error-message/52284)

- Default max iterations: **100**
- Known bug: hitting max iterations routes to Success output instead of Error output
- Adding >2 tools often triggers iteration limit
- Agent uses logic that relies on repeatedly evaluating or calling external tools

### 4.5 LangChain AgentExecutor (Production-Tested)

**Source:** [LangChain — Max Iterations](https://python.langchain.com/v0.1/docs/modules/agents/how_to/max_iterations/)

**Two early stopping methods:**
1. `force` (default): Returns constant string saying it hit the limit
2. `generate`: One final LLM pass to generate answer based on previous steps

**`max_iterations`:** Configurable (examples show 2-15); default is `None` in many configurations (unlimited — dangerous).

### 4.6 Kevin Tan Production Patterns (Production-Tested)

**Source:** [Kevin Tan — AI Agent Error Handling Patterns](https://blog.jztan.com/ai-agent-error-handling-patterns/)

- Max tokens per execution: **100,000**
- Max reasoning cycles: **20**
- 92% of organizations reported costs higher than expected
- Runaway loops identified as primary cost driver

### 4.7 Ralph Loop Iteration Budgets (Production-Tested)

**Source:** [ASDLC.io — Ralph Loop](https://asdlc.io/patterns/ralph-loop/)

- Hard caps: **20-50 iterations**
- Context rotation at **60-80% capacity**
- Costs tracked throughout
- Failed approaches recorded in progress files to prevent repetition

### 4.8 Devin AI (Production-Tested)

**Source:** [Devin Docs — Release Notes](https://docs.devin.ai/release-notes)

- Per-command timeout: **2 minutes**
- No documented sophisticated stuck-loop detection
- Relies on human intervention via chat when stuck
- Break task into smaller steps is the recommended recovery

### 4.9 Framework Default Comparison

| Framework | Default Max Iterations | Budget Type | Stopping Method |
|-----------|----------------------|-------------|-----------------|
| LangChain AgentExecutor | None (unlimited) | Iteration count | force / generate |
| n8n AI Agent | 100 | Iteration count | Routes to output (buggy) |
| Google ADK LoopAgent | Configurable (no default) | Iteration count + escalation | Hard stop or escalation |
| OpenHands | Configurable | Iteration count | Hard stop |
| SWE-agent | Configurable | Cost ($) + turn count | Hard stop |
| Ralph Loop | 20-50 | Iteration count + context % | External verification |
| Kevin Tan patterns | 20 cycles | Cycle count + token count | Hard limit via hook |
| Devin | N/A | Per-command timeout (2min) | Timeout |

---

## Cross-Cutting Themes

### Theme 1: Three-State Circuit Breakers Are the Standard

Every production system converges on Closed → Open → Half-Open. The only variations are:
- **What counts as failure:** HTTP errors vs output quality validation (Kevin Tan's pattern is notable — it tracks quality, not just crashes)
- **Threshold values:** 3-5 failures is the most common trigger; 30-60 seconds is the standard wait before half-open

### Theme 2: No Framework Ships Budget Caps by Default

Every major framework (LangChain, CrewAI, AutoGen) provides iteration limits and hooks, but actual dollar-denominated budget enforcement must be built externally. The `max_iterations` defaults are either None/unlimited or set dangerously high (100).

### Theme 3: External Verification Beats Self-Assessment

Ralph Loop's core insight is universally validated: agents cannot reliably assess their own completion. Machine-verifiable criteria (test suites, compilation, Docker builds) are the only reliable convergence signal. The DoVer finding that even GPT-4 achieves <10% accuracy on step-level failure attribution reinforces this.

### Theme 4: Context Management Is the Primary Bottleneck

Praetorian's position — "the primary bottleneck is not model intelligence, but context management" — is supported across all sources. The 60-80% context capacity trigger for rotation (Ralph Loop) aligns with Claude Code's 83.5% auto-compact threshold and Praetorian's 75-85% warning zone.

### Theme 5: Similarity-Based Stall Detection Is Emerging

Two concrete approaches:
1. **Output similarity:** Praetorian uses >90% similarity across 3 consecutive iterations
2. **Error fingerprinting:** 0.98 cosine similarity for exact dedup, 0.85 for consolidation
3. **Signal counting:** 220-loop dataset uses mechanical fingerprint counting to prevent rationalization drift

### Theme 6: The Layered Defense Pattern

Every mature system uses multiple safety nets in layers:
- Praetorian: 8-layer defense in depth
- FAILURE.md: 4 failure modes with cascading responses
- Kevin Tan: 5 patterns from circuit breakers to human escalation
- Best practice: backoff → circuit breaker → fallback → human escalation

---

## Specific Numbers That Matter (Summary Table)

| Metric | Value | Source |
|--------|-------|--------|
| Context auto-compact trigger | 83.5-95% | Claude Code |
| Context hard block | 85% | Praetorian |
| Context rotation trigger | 60-80% | Ralph Loop |
| Circuit breaker failure threshold | 3-5 consecutive | Industry consensus |
| Circuit breaker reset timeout | 30-60 seconds | Resilience4j, LLM implementations |
| Half-open probe count | 3-10 | Resilience4j (10), Ruby (3) |
| Max retry attempts | 3-5 | Manus, Resilient-LLM, LangGraph |
| Backoff initial delay | 250ms-2s | Manus (250-750ms), AWS (1-2s) |
| Backoff factor | x2 | Universal |
| Max reasoning cycles | 20 | Kevin Tan patterns |
| Max tokens per execution | 100K | Kevin Tan patterns |
| Iteration hard cap | 20-50 | Ralph Loop |
| SWE-agent cost limit | $1/instance | SWE-agent docs |
| SWE-agent turn limit | 50 | SWE-agent docs |
| Stall detection similarity | >90% across 3 iterations | Praetorian |
| Error dedup threshold | 0.98 cosine (exact), 0.85 (consolidation) | Hermes agent |
| Cascading failure detection | 3 failures in 60s | FAILURE.md |
| Per-command timeout | 2 minutes | Devin |
| Convergence: patches per bug | 10 max | APR research |
| n8n default iterations | 100 | n8n |

---

## Sources

- [Anthropic — Effective Context Engineering for AI Agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Claude API — Compaction](https://platform.claude.com/docs/en/build-with-claude/compaction)
- [Morph — Claude Code Auto-Compact](https://www.morphllm.com/claude-code-auto-compact)
- [Decode Claude — Compaction Deep Dive](https://decodeclaude.com/compaction-deep-dive/)
- [Praetorian — Deterministic AI Orchestration](https://www.praetorian.com/blog/deterministic-ai-orchestration-a-platform-architecture-for-autonomous-development/)
- [Aider — Repository Map](https://aider.chat/docs/repomap.html)
- [ContextBudget — arXiv 2604.01664](https://arxiv.org/html/2604.01664v1)
- [GetMaxim — Context Engineering](https://www.getmaxim.ai/articles/context-engineering-for-ai-agents-production-optimization-strategies/)
- [Resilience4j — CircuitBreaker](https://resilience4j.readme.io/docs/circuitbreaker)
- [Kevin Tan — 5 Error Handling Patterns](https://blog.jztan.com/ai-agent-error-handling-patterns/)
- [FAILURE.md Protocol](https://failure.md/)
- [Skywork — Manus 1.5 Observability](https://skywork.ai/blog/ai-agent/observability-manus-1-5-agents-best-practices/)
- [LangGraph — Retry Policies](https://dev.to/aiengineering/a-beginners-guide-to-handling-errors-in-langgraph-with-retry-policies-h22)
- [Pydantic AI — Durable Execution](https://ai.pydantic.dev/durable_execution/overview/)
- [GitHub — resilient-llm](https://github.com/gitcommitshow/resilient-llm)
- [GitHub — llm-circuit-breaker](https://github.com/hanzalagithub/llm-circuit-breaker)
- [ASDLC.io — Ralph Loop](https://asdlc.io/patterns/ralph-loop/)
- [LinearB — Ralph Loop Agentic Engineering](https://linearb.io/blog/ralph-loop-agentic-engineering-geoffrey-huntley)
- [Saulius.io — Automatic Debugging and Failure Detection](https://saulius.io/blog/automatic-debugging-and-failure-detection-in-ai-agent-systems)
- [DEV — Stuck Agent Detection from 220 Loops](https://dev.to/boucle2026/how-to-tell-if-your-ai-agent-is-stuck-with-real-data-from-220-loops-4d4h)
- [OpenHands — Issue #6357](https://github.com/OpenHands/OpenHands/issues/6357)
- [OpenHands — Issue #6857](https://github.com/All-Hands-AI/OpenHands/issues/6857)
- [SWE-agent — Competitive Runs](https://swe-agent.com/latest/usage/competitive_runs/)
- [Google ADK — Loop Agents](https://adk.dev/agents/workflow-agents/loop-agents/)
- [n8n — Issue #22771](https://github.com/n8n-io/n8n/issues/22771)
- [LangChain — Max Iterations](https://python.langchain.com/v0.1/docs/modules/agents/how_to/max_iterations/)
- [arXiv 2505.02931 — The Art of Repair](https://arxiv.org/html/2505.02931)
- [Nx — Self-Healing CI](https://nx.dev/docs/features/ci-features/self-healing-ci)
- [Devin Docs](https://docs.devin.ai/release-notes)
- [AWS — Timeouts, Retries and Backoff](https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/)
- [Portkey — Retries, Fallbacks, Circuit Breakers](https://portkey.ai/blog/retries-fallbacks-and-circuit-breakers-in-llm-apps/)
- [Hermes Agent — Cognitive Memory](https://github.com/NousResearch/hermes-agent/issues/509)
- [Sparkco — Agent Context Windows 2026](https://sparkco.ai/blog/agent-context-windows-in-2026-how-to-stop-your-ai-from-forgetting-everything)
