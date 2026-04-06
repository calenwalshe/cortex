# Adaptive Execution in Production Multi-Agent Systems — External Research

**Research date:** 2026-04-06
**Purpose:** External research for Cortex pattern-harvest milestone — what production systems do to adapt during execution, and what Cortex can steal.

---

## 1. Multi-Agent Framework Adaptation Patterns

### 1.1 LangGraph — Conditional Edges + Checkpointed Recovery

**Signals detected:** Node failures, state predicates, quality thresholds via conditional edge functions.

**Adaptations:**
- **Conditional edges** evaluate state at runtime and route to different nodes. A function inspects the current state dict and returns the next node name — enabling dynamic rerouting based on intermediate results, error counts, or quality scores.
- **`Command()` object** lets a node return explicit routing instructions mid-execution: branch, reroute, loop, or exit.
- **Node-level RetryPolicy** — configurable per-node with `max_attempts`, `initial_interval`, `backoff_factor`. Operates at a different layer than HTTP retries (e.g., `ChatOpenAI.max_retries`).
- **Checkpointer persistence** — snapshots full graph state at each step. On failure, resume from last successful checkpoint without re-executing prior nodes. Smaller nodes = more frequent checkpoints = less rework.
- **`interrupt()` + resume** — pause execution for human approval before destructive ops. Resume with updated state via same `thread_id`.

**Automatic vs. advisory:** Conditional routing and retries are fully automatic. Interrupts are advisory (human decides).

**Adaptation latency:** Sub-second for conditional edges. Checkpointer resume depends on persistence backend (Postgres: ~50ms, SQLite: ~10ms).

**What Cortex can steal:**
- **Checkpoint-per-phase model.** Cortex already has phase state — add snapshot-before-execute so a failed phase can resume from last good state instead of restarting.
- **Node-level retry with different strategies.** Map to Cortex: retry a plan task with different parameters (e.g., lower complexity tier, different model) instead of identical retry.

Sources:
- [LangGraph Conditional Edges](https://dev.to/jamesli/advanced-langgraph-implementing-conditional-edges-and-tool-calling-agents-3pdn)
- [LangGraph Interrupts](https://docs.langchain.com/oss/python/langgraph/interrupts)
- [LangGraph Error Handling](https://deepwiki.com/langchain-ai/langgraph/3.7-error-handling-and-retry-policies)
- [Dynamic Routing with Command()](https://medium.com/ai-engineering-bootcamp/a-beginners-guide-to-dynamic-routing-in-langgraph-with-command-2c8c0f3ef451)

---

### 1.2 CrewAI — Hierarchical Delegation (and Its Failures)

**Signals detected:** Task completion status, agent capability matching.

**Adaptations:**
- **Hierarchical process** — manager agent delegates tasks dynamically based on workload and capabilities.
- **`allow_delegation=True`** — agents can delegate to other agents mid-task.
- **`allowed_agents` parameter** (2025) — granular control over delegation chains.

**Critical failure mode:** CrewAI's hierarchical mode does NOT enforce conditional branching or true delegation. Instead of selective delegation, it executes all tasks sequentially, causing incorrect agent invocation, overwritten outputs, and inflated latency/token usage. The manager cannot truly reroute mid-task.

**Automatic vs. advisory:** Delegation is automatic but unreliable in practice.

**What Cortex can steal:**
- **Anti-pattern: don't build a "manager" that delegates sequentially.** Cortex's complexity tiers (Phase 06) should route UP FRONT, not mid-execution. Pre-classify, don't re-route.

Sources:
- [CrewAI Hierarchical Process](https://docs.crewai.com/en/learn/hierarchical-process)
- [Why CrewAI's Manager-Worker Architecture Fails](https://towardsdatascience.com/why-crewais-manager-worker-architecture-fails-and-how-to-fix-it/)

---

### 1.3 AutoGen — Dynamic Speaker Selection

**Signals detected:** Message history, pending tasks, custom heuristics, conversation context.

**Adaptations:**
- **`SelectorGroupChat`** — LLM selects next speaker based on shared context. No fixed pipeline.
- **`candidate_func`** — filter eligible speakers per turn (e.g., after agent A, only B or C can speak).
- **Custom `speaker_selection_method`** — deterministic routing via Python function inspecting full message history.

**Automatic vs. advisory:** Fully automatic (LLM-driven or function-driven).

**Adaptation latency:** One LLM call per speaker selection (~200-500ms).

**What Cortex can steal:**
- **Filtered candidate lists per state.** After a repair attempt fails, narrow the next action to {escalate, skip, try-different-approach} — don't re-evaluate all options.

Sources:
- [AutoGen Selector Group Chat](https://microsoft.github.io/autogen/stable//user-guide/agentchat-user-guide/selector-group-chat.html)
- [AutoGen Custom Speaker Selection](https://microsoft.github.io/autogen/0.2/docs/notebooks/agentchat_groupchat_customized/)

---

### 1.4 Google ADK — Workflow Agents + Dispatcher Pattern

**Signals detected:** User intent analysis, sub-agent descriptions, loop exit conditions.

**Adaptations:**
- **Sequential/Parallel/Loop workflow agents** — deterministic orchestration.
- **LLM-driven dispatcher** — central agent routes to specialist based on description matching.
- **`LoopAgent` with conditional exit** — generator-critic cycles until quality threshold met or `escalate=True`.
- **`AgentTool` wrappers** — sub-agents exposed as tools, enabling nested hierarchical delegation.

**Automatic vs. advisory:** Routing is automatic. Human-in-the-loop via custom approval tools.

**No runtime adaptation mechanisms.** ADK focuses on static pattern composition. Workflows don't reconfigure themselves during execution.

**What Cortex can steal:**
- **Generator-critic loop with early exit.** Cortex's repair loop (Phase 02) should have explicit quality thresholds that trigger exit, not just iteration counts.

Sources:
- [ADK Multi-Agent Patterns](https://developers.googleblog.com/developers-guide-to-multi-agent-patterns-in-adk/)
- [ADK Workflow Agents](https://google.github.io/adk-docs/agents/workflow-agents/)

---

### 1.5 OpenAI Agents SDK — Handoffs + Guardrails

**Signals detected:** Guardrail validation results, handoff triggers, tracing events.

**Adaptations:**
- **Handoffs** — agents delegate to specialists for specific tasks. Lightweight, typed.
- **Guardrails** — run input/output validation in parallel with agent execution. Fail fast on check failure.
- **Two guardrail modes:** parallel (best latency, agent may partially execute) or blocking (guardrail completes before agent starts, prevents token waste).
- **Built-in tracing** — captures LLM generations, tool calls, handoffs, guardrails as structured events.

**Automatic vs. advisory:** Guardrails are automatic blockers. Handoffs are LLM-initiated.

**What Cortex can steal:**
- **Parallel guardrails.** Run context-capacity checks (Phase 01) in parallel with task execution, not as a serial gate. If the check fails, kill the task early.
- **Blocking mode for expensive operations.** Before a Codex dispatch, run the complexity check FIRST to avoid wasting tokens.

Sources:
- [OpenAI Agents SDK Guardrails](https://openai.github.io/openai-agents-python/guardrails/)
- [OpenAI Agents SDK Tracing](https://openai.github.io/openai-agents-python/tracing/)

---

### 1.6 OpenAI Codex — Subagent Orchestration

**Signals detected:** Thread completion, approval requests, runtime configuration.

**Adaptations:**
- **Subagent spawning** — parallel specialist agents (explorer, reviewer, docs_researcher) with distinct models and sandbox modes.
- **Consolidated results** — waits for all subagents before responding.
- **Runtime overrides** — sandbox policies and approvals reapplied to child agents.
- **`max_threads=6`, `max_depth=1`** — caps to prevent runaway spawning.
- **Failure surfacing** — unapproved actions fail and error propagates to parent workflow.

**What Cortex can steal:**
- **Thread-level isolation with caps.** Cortex task execution should cap concurrent operations and surface failures to the orchestrating layer rather than silently retrying.

Sources:
- [Codex Subagents](https://developers.openai.com/codex/subagents)
- [Codex Agents SDK Integration](https://developers.openai.com/codex/guides/agents-sdk)

---

## 2. Agent Failure Patterns and Detection

### 2.1 The Compound Probability Problem

An 85% accurate agent fails 80% of the time on a 10-step task (0.85^10 = 19.7% success).

This is the fundamental argument for adaptive execution: forward-only execution is mathematically doomed for multi-step workflows. Systems MUST implement error detection and mid-course correction.

Source: [The Math That's Killing Your AI Agent](https://towardsdatascience.com/the-math-thats-killing-your-ai-agent/)

### 2.2 Eight Production Failure Modes (Arize)

| Mode | Signal | Detection | Adaptation |
|------|--------|-----------|------------|
| Retrieval noise | Agent ignores relevant docs | Span-level usage metrics | Deterministic content blocks |
| Hallucinated tool args | Silent failures, wrong parameter names | Tool output tracing (raw JSON) | Schema validation pre-execution |
| Recursive loops | Hundreds of API calls, tight circular graphs | Trajectory visualization | Webhook waiting vs polling |
| Guardrail bypass | Prohibited commands executed | Independent AI guardrails on output | Deterministic override layer |
| Pre-training bias | Model defaults override context | LLM-as-Judge evaluation | Secondary verification |
| API schema changes | Polite success masking backend failure | Filter logic vs env failures | Specific error retries per code |
| Instruction drift | Rules forgotten in long sessions | Monitor rule compliance over time | Context pinning (re-inject at end) |
| Code gen safety | Destructive paths hallucinated | Regex keyword blocking | Sandbox + read-only permissions |

**Key insight:** Traditional observability fails because HTTP 200 responses mask probabilistic failures. Agents succeed syntactically while failing logically — requires trajectory visualization, not linear log parsing.

Source: [Arize: Common AI Agent Failures](https://arize.com/blog/common-ai-agent-failures/)

### 2.3 AWS Three Failure Modes

| Mode | Signal | Fix |
|------|--------|-----|
| Context overflow | Tool outputs >20K chars, token spikes | **Memory Pointer Pattern** — store large data externally, return 50-byte pointers. Reduced 20M tokens to 1,234. |
| MCP tool timeouts | Calls blocked >7s, 424 errors | **Async job handling** — return job ID immediately, poll with separate tool. Wait drops from 15s to 4s. |
| Reasoning loops | Same tool+args repeated 2+ times, 12-14 calls for 1-call tasks | **DebounceHook** — detect duplicates in 3-call window, cancel via `event.cancel_tool`. Reduced 14 calls to 2. |

Source: [AWS: Why AI Agents Fail](https://dev.to/aws/why-ai-agents-fail-3-failure-modes-that-cost-you-tokens-and-time-1flb)

### 2.4 Agent Loop Detection — Production Standard

The converged approach across multiple production systems:

1. **Hash each iteration** — `(tool_name, normalized_arguments)` tuple hashed
2. **Sliding window** — track last 10 tool calls
3. **Pattern matching** — detect repeating sequences of length 1, 2, or 3
4. **Threshold** — 3 consecutive identical fingerprints = loop detected
5. **Response** — inject steering message: "You are repeating yourself. Try a different approach."
6. **Hard caps** — max iterations (15-25), wall-clock timeout (300s), cost budget ($2/run)
7. **Early stopping** — when approaching limits, prompt model to synthesize without tools

Sources:
- [Anatomy of an Agent Loop](https://stevekinney.com/writing/agent-loops)
- [StrongDM Coding Agent Loop Spec](https://github.com/strongdm/attractor/blob/main/coding-agent-loop-spec.md)
- [AgentWiki Failure Modes](https://agentwiki.org/common_agent_failure_modes)

### 2.5 Complete Agent Failure Catalog

| Failure | Detection Signal | Remediation |
|---------|-----------------|-------------|
| Reasoning failures | Illogical edge-case decisions | Chain-of-thought + human checkpoints + task decomposition |
| Tool use errors | Wrong params, hallucinated tools | Precise descriptions + param validation + tool subset restriction |
| Context overflow | Forgotten instructions, self-contradiction | Sliding windows + summarization + token monitoring |
| Infinite loops | Identical actions, token spikes | Action hash tracking + iteration caps + cost budgets |
| Goal drift | Task migration, tangential outputs | Repeat objectives every N iterations + progress checklists |
| Prompt injection | Unexpected actions after user input | Input sanitization + canary tokens + least-privilege |
| Hallucination | Plausible but wrong facts | RAG grounding + chain-of-verification + constrained decoding |
| Cost runaway | Bills exceeding projections | Real-time cost tracking + model routing + budget enforcement |

Source: [AgentWiki Common Failure Modes](https://agentwiki.org/common_agent_failure_modes)

### 2.6 Scale of the Problem (2025 Data)

- Only 11% of organizations have agentic AI running in production.
- Gartner predicts 40%+ of agentic AI projects started in 2025 will be canceled by end of 2027.
- A multi-agent research tool ran a recursive loop for 11 days undetected, costing $47,000 in API fees.
- AI coding agents introduced security bugs at 1.5-2x the rate of human coders in 2025.

Sources:
- [Composio: Why AI Agent Pilots Fail](https://composio.dev/blog/why-ai-agent-pilots-fail-2026-integration-roadmap)
- [Stack Overflow: Bugs Inevitable with AI Coding Agents?](https://stackoverflow.blog/2026/01/28/are-bugs-and-incidents-inevitable-with-ai-coding-agents/)

---

## 3. Codex/Agent Task Routing

### 3.1 Devin AI — Confidence Scores + Dynamic Re-planning

**Signals detected:** Task complexity, confidence level, CI/lint failures.

**Adaptations:**
- **Confidence scores** (green/yellow/red) — when not green, waits for user approval before proceeding.
- **Dynamic re-planning** (v3.0, 2026) — alters strategy on roadblocks without human intervention.
- **Multi-instance dispatch** — one Devin can dispatch sub-tasks to other instances for parallel execution.
- **Reduced loop behavior** — 2025 updates specifically reduced looping on CI/lint failures.

**Critical failure:** In testing, Devin spent over a day attempting impossible deployments, hallucinating features that didn't exist. The stuck detection was insufficient to recognize fundamental impossibility vs. solvable difficulty.

**What Cortex can steal:**
- **Confidence scoring before execution.** Pre-classify task difficulty and require human approval for low-confidence work. Maps directly to Cortex complexity tiers (Phase 06).
- **Impossibility detection.** Distinguish "hard but solvable" from "impossible given constraints" — this is the gap Devin exposed.

Sources:
- [Devin 2025 Performance Review](https://cognition.ai/blog/devin-annual-performance-review-2025)
- [Answer.AI Devin Review](https://www.answer.ai/posts/2025-01-08-devin.html)

### 3.2 Spotify Honk — Verification Loops at Scale

**Signals detected:** Build failures, test failures, lint errors, LLM judge quality assessment.

**Adaptations:**
- **Independent verifiers** — activate automatically based on codebase contents (e.g., Maven verifier on `pom.xml`).
- **Parsed error feedback** — regex extracts most relevant failure info, feeds back to agent.
- **LLM judge layer** — vetoes ~25% of proposed changes. Agent course-corrects successfully 50% of the time.
- **Iteration limits** — 10 turns per session, 3 session retries total.
- **Graceful degradation** — if agent can't fix, raises flag for human review.

**Automatic vs. advisory:** Fully automatic within iteration limits. Human escalation on failure.

**Scale:** 1,500+ PRs generated.

**What Cortex can steal:**
- **Automatic verifier activation based on content detection.** Cortex should auto-select validators based on what the task touches (e.g., if task modifies hooks, run hook integration tests).
- **10-turn / 3-retry budget.** Hard iteration budgets prevent runaway repairs. Maps directly to Cortex repair budget convergence (Phase 02).
- **Judge veto with course correction.** After a repair attempt, run a quality check that can reject the repair and force a different approach.

Sources:
- [Spotify Honk Part 3: Feedback Loops](https://engineering.atspotify.com/2025/12/feedback-loops-background-coding-agents-part-3)
- [Spotify Honk Part 1](https://engineering.atspotify.com/2025/11/spotifys-background-coding-agent-part-1)

---

## 4. Self-Healing Execution Patterns

### 4.1 Self-Healing CI/CD Architecture

**Signals detected:** Pipeline failure status, flaky test history, deploy metrics.

**Adaptation loop:**
1. Promotion rule detects failure: `result = 'failed' AND branch !~ '^selfheal-.*'` (prevents infinite loops)
2. AI agent receives CI logs via MCP Server
3. Agent applies code modifications, commits to `selfheal-*` branch
4. Standard CI re-executes on modified code
5. On pass: auto-creates PR. On fail: escalate or retry.

**Key innovation:** The `selfheal-*` branch prefix filter is a simple but critical anti-loop mechanism.

**What Cortex can steal:**
- **Tag-based recursion prevention.** When Cortex triggers a repair, mark the repair context so it doesn't trigger another repair cycle. Simple prefix/flag beats complex loop detection.

Sources:
- [Semaphore Self-Healing CI](https://semaphore.io/blog/self-healing-ci)
- [Self-Healing CI/CD Pipelines](https://medium.com/@eren.c.uysal/building-resilient-ci-cd-pipelines-with-automated-self-healing-and-predictive-maintenance-5ebe99d2f358)

### 4.2 Nx Cloud — Task-Graph CI with Flaky Detection

**Signals detected:** Test execution history, agent health, task completion times.

**Adaptations:**
- **Task-graph execution** — CI is a graph of tasks (not VMs). Agents dynamically claim work from shared queue.
- **Flaky test detection** — execution history identifies flaky tests automatically.
- **Retry on different agent** — crucial because flaky failures often reproduce on same infrastructure.
- **Agent replaceability** — failed agents are replaced without pipeline failure.
- **Math:** With 0.1% flaky probability and 2 retries, failure drops to 0.000005%.

**What Cortex can steal:**
- **Retry on different infrastructure/model.** If a task fails with one model, retry with a different one — not the same model again. Analogous to Nx retrying on a different agent.
- **Task-graph over sequential.** Cortex wave execution already does this — validate it's truly parallel, not just sequential with grouping.

Sources:
- [Nx Reliable CI Execution Model](https://nx.dev/blog/reliable-ci-a-new-execution-model-fixing-both-flakiness-and-slowness)
- [Nx Self-Healing CI](https://nx.dev/blog/nx-self-healing-ci)

### 4.3 Circuit Breaker vs. Bulkhead for Agents

| Pattern | Type | Trigger | Mechanism | Agent Application |
|---------|------|---------|-----------|-------------------|
| **Circuit Breaker** | Reactive | 50%+ failure rate over 100-request window | Open (block) -> Half-open (test 1 req after 30s cooldown) -> Close (resume) | Stop calling a failing LLM provider, switch to fallback |
| **Bulkhead** | Proactive | By design (no trigger) | Isolate resources into separate pools | Isolate repair budget from main execution budget |
| **Retry** | Reactive | Transient failure (429, 5xx) | Exponential backoff (1s->2s->4s, max 10s) | Retry tool calls, not entire agent runs |
| **Fallback** | Reactive | Primary timeout/error | Switch to secondary provider/model | GPT-4 -> GPT-3.5 when primary is down |

**Production thresholds (Agentmelt):**

| Metric | Alert Threshold |
|--------|-----------------|
| Retry rate | >10% |
| Fallback activation | >5% |
| Circuit breaker open | >5 minutes |
| Dead letter queue | >50 items/hour |
| End-to-end success | <95% |

**What Cortex can steal:**
- **Bulkhead: separate repair budget from execution budget.** Phase 02 (repair budget convergence) should enforce that repair tokens come from a separate pool — a runaway repair can't starve the main execution.
- **Circuit breaker for model calls.** If a model provider fails 3+ times, stop trying and switch to fallback model for remaining tasks.

Sources:
- [Portkey: Retries, Fallbacks, Circuit Breakers in LLM Apps](https://portkey.ai/blog/retries-fallbacks-and-circuit-breakers-in-llm-apps/)
- [Agentmelt: AI Agent Error Handling](https://agentmelt.com/blog/ai-agent-error-handling-fallback-strategies/)

### 4.4 Fallback Strategy Tiers

Production systems converge on 3-4 fallback levels:

| Level | Strategy | Latency Impact | Example |
|-------|----------|----------------|---------|
| 1. Feature degradation | Process without enrichment, mark as "pending" | None | Skip code review, mark PR as "unreviewed" |
| 2. Quality degradation | Fall back to cheaper/faster model | Slight quality loss | GPT-4 -> GPT-3.5 for non-critical tasks |
| 3. Speed degradation | Switch to batch mode (5-min delays vs. 2-sec real-time) | 150x slower | Queue tasks for batch processing |
| 4. Channel degradation | Escalate to human via alternative channel | Minutes to hours | Slack -> Email -> task log with human follow-up |

Source: [Agentmelt: AI Agent Error Handling](https://agentmelt.com/blog/ai-agent-error-handling-fallback-strategies/)

---

## 5. Observability-to-Action Loops

### 5.1 AIOps Closed-Loop Architecture

**Signals observed:** MELT (Metrics, Events, Logs, Traces).

**Detection:** Pattern mining across log lines + ML correlation to distinguish signal from noise.

**Remediation actions:** Auto-rollback configurations, initiate failovers, execute predefined mitigation strategies.

**Loop:** Observe -> Engage (find patterns, root cause) -> Act (resolve) -> cycle.

**2025 state:** Agentic AI now autonomously executes corrective actions without human intervention. LLMs enable processing unstructured data for anomaly detection at scale.

**What Cortex can steal:**
- **MELT for agent execution.** Cortex event log (Phase 08) should capture metrics (token usage, duration), events (phase transitions, failures), logs (agent output), and traces (execution path). This isn't just logging — it's the foundation for closed-loop adaptation.

Sources:
- [Digitate: Observability and AIOps](https://digitate.com/blog/observability-and-aiops/)
- [AIOps in 2025](https://www.selector.ai/learning-center/aiops-in-2025-4-components-and-4-key-capabilities/)

### 5.2 Chaos Engineering 2.0 — AI-Driven Resilience Testing

**Signals detected:** Blast radius calculations, anomaly detection via SHAP explanations.

**Adaptations:**
- GenAI translates conversational prompts into executable chaos experiments.
- Policy-as-code safeguards prevent experiments from jeopardizing customer trust.
- AI analyzes logs/metrics/alerts to distinguish normal from anomalous behavior.

**What Cortex can steal:**
- **Proactive failure injection in test mode.** Before deploying a new Cortex pattern, inject synthetic failures to verify the adaptation logic works. "What happens if the repair loop exceeds budget?" should be testable.

Source: [Chaos Engineering 2.0](https://www.srao.blog/p/chaos-engineering-the-evolution-from)

---

## 6. Durable Execution: Temporal

**Signals detected:** Activity timeouts, workflow failures, retry exhaustion.

**Adaptations:**
- **Automatic state persistence** — resume from any point after failure.
- **Configurable retry policies** — `initial_interval=1s`, `maximum_interval=30s`, `maximum_attempts=3`.
- **Saga pattern** — compensating transactions in reverse order on failure.
- **Conditional execution** — check intermediate results (e.g., risk scores) and branch dynamically.
- **Non-retryable error exclusion** — skip retries for permanent failures (auth errors, validation errors).

**What Cortex can steal:**
- **Saga compensation for multi-phase execution.** If Phase 3 fails, Cortex should have defined rollback actions for Phases 1-2 (or at minimum, preserve their state). Currently phases are fire-and-forget.
- **Non-retryable error classification.** Some failures should NEVER be retried (auth failures, impossible tasks). Cortex needs an error taxonomy, not just retry counts.

Sources:
- [Temporal + AI Agents](https://dev.to/akki907/temporal-workflow-orchestration-building-reliable-agentic-ai-systems-3bpm)
- [Temporal Saga Pattern](https://temporal.io/blog/saga-pattern-made-easy)

---

## 7. Academic: RL-Based Adaptive Scheduling

### Key findings from 2024-2025 research:

- **Hierarchical MARL** (Wang et al. 2025) decomposes scheduling into job prioritization + machine assignment + transport allocation, with imitation learning for faster convergence.
- **MARLSIO** uses structural entropy optimization for large-scale scheduling with generalization.
- **Adaptive online learning units** integrated within metaschedulers enhance ML scheduling at runtime using RL (arxiv 2509.20520).
- **RL-MOTS** formulates scheduling as Markov Decision Process with priority-aware dynamic queueing and multi-objective reward (latency, energy, cost).

**What Cortex can steal:**
- **Multi-objective reward signal.** Cortex's complexity tiers should optimize across multiple objectives: time-to-completion, token cost, quality score — not just binary pass/fail.
- **Imitation learning from prior successful executions.** Log successful task patterns and use them to bootstrap routing decisions for new tasks.

Sources:
- [MARL for Flexible Shop Scheduling](https://www.frontiersin.org/journals/industrial-engineering/articles/10.3389/fieng.2025.1611512/full)
- [Adaptive Metascheduling with RL](https://arxiv.org/abs/2509.20520)

---

## 8. StrongDM Attractor — Production Agent Loop Spec

The most detailed open-source spec for a production coding agent loop:

| Component | Implementation | Default |
|-----------|---------------|---------|
| Loop detection | Hash (tool_name + args) across sliding window, detect patterns of length 1-3 | Window: 10 calls |
| Response to loop | Inject SteeringTurn warning message | Automatic |
| Command timeout | Per-command enforced | 10s default, 10min max |
| Output truncation | Head+tail split with middle omission, character then line limits | Per-tool configurable |
| Event system | Typed events: TOOL_CALL_START/END, STEERING_INJECTED, LOOP_DETECTION, WARNING, ERROR | Always active |
| Truncation split | Full output to events/UI, truncated to LLM | By design |
| Stop conditions | Natural completion, round limit, turn limit, abort signal, unrecoverable error | 5 distinct exit paths |

**What Cortex can steal:**
- **Steering injection on loop detection.** Instead of just capping iterations, inject a message that tells the model WHY it's stuck and suggests alternatives.
- **Full output to logs, truncated to LLM.** Cortex event log should capture complete execution data even when the LLM only sees summaries.
- **Five distinct exit paths.** Every Cortex execution context needs explicit handling for: success, budget exceeded, time exceeded, abort, and unrecoverable error.

Source: [StrongDM Attractor Coding Agent Loop Spec](https://github.com/strongdm/attractor/blob/main/coding-agent-loop-spec.md)

---

## 9. Production Architecture Patterns (Maxim)

Four coordination models with distinct failure properties:

| Pattern | Failure Mode | Observability | Best For |
|---------|-------------|---------------|----------|
| **Orchestrated** | Single point of failure (orchestrator), but predictable | All paths through orchestrator = easy tracing | Critical workflows needing auditability |
| **Autonomous network** | Individual failures don't cascade; agents route around | Requires correlation IDs + distributed tracing | High-throughput, fault-tolerant workloads |
| **Hierarchical** | Team-level isolation; top coordinator routes around failed teams | Team-level boundaries simplify tracing | Complex multi-domain problems |
| **Hybrid** | Central for critical ops, autonomous for tactical | Mixed tracing needs | Enterprise systems mixing critical + routine |

**What Cortex can steal:**
- **Cortex is orchestrated today.** That's correct for its use case (developer workflow tool with auditability needs). Don't switch to autonomous — the tracing benefits are too valuable.
- **Correlation IDs for multi-phase execution.** Each execution run should have a single ID that traces through all phases, plans, and tasks.

Source: [Maxim: Production Multi-Agent Systems](https://www.getmaxim.ai/articles/best-practices-for-building-production-ready-multi-agent-systems/)

---

## 10. Synthesis: What Cortex Should Steal

### Tier 1 — Direct implementation targets (maps to existing phases)

| Pattern | Source | Cortex Phase | Implementation |
|---------|--------|-------------|----------------|
| **Loop detection via action hashing** | StrongDM, AWS, AgentWiki | Phase 03 (Circuit Breaker) | Hash `(action, args)` tuples, detect repeats in 10-call window, inject steering message |
| **Repair budget as bulkhead** | Circuit breaker literature | Phase 02 (Repair Budget) | Separate token pool for repairs — runaway repair can't starve execution |
| **Iteration budget: 10 turns / 3 retries** | Spotify Honk | Phase 03 (Circuit Breaker) | Hard caps with graceful degradation to human escalation |
| **Retry on different model** | Nx Cloud (retry on different agent) | Phase 02 / Phase 06 | If task fails with one model, retry with different model, not identical retry |
| **Confidence scoring pre-execution** | Devin AI | Phase 06 (Complexity Tiers) | Pre-classify task difficulty, require human approval for low-confidence work |
| **Selfheal-prefix anti-recursion** | Semaphore CI | Phase 02 (Repair Budget) | Mark repair contexts to prevent repair-of-repair cycles |
| **Five exit paths** | StrongDM | Phase 03 (Circuit Breaker) | Success, budget exceeded, time exceeded, abort, unrecoverable — each handled distinctly |

### Tier 2 — Architecture enhancements

| Pattern | Source | Cortex Impact |
|---------|--------|---------------|
| **MELT event taxonomy** | AIOps | Phase 08 (Event Log) should capture Metrics, Events, Logs, Traces — not just logs |
| **Correlation IDs** | Maxim | Single ID traces through all phases of an execution run |
| **Non-retryable error classification** | Temporal | Error taxonomy: transient (retry), permanent (skip), impossible (escalate) |
| **Checkpoint-per-phase** | LangGraph | Snapshot state before execute; resume from last good state on failure |
| **Full output to logs, truncated to context** | StrongDM | Event log captures complete data; LLM context gets summaries |
| **Parallel guardrails** | OpenAI Agents SDK | Run context-capacity checks in parallel with task start; kill early on failure |

### Tier 3 — Future capabilities

| Pattern | Source | Cortex Opportunity |
|---------|--------|--------------------|
| **Generator-critic loops with quality threshold** | Google ADK | Repair loop exits on quality score, not just iteration count |
| **Saga compensation** | Temporal | Multi-phase rollback: if Phase 3 fails, defined cleanup for Phases 1-2 |
| **Multi-objective optimization** | MARL research | Route tasks optimizing for time + cost + quality simultaneously |
| **Proactive failure injection** | Chaos Engineering 2.0 | Test Cortex adaptation logic with synthetic failures |
| **Imitation learning from prior successes** | MARL research | Log successful patterns, bootstrap routing for similar future tasks |

---

## 11. The Compound Probability Argument

Every Cortex phase that adds a step increases failure probability exponentially. With 8 phases at 85% per-phase reliability: **0.85^8 = 27% end-to-end success.** This makes adaptive execution not a nice-to-have but a mathematical necessity. The pattern-harvest milestone directly addresses this by making each phase self-correcting.

---

## 12. Industry-Convergent Architecture

The industry has converged on a common architecture for adaptive agent execution:

```
detect(signal) -> classify(transient|permanent|impossible) -> adapt(retry|reroute|escalate|skip) -> verify(did_it_work) -> log(everything)
```

Cortex's 8-phase pattern-harvest milestone maps onto this:
- **Detect:** Phase 01 (Context Capacity), Phase 07 (Coherence Scoring)
- **Classify:** Phase 06 (Complexity Tiers), Phase 05 (Validator Taxonomy)
- **Adapt:** Phase 02 (Repair Budget), Phase 03 (Circuit Breaker), Phase 04 (Failed Approaches)
- **Verify:** Phase 05 (Completion Promises)
- **Log:** Phase 08 (Event Log)

**The gap is in the classify step.** Most Cortex phases currently treat all failures equally. Adding an error taxonomy (transient/permanent/impossible) and a confidence pre-check would be the highest-leverage single improvement.
