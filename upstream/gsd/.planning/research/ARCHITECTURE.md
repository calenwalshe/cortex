# Architecture Research

**Domain:** Autonomous Claude Code orchestration daemon
**Researched:** 2026-03-09
**Confidence:** HIGH

## System Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                      Telegram Layer                              │
│  ┌───────────────┐         ┌──────────────────┐                  │
│  │ Approvals     │◄───────►│ Admin (you)      │                  │
│  │ Bridge        │ buttons │ on Telegram       │                  │
│  └──────┬────────┘         └──────────────────┘                  │
│         │ HTTP callback                                          │
├─────────┼────────────────────────────────────────────────────────┤
│         ▼              Runner Daemon                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐       │
│  │ Gate          │  │ Session      │  │ State            │       │
│  │ Controller    │  │ Manager      │  │ Machine          │       │
│  │ (escalation)  │  │ (lifecycle)  │  │ (GSD loop)       │       │
│  └──────┬────────┘  └──────┬───────┘  └────────┬─────────┘       │
│         │                  │                    │                 │
├─────────┼──────────────────┼────────────────────┼─────────────────┤
│         ▼                  ▼                    ▼                 │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │              Claude Code CLI (child process)             │    │
│  │  claude -p --output-format stream-json                   │    │
│  │  --dangerously-skip-permissions --session-id <uuid>      │    │
│  └──────────────────────────────────────────────────────────┘    │
├──────────────────────────────────────────────────────────────────┤
│                      Disk State                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐  ┌────────────┐   │
│  │ STATE.md │  │ROADMAP.md│  │.continue-here│  │ runner.json│   │
│  └──────────┘  └──────────┘  └──────────────┘  └────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **State Machine** | Reads STATE.md/ROADMAP.md, determines current GSD phase, selects next GSD command to invoke | Pure function: `(state_on_disk) => next_action` |
| **Session Manager** | Spawns Claude Code as child process, streams output, detects completion/failure, handles context window exhaustion via PreCompact hooks | Node.js `child_process.spawn` with NDJSON parsing |
| **Gate Controller** | Detects GSD gate points (roadmap approval, verification checkpoints), sends Telegram messages with inline buttons, blocks until response | HTTP POST to existing approvals-bridge, or direct Telegram bot API |
| **Runner Daemon** | Top-level loop orchestrating the three above: start session, run until gate or completion, handle gate, advance, repeat | Main process entry point, long-running |
| **Disk State** | STATE.md + ROADMAP.md + .continue-here.md as the single source of truth across session restarts | Files on disk, read/written by Claude Code during GSD commands |

## Recommended Project Structure

```
gsd-runner/
├── bin/
│   └── gsd-runner.js         # CLI entry point
├── src/
│   ├── daemon.js             # Main loop / orchestrator
│   ├── state-machine.js      # GSD state reader + next-action logic
│   ├── session.js            # Claude Code process lifecycle
│   ├── gate.js               # Telegram escalation + blocking wait
│   ├── hooks/                # Claude Code hook scripts
│   │   ├── on-pre-compact.sh # Fires when context window fills
│   │   ├── on-stop.sh        # Fires when Claude stops responding
│   │   └── on-session-end.sh # Cleanup on session termination
│   └── util/
│       ├── state-parser.js   # Parse STATE.md / ROADMAP.md
│       └── logger.js         # Structured logging
├── config/
│   └── default.json          # Config (Telegram tokens, paths, timeouts)
├── test/
│   ├── state-machine.test.js
│   ├── session.test.js
│   └── gate.test.js
└── package.json
```

### Structure Rationale

- **bin/:** Thin CLI wrapper. Can be invoked manually or by systemd.
- **src/:** Four core modules with clear single responsibilities. No module exceeds ~200 lines.
- **hooks/:** Shell scripts registered with Claude Code's hook system. They communicate back to the daemon via IPC (file or HTTP).
- **config/:** Environment-specific settings. No secrets in code -- uses existing .env or `pass`.

## Architectural Patterns

### Pattern 1: Hooks-Based Lifecycle Detection (not output parsing)

**What:** Use Claude Code's hook system (`PreCompact`, `Stop`, `SessionEnd`) for lifecycle events instead of parsing stream-json output for context window heuristics.

**When to use:** Always. This is the officially supported mechanism.

**Trade-offs:** Hooks are reliable and event-driven. The downside is they run as separate processes and communicate back to the daemon asynchronously, requiring an IPC channel.

**Why this matters:**
- `PreCompact` with matcher `auto` fires when context window is filling -- this IS the context window detection mechanism. No need to count tokens or guess.
- `Stop` fires when Claude finishes responding -- the `last_assistant_message` field gives you the output without parsing NDJSON.
- `SessionEnd` fires on termination for cleanup.

**Implementation approach:**
```javascript
// Hook script (on-pre-compact.sh) writes to a named pipe or HTTP endpoint
// that the daemon monitors. When PreCompact(auto) fires:
//
// 1. Hook script signals daemon: "context window filling"
// 2. Daemon sets a flag: next Stop event triggers checkpoint
// 3. On Stop: daemon reads last_assistant_message, runs /gsd:pause-work
// 4. Daemon kills session, starts fresh with /gsd:resume-work

// IPC via HTTP (simplest approach -- daemon runs a tiny HTTP server):
// Hook script:
//   curl -s http://localhost:${GSD_RUNNER_PORT}/hook/pre-compact
```

### Pattern 2: State Machine Driven by Disk Artifacts

**What:** The daemon never holds GSD state in memory. It reads STATE.md and ROADMAP.md from disk before every decision. Claude Code writes these files during GSD commands.

**When to use:** Always. This is what makes session restarts safe.

**Trade-offs:** Slightly slower (disk reads), but eliminates state synchronization bugs entirely. The disk IS the state.

**Key insight from GSD commands:**
- `/gsd:pause-work` writes `.continue-here.md` with exact task position
- `/gsd:resume-work` reads it and restores context
- `STATE.md` tracks phase position
- `ROADMAP.md` tracks phase definitions and order

```javascript
// Before spawning a session:
function determineNextAction(projectDir) {
  const state = parseStateFile(`${projectDir}/.planning/STATE.md`);
  const roadmap = parseRoadmapFile(`${projectDir}/.planning/ROADMAP.md`);
  const continueFile = findContinueHere(projectDir);

  if (continueFile) return { action: 'resume', prompt: '/gsd:resume-work' };
  if (state.currentPhase && !state.phaseComplete) return { action: 'execute', prompt: '/gsd:execute-phase' };
  if (state.currentPhase && state.phaseComplete && !state.verified) return { action: 'verify', prompt: '/gsd:verify-work' };
  if (state.allPhasesComplete) return { action: 'done' };
  return { action: 'next-phase', prompt: '/gsd:plan-phase' };
}
```

### Pattern 3: Gate Detection via Output Scanning

**What:** Scan Claude Code's output (via `Stop` hook's `last_assistant_message` or stream-json) for GSD gate indicators -- moments where human approval is needed.

**When to use:** At the boundary between automated execution and human decision points.

**Trade-offs:** Relies on Claude Code producing recognizable gate signals. GSD commands have structured output, so this is reliable for known patterns (roadmap approval prompts, verification reports).

**How gates are detected:**
```javascript
// GSD commands produce structured output at gates:
// - /gsd:create-roadmap ends with "Ready to proceed?" or similar
// - /gsd:verify-work ends with a verification report
// - /gsd:define-requirements ends asking for confirmation
//
// The daemon scans for these patterns in Stop hook output:
const GATE_PATTERNS = [
  { pattern: /ready to proceed|approve.*roadmap/i, gate: 'roadmap-approval' },
  { pattern: /verification.*report|verify.*complete/i, gate: 'verification' },
  { pattern: /requirements.*confirm/i, gate: 'requirements-approval' },
];
```

## Data Flow

### Main Execution Loop

```
┌──────────┐     ┌───────────┐     ┌──────────────┐     ┌────────────┐
│  Daemon   │────►│  Read     │────►│  State       │────►│  Spawn     │
│  Loop     │     │  Disk     │     │  Machine     │     │  Claude    │
│  Start    │     │  State    │     │  Decision    │     │  Session   │
└──────────┘     └───────────┘     └──────────────┘     └─────┬──────┘
                                                              │
                 ┌──────────────────────────────────────────────┘
                 ▼
┌──────────────────────┐     ┌──────────────┐     ┌────────────────┐
│  Claude Code runs    │────►│  Hook fires  │────►│  Daemon        │
│  GSD command         │     │  (Stop/       │     │  processes     │
│  autonomously        │     │  PreCompact)  │     │  hook signal   │
└──────────────────────┘     └──────────────┘     └───────┬────────┘
                                                          │
                          ┌───────────────────────────────┘
                          ▼
                 ┌─── Is it a gate? ───┐
                 │                     │
                YES                   NO
                 │                     │
                 ▼                     ▼
        ┌──────────────┐      ┌──────────────┐
        │  Send to     │      │  Loop back   │
        │  Telegram    │      │  to start    │
        │  + wait      │      │  (next cmd)  │
        └──────┬───────┘      └──────────────┘
               │
               ▼
        ┌──────────────┐
        │  Approved?   │──NO──► Pause / abort
        │              │
        └──────┬───────┘
               │ YES
               ▼
        ┌──────────────┐
        │  Continue    │
        │  loop        │
        └──────────────┘
```

### Context Window Exhaustion Flow

```
Claude Code running
        │
        ▼
Context window fills
        │
        ▼
PreCompact(auto) hook fires ──► daemon HTTP endpoint receives signal
        │
        ▼
Claude auto-compacts (cannot prevent this)
        │
        ▼
SessionStart(compact) hook fires ──► daemon notes compaction happened
        │
        ▼
Claude continues running with compacted context
        │
        ▼
Stop hook fires ──► daemon checks if compaction count > threshold
        │
       YES: too many compactions = context degradation risk
        │
        ▼
Daemon terminates session, invokes /gsd:pause-work in new short session
        │
        ▼
Fresh session with /gsd:resume-work
```

**Key insight:** You cannot prevent auto-compaction. PreCompact fires BEFORE compaction but has no decision control -- it cannot block. The strategy is: let Claude compact, track how many times it has compacted in this session, and when a threshold is hit (e.g., 2-3 compactions), checkpoint and restart fresh. This avoids context degradation from repeated compaction.

### Session Lifecycle

```
1. Daemon spawns:  claude -p "<prompt>" --output-format stream-json \
                   --dangerously-skip-permissions --session-id <uuid>

2. Claude runs:    Reads CLAUDE.md, executes GSD command, uses tools

3. Hooks fire:     PreCompact → daemon tracks compaction count
                   Stop → daemon reads last_assistant_message
                   SessionEnd → daemon does cleanup

4. Daemon decides: Gate detected? → Telegram escalation
                   Compaction threshold? → Checkpoint + restart
                   Phase complete? → Next phase
                   All done? → Exit
```

## Key Architectural Decisions

### Use `--dangerously-skip-permissions` (not `--permission-mode auto`)

The daemon runs in a sandboxed environment (single Vultr server, no internet-facing services modified). Using `--dangerously-skip-permissions` eliminates all permission prompts. The `--permission-mode auto` alternative still prompts for some operations. Since the daemon cannot respond to interactive prompts, full bypass is required.

**Confidence:** HIGH -- verified from [CLI reference](https://code.claude.com/docs/en/cli-reference).

### Use `-p` (print mode) not interactive mode

Claude Code explicitly blocks nested sessions (`CLAUDECODE` env var check). The daemon must use `-p`/`--print` mode to run non-interactively. Each GSD command is a separate `claude -p` invocation.

**Confidence:** HIGH -- verified by direct test (error: "Claude Code cannot be launched inside another Claude Code session").

### Use `--output-format stream-json` for real-time monitoring

Stream-json emits NDJSON with content deltas, giving the daemon visibility into what Claude is doing. Combined with hooks (which provide structured lifecycle events), this gives full observability.

**Confidence:** MEDIUM -- stream-json format is documented but exact field structure for all event types needs validation during implementation.

### Hooks communicate to daemon via local HTTP

The daemon runs a tiny HTTP server on localhost. Hook scripts `curl` to it. This is simpler than named pipes, FIFOs, or file-based IPC, and the approvals-bridge already uses this pattern (health endpoint on port 9095).

**Confidence:** HIGH -- established pattern in this codebase.

### One `claude -p` invocation per GSD command

Rather than trying to maintain a long-running interactive session and feed it multiple prompts, each GSD step (`/gsd:plan-phase`, `/gsd:execute-phase`, etc.) is a separate `claude -p` invocation. This is simpler and avoids the complexity of piping prompts into an ongoing session.

**Trade-off:** More session startups (each reads CLAUDE.md, loads context), but each session starts clean with no context degradation. GSD's disk-based state (`STATE.md`, `.continue-here.md`) makes this seamless.

**Confidence:** HIGH -- this is the natural fit for `-p` mode.

### Telegram integration via existing approvals-bridge HTTP API (preferred) or direct bot API

Two viable options:

1. **Extend approvals-bridge** (preferred): Add a `/gsd/gate` HTTP endpoint that accepts gate context, sends Telegram message with inline buttons, and returns the decision. The bridge already handles Telegram polling, button callbacks, and message formatting.

2. **Direct Telegram Bot API**: The daemon manages its own bot connection. More isolated but duplicates existing infra.

**Confidence:** MEDIUM -- option 1 requires approvals-bridge modifications; feasibility depends on how tightly coupled its current WebSocket-based flow is.

## Anti-Patterns

### Anti-Pattern 1: Parsing Claude's natural language output for state

**What people do:** Try to determine what phase Claude is in by parsing its text output.
**Why it's wrong:** Claude's output format varies. A typo or rephrasing breaks the parser. Fragile and unmaintainable.
**Do this instead:** Always read STATE.md from disk. It is the canonical state. Claude Code writes it via GSD commands.

### Anti-Pattern 2: Keeping session state in daemon memory

**What people do:** Track current phase, task number, etc. in daemon variables.
**Why it's wrong:** Daemon crash = lost state. Session restart = stale state. Two sources of truth = bugs.
**Do this instead:** Read from disk before every decision. Let GSD commands own state writes.

### Anti-Pattern 3: Token counting for context window detection

**What people do:** Count tokens in the stream-json output and compare against a hardcoded context limit.
**Why it's wrong:** Context limits change per model. Token counting from output doesn't account for tool inputs, system prompts, or internal overhead. Off-by-one errors cause premature or late restarts.
**Do this instead:** Use the `PreCompact(auto)` hook. Claude Code already knows when its context is filling and fires this event. Trust the tool.

### Anti-Pattern 4: Long-running interactive sessions

**What people do:** Start Claude in interactive mode and pipe commands via stdin.
**Why it's wrong:** Claude Code blocks nested sessions. Interactive mode requires TTY. Permission prompts block indefinitely without human input.
**Do this instead:** Use `claude -p` for each GSD step. Clean, stateless, no TTY needed.

### Anti-Pattern 5: Restarting on every PreCompact

**What people do:** Kill the session immediately when PreCompact fires.
**Why it's wrong:** PreCompact fires BEFORE compaction and cannot prevent it. Killing mid-compaction may leave state inconsistent. Also, first compaction is usually fine -- context quality degrades on repeated compactions.
**Do this instead:** Track compaction count per session. Set a threshold (2-3). On threshold, let the current command finish (wait for Stop), then checkpoint and restart.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Claude Code CLI | `child_process.spawn('claude', ['-p', ...])` | Must unset `CLAUDECODE` env var. Stream-json output parsed line by line. |
| Telegram (via approvals-bridge) | HTTP POST to localhost:9095 | New endpoint needed for GSD gates. Existing bridge handles button callbacks. |
| GSD skill system | Invoked by prompting Claude with `/gsd:command` | Skills are loaded from `~/.claude/get-shit-done/`. No modification needed. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Daemon ↔ Session Manager | Direct function calls | Same process. Session Manager returns a promise that resolves when session ends. |
| Daemon ↔ Hook Scripts | HTTP (hook → daemon) | Hooks POST to daemon's localhost HTTP server. One-way: hooks report events, daemon acts. |
| Daemon ↔ Gate Controller | Direct function calls + async wait | Gate Controller sends Telegram message, returns promise. Resolves when button pressed. |
| Session Manager ↔ Claude Code | stdio (spawn) | Daemon reads stdout (stream-json), writes to stdin (not used in -p mode). Exit code signals completion. |

## Build Order (Dependencies)

The components have clear dependency ordering:

```
Phase 1: State Machine + State Parser
         (no external deps, fully testable with fixture files)
              │
Phase 2: Session Manager
         (depends on: state machine for "what to run")
         (spawns Claude Code, handles hooks IPC)
              │
Phase 3: Gate Controller + Telegram Integration
         (depends on: session manager output to detect gates)
         (sends messages, waits for responses)
              │
Phase 4: Daemon Loop (orchestrator)
         (wires everything together)
         (depends on all three above)
```

**Why this order:**
1. State Machine is a pure function with no I/O dependencies -- can be built and tested with mock STATE.md files immediately.
2. Session Manager needs to know what command to run (from State Machine), but Gate Controller is not needed yet -- can auto-approve everything during development.
3. Gate Controller requires session output to know when to escalate.
4. Daemon is just the wiring -- trivial once components exist.

**Phase 1 and 2 can potentially be collapsed** since the State Machine is small (~50 lines). The real complexity is in Session Manager (process lifecycle, hook IPC, stream parsing) and Gate Controller (Telegram integration, async waiting).

## Sources

- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference) -- flags, permission modes, output formats (HIGH confidence)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) -- PreCompact, Stop, SessionEnd event schemas (HIGH confidence)
- Existing approvals-bridge source at `/home/agent/agent-stack/approvals-bridge/approvals_bridge.py` -- Telegram inline button pattern (HIGH confidence)
- GSD pause-work/resume-work commands at `/home/agent/projects/get-shit-done/commands/gsd/` -- checkpoint mechanism (HIGH confidence)
- Direct CLI test confirming nested session blocking (HIGH confidence)

---
*Architecture research for: GSD Autonomous Runner*
*Researched: 2026-03-09*
