# Feature Research

**Domain:** Autonomous AI Coding Agent Orchestration / Daemon Runner
**Researched:** 2026-03-09
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Headless session management | Core purpose -- launch Claude Code non-interactively, capture output, detect completion | MEDIUM | Claude Code's `-p` flag and `--output-format json` are the primitives. Runner wraps these in a loop with process lifecycle management. |
| Context window lifecycle | Sessions hit context limits and degrade. Every orchestrator handles this. | HIGH | Detect ~60% utilization ("context rot" threshold), checkpoint state to disk, kill session, spawn fresh one that re-orients from persisted state. The Ralph Loop pattern (fresh context per iteration, read evidence from filesystem) is the 2026 standard. |
| Persistent state across restarts | Without this, a restart = starting over. Useless for multi-hour work. | LOW | GSD already provides STATE.md + ROADMAP.md. The runner reads these to re-orient. This is table stakes because it's what makes the "loop" work. |
| Phase/task loop execution | The daemon must drive work through stages autonomously -- plan, execute, verify, advance. | MEDIUM | State machine: read STATE.md -> determine current phase -> invoke correct GSD command -> parse result -> advance or escalate. |
| Human-in-the-loop approval gates | Every serious orchestrator has these. Fully autonomous with zero oversight is unusable in practice. | MEDIUM | Pause at defined gates, notify human, wait for approve/reject, resume. The "human relay pattern" is standard: pause execution, send question, wait for response. |
| Error handling and retry | Agent sessions crash, commands fail, APIs timeout. Must not die on first error. | MEDIUM | Retry with backoff for transient failures. Distinguish between retriable errors (process crash, API timeout) and semantic failures (tests fail, verification rejects). Different recovery strategy for each. |
| Logging and audit trail | Must be able to see what the daemon did, when, and why. Essential for debugging and trust. | LOW | Log every session start/stop, every GSD command invoked, every gate decision, every escalation. Structured logs (JSON) preferred for parseability. |
| Session output capture | Need to see what Claude actually produced in each session. | LOW | Capture stdout/stderr from each `claude -p` invocation. Store per-session for review. |
| Graceful shutdown | Must handle SIGTERM/SIGINT without corrupting state. | LOW | On signal: finish current atomic operation, checkpoint state, exit cleanly. |
| Auto-approve for non-gate steps | Between gates, the agent should work without asking permission for every file write. | LOW | `--dangerously-skip-permissions` or equivalent. GSD's YOLO mode between gates. Without this, the daemon stops every 30 seconds for trivial approvals. |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| GSD workflow integration | Unlike generic orchestrators, this one understands GSD's phase structure natively -- plan-phase, execute-phase, verify-work are first-class concepts, not arbitrary prompts | MEDIUM | This is the core differentiator. The runner isn't a generic "run Claude in a loop" tool -- it understands the GSD workflow graph and navigates it. |
| Telegram bidirectional escalation with inline buttons | Mobile-friendly approval UX. Most orchestrators use Slack or dashboards. Telegram inline buttons = tap to approve from your phone. | MEDIUM | Reuses existing OpenClaw Telegram bridge. Approve/reject buttons, not free-text parsing. Response piped back to unblock the runner. |
| Smart checkpoint via /gsd:pause-work | Richer context preservation than raw state dumps. GSD's pause-work captures continuation context, not just "what phase am I on." | LOW | This is better than what most orchestrators do (dump raw state). GSD's pause-work writes a structured continuation file. |
| Cost/token tracking per session | Know how much each phase costs. Essential for budgeting autonomous runs. | LOW | Parse Claude Code's session stats or use ccusage. Aggregate per-phase, per-project. Report at completion. |
| Confidence-based escalation | Auto-escalate when the agent is uncertain, not just at predefined gates. Hook into Claude's output to detect hedging, errors, or low-confidence signals. | HIGH | Goes beyond fixed gates. Parse agent output for patterns like "I'm not sure", test failures, repeated retries. Escalate dynamically. |
| Git safety guardrails | Prevent the autonomous agent from force-pushing, deleting branches, or committing secrets. | LOW | Use Claude Code hooks (PreToolUse) to block dangerous git operations. Whitelist allowed commands. |
| Progress notifications | Periodic "still working, completed X of Y phases" updates to Telegram. Not just gate approvals. | LOW | Lightweight but high-value for trust. User knows the daemon is alive and making progress without checking logs. |
| Run summary report | At completion, send a structured summary: phases completed, time per phase, cost, errors encountered, commits made. | LOW | Aggregated from logs. Sent to Telegram as final message. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Multi-project parallel orchestration | "Run 5 projects at once" | Massive complexity explosion for v1: resource contention, context switching, session management, error isolation. Also, API rate limits and token budgets make parallel sessions expensive and unpredictable. | Single project, single session. Queue projects sequentially if needed. |
| Free-text Telegram replies | "Let me type instructions back to the agent" | Turns a daemon into a chat interface. Parsing natural language intent, injecting it mid-session, and handling ambiguity is a different product entirely. | Approve/reject buttons only. For complex feedback, pause the daemon and intervene manually. |
| Web dashboard UI | "I want a React app to monitor the daemon" | Massive scope increase for marginal value. The operator is one person on a phone. A dashboard serves teams, not solo operators. | Telegram notifications + structured log files. If you need to dig deeper, read the logs. |
| Auto-resume on boot | "Start running when the server restarts" | Silent autonomous execution after unplanned restarts is dangerous. State may be inconsistent, network may be partial, you may not even know it's running. | Manual start trigger. Deliberate decision to begin autonomous execution. |
| Custom workflow definitions | "Let me define my own phase graph" | Over-engineering for v1. GSD already defines the workflow. Building a generic workflow engine is a different project. | Hardcode the GSD phase loop. If the workflow changes, update the runner code. |
| Model selection / switching | "Use GPT-4 for planning, Claude for coding" | Multi-model orchestration adds config complexity, different API formats, different capabilities, different error modes. Not worth it when Claude Code is the execution engine. | Single model (Claude Code). The runner is a Claude Code runner, not a generic LLM orchestrator. |
| Real-time streaming output | "Show me what Claude is typing in real-time" | Requires WebSocket infrastructure, a UI to display it, and adds latency to the runner loop. The value is curiosity, not control. | Capture output per-session, review after completion. Progress notifications cover the "is it alive?" need. |
| Automatic git push / deploy | "Push to main and deploy when done" | Autonomous push to production without human review is reckless. Even with tests, the human gate before deployment is important. | Create PR or leave commits on branch. Human reviews and pushes. |

## Feature Dependencies

```
[Headless session management]
    |-- requires --> [Auto-approve for non-gate steps]
    |-- requires --> [Session output capture]
    |-- requires --> [Graceful shutdown]

[Context window lifecycle]
    |-- requires --> [Headless session management]
    |-- requires --> [Persistent state across restarts]
    |-- enhanced-by --> [Smart checkpoint via /gsd:pause-work]

[Phase/task loop execution]
    |-- requires --> [Headless session management]
    |-- requires --> [Persistent state across restarts]
    |-- requires --> [Context window lifecycle]

[Human-in-the-loop approval gates]
    |-- requires --> [Phase/task loop execution]
    |-- enhanced-by --> [Telegram bidirectional escalation]
    |-- enhanced-by --> [Confidence-based escalation]

[Error handling and retry]
    |-- requires --> [Headless session management]
    |-- requires --> [Logging and audit trail]
    |-- enhanced-by --> [Confidence-based escalation]

[Progress notifications]
    |-- requires --> [Telegram bidirectional escalation]
    |-- requires --> [Phase/task loop execution]

[Run summary report]
    |-- requires --> [Logging and audit trail]
    |-- requires --> [Cost/token tracking per session]

[Git safety guardrails]
    |-- independent, can be added anytime via Claude Code hooks
```

### Dependency Notes

- **Context window lifecycle requires headless session management:** You need to be able to kill and respawn sessions before you can manage their lifecycle.
- **Phase/task loop requires context window lifecycle:** Long-running phase execution will exceed context windows, so the loop must handle restarts mid-phase.
- **Human-in-the-loop requires phase loop:** Gates are defined in terms of phases. No phases = no gates.
- **Telegram escalation enhances approval gates:** The gates work with any notification mechanism, but Telegram makes them mobile-friendly.
- **Confidence-based escalation enhances both gates and error handling:** It's an overlay that makes both smarter, but neither depends on it.
- **Git safety guardrails are independent:** Implemented via Claude Code hooks (PreToolUse), can be added at any point without touching the runner.

## MVP Definition

### Launch With (v1)

Minimum viable product -- what's needed to validate the concept of autonomous GSD execution.

- [ ] Headless session management -- launch `claude -p`, capture output, detect completion
- [ ] Persistent state via STATE.md/ROADMAP.md -- re-orient after restart
- [ ] Context window lifecycle -- detect filling, checkpoint, restart fresh
- [ ] Phase loop -- plan -> execute -> verify -> advance, driven from ROADMAP.md
- [ ] Telegram approval gates -- inline approve/reject buttons at GSD gates
- [ ] Auto-approve between gates -- `--dangerously-skip-permissions`
- [ ] Error handling with retry -- don't die on first transient failure
- [ ] Logging -- structured log of all actions
- [ ] Graceful shutdown -- handle SIGTERM, checkpoint, exit clean
- [ ] Manual CLI start trigger

### Add After Validation (v1.x)

Features to add once the core loop is proven stable.

- [ ] Cost/token tracking per session -- once you know it works, track how much it costs
- [ ] Progress notifications -- periodic Telegram updates between gates
- [ ] Run summary report -- end-of-run summary with stats
- [ ] Smart checkpoint via /gsd:pause-work -- richer continuation context
- [ ] Git safety guardrails via hooks -- block dangerous operations

### Future Consideration (v2+)

Features to defer until the autonomous runner is battle-tested.

- [ ] Confidence-based escalation -- requires parsing agent output for uncertainty signals, complex to get right
- [ ] Multi-project sequential queue -- run projects back-to-back
- [ ] Telegram "go" command to start runs remotely -- convenience, not essential

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Headless session management | HIGH | MEDIUM | P1 |
| Context window lifecycle | HIGH | HIGH | P1 |
| Persistent state across restarts | HIGH | LOW | P1 |
| Phase/task loop execution | HIGH | MEDIUM | P1 |
| Telegram approval gates | HIGH | MEDIUM | P1 |
| Auto-approve between gates | HIGH | LOW | P1 |
| Error handling and retry | HIGH | MEDIUM | P1 |
| Logging and audit trail | MEDIUM | LOW | P1 |
| Session output capture | MEDIUM | LOW | P1 |
| Graceful shutdown | MEDIUM | LOW | P1 |
| GSD workflow integration | HIGH | MEDIUM | P1 |
| Smart checkpoint | MEDIUM | LOW | P2 |
| Cost/token tracking | MEDIUM | LOW | P2 |
| Progress notifications | MEDIUM | LOW | P2 |
| Run summary report | MEDIUM | LOW | P2 |
| Git safety guardrails | MEDIUM | LOW | P2 |
| Confidence-based escalation | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch (the autonomous loop doesn't work without these)
- P2: Should have, add when the loop is stable (polish and observability)
- P3: Nice to have, future consideration (advanced intelligence)

## Competitor Feature Analysis

| Feature | Auto-Claude | Devin | Overstory | Claude Agent Teams | GSD Runner (Ours) |
|---------|-------------|-------|-----------|-------------------|-------------------|
| Multi-session parallel | Yes (12 terminals) | Yes (cloud) | Yes (worktrees) | Yes (teammates) | No -- single session by design |
| UI | Electron/React desktop | Web app | CLI + tmux | CLI | CLI + Telegram |
| Human approval | Manual review | PR review | Manual review | Interactive | Telegram inline buttons |
| Context management | Multi-session | Cloud-managed | Per-worktree | Per-teammate | Checkpoint + restart loop |
| Workflow structure | Spec -> Plan -> Code -> QA | Free-form tasks | Task assignment | Lead/teammate | GSD phases (plan -> execute -> verify) |
| Git isolation | Worktrees | Branches | Worktrees + FIFO merge | Worktrees | Single branch (v1) |
| Error recovery | QA agent loop | Self-correction | Watchdog + triage | Retry | Retry + escalate |
| Cost tracking | No | Cloud billing | No | No | Per-session tracking |
| Target user | Teams | Teams/Enterprise | Teams | Teams | Solo operator |

**Key insight:** Every competitor targets teams. Our runner targets a solo operator running autonomous GSD projects from their phone via Telegram. This is a genuinely different use case -- simpler infra, simpler UX, but the same core challenge of keeping an autonomous agent on track.

## Sources

- [Claude Code Headless Mode docs](https://code.claude.com/docs/en/headless) -- official headless/automation API
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide) -- lifecycle hooks for automation
- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams) -- multi-agent orchestration (experimental)
- [Auto-Claude](https://github.com/AndyMik90/Auto-Claude) -- autonomous multi-session framework
- [Overstory](https://github.com/jayminwest/overstory) -- multi-agent orchestration with worktrees
- [Composio Agent Orchestrator](https://github.com/ComposioHQ/agent-orchestrator) -- parallel coding agent orchestrator
- [Devin AI](https://devin.ai/) -- autonomous AI software engineer
- [Context Engineering for Coding Agents (Martin Fowler)](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html) -- context window management patterns
- [Ralph Loop pattern](https://dev.to/alexandergekov/2026-the-year-of-the-ralph-loop-agent-1gkj) -- fresh context per iteration, read from filesystem
- [Claude Code Cost Management](https://code.claude.com/docs/en/costs) -- token tracking and limits
- [ccusage](https://ccusage.com/) -- CLI tool for Claude Code usage analysis
- [Human Relay Pattern](https://tryb.dev/blog/human-in-the-loop-for-ai-agents) -- pause, notify, wait, resume

---
*Feature research for: Autonomous AI Coding Agent Orchestration / Daemon Runner*
*Researched: 2026-03-09*
