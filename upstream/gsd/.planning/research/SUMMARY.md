# Project Research Summary

**Project:** GSD Autonomous Runner
**Domain:** Autonomous AI coding agent orchestration daemon
**Researched:** 2026-03-09
**Confidence:** HIGH

## Executive Summary

The GSD Autonomous Runner is a daemon that drives Claude Code through GSD project phases (plan, execute, verify, advance) without human intervention, escalating to Telegram at defined gates. The 2026 consensus for building this type of system is the "Ralph Loop" pattern: small bounded tasks, fresh agent sessions per task, all state persisted to disk between sessions. The key architectural insight from research is that the Claude Agent SDK (`@anthropic-ai/claude-agent-sdk`) replaces the originally-assumed CLI spawning approach with a typed, first-class programmatic API for session management, hooks, cancellation, and MCP tool injection -- making the Telegram escalation bridge trivially implementable as an in-process MCP tool rather than cross-language IPC.

The recommended approach is a TypeScript state machine that reads GSD artifacts from disk (STATE.md, ROADMAP.md), invokes the Agent SDK's `query()` with bounded `maxTurns` and `maxBudgetUsd` per invocation, detects gate points and context exhaustion, and escalates via a grammY-based Telegram bot running in the same process. This is architecturally simpler than the PROJECT.md's original assumption of reusing the OpenClaw approvals-bridge (Python, WebSocket-coupled) -- research found that a fresh grammY bot with a separate bot token is approximately 100 lines of code and avoids all cross-language complexity.

The primary risks are context window death spirals (sessions running unbounded until "Prompt too long"), infinite agent loops burning API credits, and compounding architectural errors across phases that go undetected until late. All three are mitigable with established patterns: `maxTurns` caps, loop detection with escalation, and meaningful verification gates with human review after foundational phases. The research is high-confidence because the Agent SDK, Claude Code hooks, and GSD primitives are all well-documented with official sources.

## Key Findings

### Recommended Stack

The stack is TypeScript on Node.js 20 (already installed), centered on the Claude Agent SDK for session management and grammY for Telegram. No new runtime dependencies are needed. The Agent SDK is strictly superior to CLI spawning for every concern: session resume, streaming, cancellation, budget control, hooks, and custom MCP tools are all typed first-class APIs.

**Core technologies:**
- **@anthropic-ai/claude-agent-sdk** (0.2.71): Programmatic Claude Code API -- replaces child_process spawning with typed async generators, native session resume, hooks, and MCP tool support
- **grammY** (1.41.1): TypeScript-native Telegram bot framework -- inline keyboard support for approve/reject buttons, runs in-process via long polling
- **TypeScript** (~5.7): Type safety for the state machine and Agent SDK message types
- **zod** (3.x): Schema validation for state parsing and Agent SDK MCP tool definitions
- **pino** (~9.6): Structured JSON logging for daemon operation

**Key stack decisions from research:**
- Use a separate Telegram bot token (not shared with approvals-bridge) to avoid polling conflicts
- Do NOT reuse the OpenClaw approvals-bridge -- it is tightly coupled to OpenClaw's WebSocket protocol
- Do NOT use pm2/forever -- the daemon IS the process manager; use systemd for the daemon itself
- Do NOT use bull/bullmq -- in-memory state machine with disk persistence, not a Redis job queue

### Expected Features

**Must have (table stakes):**
- Headless session management via Agent SDK `query()`
- Context window lifecycle -- bounded sessions via `maxTurns`, checkpoint and restart
- Persistent state via STATE.md/ROADMAP.md (GSD provides this)
- Phase/task loop -- plan, execute, verify, advance driven from ROADMAP.md
- Telegram approval gates with inline approve/reject buttons
- Auto-approve between gates (`permissionMode: 'bypassPermissions'`)
- Error handling with retry and escalation
- Structured logging and session output capture
- Graceful shutdown on SIGTERM

**Should have (differentiators):**
- GSD-native workflow integration (not generic prompts -- first-class GSD commands)
- Smart checkpoint via `/gsd:pause-work` (richer than raw state dumps)
- Cost/token tracking per session
- Progress notifications between gates
- Run summary report at completion
- Git safety guardrails via Agent SDK hooks

**Defer (v2+):**
- Confidence-based escalation (parsing agent output for uncertainty -- complex, low ROI for v1)
- Multi-project sequential queue
- Remote start via Telegram "go" command

### Architecture Approach

The system is four components in a single Node.js process: a state machine that reads disk artifacts to decide the next GSD command, a session manager that invokes the Agent SDK and handles lifecycle events, a gate controller that sends Telegram messages and blocks until button press, and a daemon loop that wires them together. State lives exclusively on disk -- the daemon holds no GSD state in memory, making session restarts safe. Context exhaustion is handled by tracking compaction count per session (via hooks) and checkpointing when a threshold is hit.

**Major components:**
1. **State Machine** -- reads STATE.md/ROADMAP.md, determines next GSD command (pure function)
2. **Session Manager** -- invokes Agent SDK `query()`, streams messages, handles lifecycle hooks
3. **Gate Controller** -- sends Telegram inline keyboards via grammY, returns Promise that resolves on button press
4. **Daemon Loop** -- top-level orchestrator wiring the three above in a loop

### Critical Pitfalls

1. **Context window death spiral** -- Sessions run unbounded until "Prompt too long" and become permanently unusable. Prevent with `maxTurns` (50-100) on every invocation; treat every session as disposable.
2. **Infinite loop / stuck agent** -- Claude retries the same failing action indefinitely, burning API credits. Prevent with loop detection (track last N tool calls), `maxTurns` ceiling, and escalation to Telegram on stuck detection.
3. **State corruption on restart** -- New session reads stale or partially-written STATE.md after a crash. Prevent with state validation between sessions and idempotent state transitions.
4. **Telegram approval deadlock** -- Daemon blocks forever waiting for a button press that never comes. Prevent with configurable timeouts (4h default), persistent pending approvals, and reminder messages.
5. **Compounding error across phases** -- Subtle Phase 1 mistakes compound through later phases undetected. Prevent with meaningful verification gates (not just "tests pass") and mandatory human review after foundational phases.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: State Machine and Session Core
**Rationale:** The state machine is a pure function with no I/O dependencies -- fully testable with fixture files. The session manager is the highest-complexity component and the foundation everything else depends on. Both must exist before any integration work.
**Delivers:** Working state machine that reads GSD artifacts and determines next action; session manager that invokes Agent SDK with bounded turns, captures output, handles errors.
**Addresses:** Headless session management, persistent state, context window lifecycle, phase loop, auto-approve, error handling, graceful shutdown, logging.
**Avoids:** Context window death spiral (maxTurns from day one), state corruption (validation between sessions), permission bypass damage (allowedTools per phase type).

### Phase 2: Telegram Integration
**Rationale:** Gate controller depends on session manager output to know when to escalate. Telegram is the human-in-the-loop mechanism -- without it, the runner is fully autonomous with no oversight (unusable in practice).
**Delivers:** grammY bot with inline approve/reject buttons, approval timeout handling, progress notifications, daemon heartbeat.
**Addresses:** Telegram approval gates, progress notifications, escalation UX.
**Avoids:** Telegram approval deadlock (timeouts from the start), silent failures (heartbeat notifications).

### Phase 3: GSD Workflow Integration
**Rationale:** With the core loop and Telegram working, this phase wires in GSD-specific intelligence: gate detection patterns, verification criteria injection, smart checkpointing via `/gsd:pause-work`, and the full phase progression logic.
**Delivers:** Full GSD phase loop (plan -> execute -> verify -> advance), gate detection from session output, meaningful verification criteria, smart checkpoint/resume.
**Addresses:** GSD workflow integration, smart checkpoint, meaningful verification gates.
**Avoids:** Compounding error across phases (architectural verification at gates, not just test results).

### Phase 4: Observability and Safety
**Rationale:** Polish phase -- once the core loop is proven stable, add cost tracking, run summaries, git guardrails, and loop detection refinement.
**Delivers:** Per-session cost tracking, end-of-run summary report, git safety hooks, refined loop/stuck detection.
**Addresses:** Cost/token tracking, run summary report, git safety guardrails.
**Avoids:** Infinite loop cost blowouts (budget limits + loop detection), unsafe git operations (hook-based guardrails).

### Phase Ordering Rationale

- **Phase 1 before Phase 2:** Telegram integration needs session output to detect gates -- the session manager must exist first.
- **Phase 2 before Phase 3:** GSD-specific workflow logic needs the gate controller to escalate at GSD-defined checkpoints.
- **Phase 3 before Phase 4:** Observability and safety features are polish on a working system, not prerequisites.
- **Architecture research confirms this order:** the build dependency graph (state machine -> session manager -> gate controller -> daemon loop) maps directly to this phase sequence.
- **Pitfall research validates front-loading safety:** context limits, state validation, and basic error handling must be in Phase 1, not deferred.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2:** Telegram integration specifics -- grammY inline keyboard callback routing, long polling configuration, timeout implementation patterns. The approvals-bridge pivot (from reuse to fresh bot) means no existing code to reference.
- **Phase 3:** GSD gate detection -- need to catalog exact output patterns from each GSD command to build reliable gate detectors. May require running each command and capturing output.

Phases with standard patterns (skip research-phase):
- **Phase 1:** Session management via Agent SDK is well-documented with official examples. State machine is pure logic with no unknowns.
- **Phase 4:** Cost tracking, git hooks, and logging are all established patterns with clear implementations.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Agent SDK verified against official docs and npm. grammY verified. All versions confirmed on target server. |
| Features | HIGH | Feature landscape mapped against 5 competitors. Clear MVP definition with dependency graph. |
| Architecture | HIGH | Component boundaries, data flow, and build order well-defined. Anti-patterns documented with alternatives. |
| Pitfalls | MEDIUM-HIGH | Critical pitfalls verified against official docs and community reports. Some Claude Code CLI behaviors (stream-json field structure) need validation during implementation. |

**Overall confidence:** HIGH

### Gaps to Address

- **Agent SDK `query()` in practice:** Research verified the API surface from docs, but no prototype has been built. The exact message type sequence from `query()` needs validation in Phase 1 -- run a simple test invocation early.
- **GSD command output patterns:** Gate detection relies on recognizing structured output from GSD commands. These patterns are not formally documented -- need to catalog them during Phase 3 planning.
- **Compaction count as context proxy:** The strategy of tracking compaction events to decide when to restart is theoretically sound but untested. The threshold (2-3 compactions) is a guess -- needs empirical tuning in Phase 1.
- **stream-json field structure:** The exact NDJSON fields emitted by `--output-format stream-json` are documented at a high level but the full schema for all event types needs validation.

## Sources

### Primary (HIGH confidence)
- [Claude Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview) -- query() API, session management, hooks, MCP tools
- [Claude Agent SDK TypeScript reference](https://platform.claude.com/docs/en/agent-sdk/typescript) -- full Options interface, Query methods, message types
- [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference) -- flags, permission modes, output formats
- [Claude Code Hooks reference](https://code.claude.com/docs/en/hooks) -- PreCompact, Stop, SessionEnd event schemas
- [@anthropic-ai/claude-agent-sdk npm](https://www.npmjs.com/package/@anthropic-ai/claude-agent-sdk) -- version 0.2.71
- [grammY docs and comparison](https://grammy.dev/resources/comparison) -- framework tradeoffs
- Existing approvals-bridge source analysis -- determined reuse is not viable
- Local server inspection -- Node 20.20.0, Claude Code 2.1.71 confirmed

### Secondary (MEDIUM confidence)
- [Context engineering for coding agents (Martin Fowler)](https://martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html) -- context window management patterns
- [Ralph Loop pattern](https://dev.to/alexandergekov/2026-the-year-of-the-ralph-loop-agent-1gkj) -- fresh context per iteration
- [Human relay pattern (tryb.dev)](https://tryb.dev/blog/human-in-the-loop-for-ai-agents) -- pause, notify, wait, resume
- [Agent stuck detection from 220 loops](https://dev.to/boucle2026/how-to-tell-if-your-ai-agent-is-stuck-with-real-data-from-220-loops-4d4h) -- loop detection patterns
- [AutoCompact behavior issue #18264](https://github.com/anthropics/claude-code/issues/18264) -- auto-compact unreliability
- [Prompt too long issue #22013](https://github.com/anthropics/claude-code/issues/22013) -- session death behavior

---
*Research completed: 2026-03-09*
*Ready for roadmap: yes*
