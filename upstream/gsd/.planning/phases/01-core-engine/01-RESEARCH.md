# Phase 1: Core Engine - Research

**Researched:** 2026-03-09
**Domain:** Claude Agent SDK session management, state machine orchestration, GSD phase loop
**Confidence:** HIGH

## Summary

Phase 1 builds the autonomous core: a TypeScript daemon that reads GSD state from disk, invokes Claude Code via the Agent SDK `query()` function with bounded sessions, detects compaction events in-stream, checkpoints via `/gsd:pause-work`, and restarts fresh sessions that re-orient from STATE.md. The phase loop is a state machine that cycles through plan-phase, execute-phase, verify-work, and advance -- terminating when all ROADMAP.md phases are complete.

The Agent SDK (v0.2.71) provides everything needed as first-class typed APIs: `maxTurns` for bounded sessions, `permissionMode: 'bypassPermissions'` for autonomous operation, `abortController` for graceful shutdown, and `SDKCompactBoundaryMessage` for in-stream compaction detection. The critical discovery from research is that compaction events are available as typed messages in the query stream (`type: "system", subtype: "compact_boundary"`) -- external hook scripts and HTTP IPC are NOT needed for this phase. This simplifies the architecture significantly.

A key performance consideration: each `query()` call incurs ~12 seconds of cold-start overhead (process spawn). This is acceptable since GSD commands run for minutes, but the architecture should NOT use rapid sequential `query()` calls for short operations. The pause-work checkpoint should be a separate query (acceptable overhead for the safety it provides).

**Primary recommendation:** Build a single-file state machine that reads STATE.md/ROADMAP.md before every decision, invokes `query()` with `maxTurns: 75` per GSD command, tracks `compact_boundary` messages to detect context exhaustion, and uses `abortController` for SIGTERM handling.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SESS-01 | Runner launches Claude via Agent SDK query() with configurable maxTurns per invocation | Agent SDK `query()` accepts `maxTurns` in Options. Verified from official TypeScript reference. |
| SESS-02 | Runner tracks compaction events per session and checkpoints via /gsd:pause-work when threshold is hit | `SDKCompactBoundaryMessage` (`type: "system", subtype: "compact_boundary"`) streams in-band with `compact_metadata.trigger` field. Count these per session. |
| SESS-03 | Runner starts fresh session that reads STATE.md to re-orient and continues from where it left off | Fresh `query()` call with GSD command as prompt. GSD's `/gsd:resume-work` reads `.continue-here.md` automatically. No SDK `resume` needed. |
| SESS-04 | Runner shuts down gracefully on SIGTERM, completing current operation and persisting state | `abortController` on Options. On SIGTERM, signal abort, wait for current query to yield `SDKResultMessage`, then run pause-work in a short final session. |
| LOOP-01 | State machine reads STATE.md and ROADMAP.md to determine the next GSD command to invoke | Pure function: parse markdown files, return next action. No SDK dependency -- testable with fixture files. |
| LOOP-02 | Runner executes the full phase cycle: plan-phase, execute-phase, verify-work, advance to next phase | Sequential `query()` calls with appropriate GSD slash commands as prompts. Each call is a bounded session. |
| LOOP-03 | Runner auto-approves at non-gate steps (permissionMode: bypassPermissions) | `permissionMode: 'bypassPermissions'` with `allowDangerouslySkipPermissions: true` in Options. Verified in official docs. |
| LOOP-04 | Runner terminates when all phases in ROADMAP.md are marked complete | State machine returns `{ action: 'done' }` when all `- [x]` in ROADMAP.md phases section. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `@anthropic-ai/claude-agent-sdk` | 0.2.71 | Claude Code programmatic API | First-class typed `query()`, `maxTurns`, `abortController`, in-stream compaction messages, `permissionMode`. This IS the interface. |
| TypeScript | ~5.7 | Type safety | Agent SDK is TypeScript-first. Message type unions require discriminated union handling. |
| Node.js | 20.20.0 | Runtime | Already installed on server. Required by Agent SDK. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `zod` | 3.x | Schema validation | Validate parsed STATE.md/ROADMAP.md structure before trusting it. Required by Agent SDK `tool()` for MCP definitions (Phase 2). |
| `pino` | ~9.6 | Structured logging | JSON logs for daemon operations. Lightweight, fast. |
| `dotenv` | ~16.4 | Environment config | Load API keys and configuration from `.env`. |

### Development
| Tool | Purpose | Notes |
|------|---------|-------|
| `tsx` | TypeScript execution | Run `.ts` files directly without compile step. Dev mode. |
| `tsup` | Build/bundle | Single-file ESM bundle for production. |
| `vitest` | Testing | Fast TypeScript-native test runner. Test state machine transitions with fixture files. |
| `@types/node` | Node.js types | Match installed Node 20.x. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Agent SDK `query()` | CLI spawn via `child_process` | CLI spawn gives no typed messages, no `abortController`, no in-stream compaction detection. Agent SDK wraps CLI internally anyway. |
| Fresh `query()` per GSD command | SDK `continue: true` for multi-turn | `continue` loads full history, approaching context limits faster. Fresh sessions with disk state are safer and the GSD-native pattern. |
| `vitest` | `jest` | Jest needs extra config for TypeScript ESM. Vitest is zero-config for TS. |

**Installation:**
```bash
npm install @anthropic-ai/claude-agent-sdk zod pino dotenv
npm install -D typescript tsx tsup vitest @types/node
```

## Architecture Patterns

### Recommended Project Structure
```
gsd-runner/
  src/
    index.ts              # Entry point, SIGTERM handler, main loop
    state-machine.ts      # Pure function: (disk state) => next GSD action
    session-runner.ts     # Invokes query(), streams messages, returns result
    state-parser.ts       # Parse STATE.md and ROADMAP.md into typed structures
    types.ts              # Shared type definitions
  test/
    state-machine.test.ts # Fixture-based tests for state transitions
    state-parser.test.ts  # Parse real and malformed STATE.md files
    session-runner.test.ts # Mock query() integration tests
  .env                    # API keys, config (gitignored)
  package.json
  tsconfig.json
  vitest.config.ts
```

### Pattern 1: State Machine Driven by Disk Artifacts
**What:** The daemon NEVER holds GSD state in memory. Before every decision, it reads STATE.md and ROADMAP.md from disk, parses them, and returns the next action.
**When to use:** Always. This is what makes session restarts safe.
**Example:**
```typescript
// Source: GSD project research + Agent SDK docs
type GsdAction =
  | { type: 'plan'; phase: number }
  | { type: 'execute'; phase: number }
  | { type: 'verify'; phase: number }
  | { type: 'resume' }
  | { type: 'done' }
  | { type: 'error'; reason: string };

function determineNextAction(projectDir: string): GsdAction {
  const state = parseStateFile(`${projectDir}/.planning/STATE.md`);
  const roadmap = parseRoadmapFile(`${projectDir}/.planning/ROADMAP.md`);
  const continueFile = findContinueHere(projectDir);

  if (continueFile) return { type: 'resume' };

  const currentPhase = getCurrentPhase(state, roadmap);
  if (!currentPhase) return { type: 'done' };

  if (!currentPhase.hasPlans) return { type: 'plan', phase: currentPhase.number };
  if (!currentPhase.plansComplete) return { type: 'execute', phase: currentPhase.number };
  if (!currentPhase.verified) return { type: 'verify', phase: currentPhase.number };

  // Phase complete but not marked in roadmap -- advance and re-check
  return { type: 'plan', phase: currentPhase.number + 1 };
}
```

### Pattern 2: In-Stream Compaction Detection
**What:** Track `SDKCompactBoundaryMessage` events in the query stream to count compactions per session. When threshold (2-3) is hit, let current operation finish, then checkpoint.
**When to use:** Every session. This replaces the external hook + HTTP IPC approach from the architecture research.
**Example:**
```typescript
// Source: Agent SDK TypeScript reference - SDKCompactBoundaryMessage
let compactionCount = 0;

for await (const msg of session) {
  if (msg.type === 'system' && msg.subtype === 'compact_boundary') {
    compactionCount++;
    logger.info({ compactionCount, trigger: msg.compact_metadata.trigger },
      'compaction detected');
  }
  if (msg.type === 'result') {
    result = msg;
    break;
  }
}

if (compactionCount >= COMPACTION_THRESHOLD) {
  // Run pause-work in a short session, then restart fresh
  await checkpointAndRestart(projectDir);
}
```

### Pattern 3: Bounded Sessions via maxTurns
**What:** Every `query()` call sets `maxTurns` to prevent unbounded context growth. When turns are exhausted, the SDK returns `SDKResultMessage` with `subtype: "error_max_turns"`.
**When to use:** Every `query()` invocation. No exceptions.
**Example:**
```typescript
// Source: Agent SDK TypeScript reference
const session = query({
  prompt: `/gsd:execute-phase ${phaseNumber}`,
  options: {
    cwd: projectDir,
    maxTurns: config.maxTurnsPerSession ?? 75,
    maxBudgetUsd: config.maxBudgetPerSession ?? 5.0,
    permissionMode: 'bypassPermissions',
    allowDangerouslySkipPermissions: true,
    systemPrompt: { type: 'preset', preset: 'claude_code' },
    settingSources: ['project'],  // Loads CLAUDE.md
    abortController: controller,
  }
});
```

### Pattern 4: Graceful SIGTERM Shutdown
**What:** On SIGTERM, abort the current query, wait for it to complete, run a short pause-work session, then exit.
**Example:**
```typescript
const controller = new AbortController();
let isShuttingDown = false;

process.on('SIGTERM', () => {
  if (isShuttingDown) return;
  isShuttingDown = true;
  logger.info('SIGTERM received, completing current operation...');
  controller.abort();
});

// In main loop, after query completes:
if (isShuttingDown) {
  await runPauseWork(projectDir);
  process.exit(0);
}
```

### Anti-Patterns to Avoid
- **Keeping GSD state in daemon memory:** Read from disk before every decision. Daemon crash = no lost state.
- **Using SDK `resume` for the main loop:** Resume loads full conversation history, approaching context limits. Use fresh sessions with `/gsd:resume-work` prompt instead.
- **Token counting for context detection:** Use `SDKCompactBoundaryMessage` in-stream. Claude Code knows when its context is filling.
- **Restarting on first compaction:** First compaction is usually fine. Track count, threshold at 2-3.
- **Not setting maxTurns:** Every `query()` MUST have `maxTurns`. An unbounded session will hit "Prompt too long" and die.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Session management | Custom child_process spawn + NDJSON parsing | Agent SDK `query()` | Typed async generator, abort control, compaction events in-stream. SDK wraps CLI internally. |
| Context exhaustion detection | Token counting, StatusLine parsing, percentage heuristics | `SDKCompactBoundaryMessage` from query stream | Official signal. Token counting is fragile (hidden buffers, model-specific limits). |
| Permission bypass | Custom tool allow/deny logic | `permissionMode: 'bypassPermissions'` | One option flag. Built-in, tested, covers all tools. |
| Session cancellation | `process.kill()` on Claude CLI PID | `abortController.abort()` on query Options | Clean shutdown, no orphaned processes, typed cleanup. |
| State persistence across restarts | Custom state file format | GSD's STATE.md + ROADMAP.md + `.continue-here.md` | Already exists, Claude reads it natively, `/gsd:pause-work` writes rich context. |
| Markdown parsing | Regex-based STATE.md parser | Simple line-by-line parser with zod validation | STATE.md has a known, simple format. Don't use a full markdown AST library. |

**Key insight:** The Agent SDK handles all the hard session lifecycle problems. The runner's job is purely: decide which GSD command to run next, invoke it, handle the result.

## Common Pitfalls

### Pitfall 1: Context Window Death Spiral
**What goes wrong:** Session runs unbounded until "Prompt too long" error. Session becomes permanently unusable.
**Why it happens:** No `maxTurns` set, or set too high (500+). Context fills with tool call history.
**How to avoid:** Set `maxTurns: 75` on every `query()`. Treat every session as disposable. Track compaction events and restart at threshold 2-3.
**Warning signs:** Sessions > 30 min without restart. Increasing response latency. `compact_boundary` messages appearing.

### Pitfall 2: Exit Code 0 Does Not Mean Success
**What goes wrong:** Runner treats `query()` completion as task success. But `SDKResultMessage` with `subtype: "success"` only means the process ran without errors -- not that Claude accomplished the GSD command goal.
**Why it happens:** Confusing process success with task success.
**How to avoid:** After each query, re-read STATE.md/ROADMAP.md from disk. Verify the expected state transition actually happened. If phase was "planning" and no PLAN.md appeared, the command failed.
**Warning signs:** STATE.md not changing between sessions. No new files in phase directory after execute.

### Pitfall 3: State Corruption After Crash
**What goes wrong:** Session crashes mid-task. STATE.md or `.continue-here.md` is partially written. Next session reads corrupt state.
**Why it happens:** File writes happen during tool calls. Crash before completion = partial writes.
**How to avoid:** Validate STATE.md structure (zod schema) before trusting it. If invalid, check git for last known good version. Design state transitions to be idempotent.
**Warning signs:** Malformed STATE.md. Git log showing same files modified repeatedly. Phase/task mismatch.

### Pitfall 4: 12-Second Query Overhead
**What goes wrong:** Architecture calls for many short `query()` invocations. Each incurs ~12s cold-start. Total overhead dominates execution time.
**Why it happens:** Agent SDK spawns a fresh Claude Code process per `query()` call.
**How to avoid:** Design around few, long-running `query()` calls. Each GSD command = one query. Don't split a single GSD operation across multiple queries. The pause-work checkpoint is a separate query (acceptable -- it's a safety boundary).
**Warning signs:** Runner spending more time on startup overhead than actual work.

### Pitfall 5: settingSources Omission
**What goes wrong:** Claude Code runs without loading CLAUDE.md project instructions. GSD commands don't work correctly because they depend on project-specific context.
**Why it happens:** Default `settingSources` is `[]` (no settings loaded). Must explicitly include `'project'`.
**How to avoid:** Always set `settingSources: ['project']` and `systemPrompt: { type: 'preset', preset: 'claude_code' }`.
**Warning signs:** GSD commands not recognizing project structure. Missing slash commands.

## Code Examples

### Complete Session Invocation
```typescript
// Source: Agent SDK TypeScript reference (platform.claude.com)
import { query, type SDKMessage, type SDKResultMessage } from '@anthropic-ai/claude-agent-sdk';

interface SessionResult {
  success: boolean;
  sessionId: string;
  compactionCount: number;
  result: SDKResultMessage;
  costUsd: number;
}

async function runGsdCommand(
  prompt: string,
  projectDir: string,
  controller: AbortController,
  config: { maxTurns: number; maxBudgetUsd: number }
): Promise<SessionResult> {
  let compactionCount = 0;
  let sessionId = '';
  let result: SDKResultMessage | undefined;

  const session = query({
    prompt,
    options: {
      cwd: projectDir,
      maxTurns: config.maxTurns,
      maxBudgetUsd: config.maxBudgetUsd,
      permissionMode: 'bypassPermissions',
      allowDangerouslySkipPermissions: true,
      systemPrompt: { type: 'preset', preset: 'claude_code' },
      settingSources: ['project'],
      abortController: controller,
    }
  });

  for await (const msg of session) {
    if (msg.type === 'system' && msg.subtype === 'init') {
      sessionId = msg.session_id;
    }
    if (msg.type === 'system' && msg.subtype === 'compact_boundary') {
      compactionCount++;
    }
    if (msg.type === 'result') {
      result = msg;
    }
  }

  if (!result) throw new Error('Session ended without result message');

  return {
    success: result.subtype === 'success',
    sessionId,
    compactionCount,
    result,
    costUsd: result.total_cost_usd,
  };
}
```

### STATE.md Parser
```typescript
// Source: GSD STATE.md format (from project research)
import { z } from 'zod';

const StateSchema = z.object({
  currentPhase: z.number(),
  totalPhases: z.number(),
  plansInPhase: z.number(),
  plansComplete: z.number(),
  status: z.string(),
});

type ParsedState = z.infer<typeof StateSchema>;

function parseStateFile(content: string): ParsedState {
  // Extract "Phase: X of Y" pattern
  const phaseMatch = content.match(/Phase:\s*(\d+)\s*of\s*(\d+)/);
  // Extract "Plan: X of Y" pattern
  const planMatch = content.match(/Plan:\s*(\d+)\s*of\s*(\d+)/);
  // Extract "Status: ..." pattern
  const statusMatch = content.match(/Status:\s*(.+)/);

  return StateSchema.parse({
    currentPhase: phaseMatch ? parseInt(phaseMatch[1]) : 0,
    totalPhases: phaseMatch ? parseInt(phaseMatch[2]) : 0,
    plansInPhase: planMatch ? parseInt(planMatch[2]) : 0,
    plansComplete: planMatch ? parseInt(planMatch[1]) : 0,
    status: statusMatch?.[1]?.trim() ?? 'unknown',
  });
}
```

### ROADMAP.md Phase Completion Check
```typescript
// Source: GSD ROADMAP.md format (from project research)
interface PhaseInfo {
  number: number;
  name: string;
  complete: boolean;
}

function parseRoadmap(content: string): PhaseInfo[] {
  const phases: PhaseInfo[] = [];
  // Match "- [ ] **Phase N: Name**" or "- [x] **Phase N: Name**"
  const phaseRegex = /- \[([ x])\] \*\*Phase (\d+): (.+?)\*\*/g;
  let match;
  while ((match = phaseRegex.exec(content)) !== null) {
    phases.push({
      number: parseInt(match[2]),
      name: match[3],
      complete: match[1] === 'x',
    });
  }
  return phases;
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CLI spawn + NDJSON parsing | Agent SDK `query()` async generator | SDK 0.2.x (2026) | Typed messages, native abort, in-stream compaction detection |
| `@anthropic-ai/claude-code` package | `@anthropic-ai/claude-agent-sdk` | Renamed ~2026-02 | Old package deprecated, may stop receiving updates |
| Hook scripts + HTTP IPC for lifecycle | In-stream `SDKCompactBoundaryMessage` + `SDKResultMessage` subtypes | SDK 0.2.x | No external hook scripts needed for compaction/result detection |
| `--dangerously-skip-permissions` CLI flag | `permissionMode: 'bypassPermissions'` in Options | SDK 0.2.x | Programmatic, typed, with `canUseTool` callback fallback |

**Deprecated/outdated:**
- `@anthropic-ai/claude-code`: Renamed to `@anthropic-ai/claude-agent-sdk`. Use the new name.
- External hook scripts for compaction: `SDKCompactBoundaryMessage` in the query stream is simpler and sufficient. Hooks are still available but not needed for this use case.
- Token counting for context limits: `compact_boundary` messages are the official signal. Don't count tokens.

## Open Questions

1. **Compaction threshold tuning**
   - What we know: 2-3 compactions is the suggested threshold from research. `compact_boundary` messages include `pre_tokens` count.
   - What's unclear: Optimal threshold for GSD commands specifically. May vary by command type (execute-phase runs longer than plan-phase).
   - Recommendation: Start with threshold of 2. Log `pre_tokens` from compact_boundary messages. Tune empirically after first full run.

2. **GSD command as prompt -- slash command or natural language?**
   - What we know: GSD commands are slash commands (e.g., `/gsd:execute-phase 1`). The Agent SDK passes the prompt to Claude Code which interprets slash commands.
   - What's unclear: Whether slash commands work reliably as `query()` prompts, or if Claude Code needs natural language wrapping.
   - Recommendation: Test with raw slash command first. If it doesn't work, wrap as: "Run the GSD command: /gsd:execute-phase 1"

3. **STATE.md format stability**
   - What we know: STATE.md has a known format with "Phase: X of Y", "Plan: X of Y", "Status: ..." fields.
   - What's unclear: Whether GSD commands always produce exactly this format, or if there are edge cases (newly created projects, error states).
   - Recommendation: Write a robust parser with fallbacks. Validate with zod. Log warnings on unexpected format but don't crash.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | vitest (latest) |
| Config file | `gsd-runner/vitest.config.ts` (Wave 0) |
| Quick run command | `cd gsd-runner && npx vitest run --reporter=verbose` |
| Full suite command | `cd gsd-runner && npx vitest run` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SESS-01 | query() invoked with configurable maxTurns | unit | `npx vitest run test/session-runner.test.ts -t "maxTurns"` | Wave 0 |
| SESS-02 | Compaction tracking + pause-work checkpoint | unit | `npx vitest run test/session-runner.test.ts -t "compaction"` | Wave 0 |
| SESS-03 | Fresh session with resume-work prompt | unit | `npx vitest run test/session-runner.test.ts -t "fresh session"` | Wave 0 |
| SESS-04 | SIGTERM graceful shutdown | unit | `npx vitest run test/index.test.ts -t "SIGTERM"` | Wave 0 |
| LOOP-01 | State machine next-action from STATE.md/ROADMAP.md | unit | `npx vitest run test/state-machine.test.ts` | Wave 0 |
| LOOP-02 | Full phase cycle (plan, execute, verify, advance) | integration | `npx vitest run test/daemon-loop.test.ts -t "full cycle"` | Wave 0 |
| LOOP-03 | bypassPermissions set on query options | unit | `npx vitest run test/session-runner.test.ts -t "permissions"` | Wave 0 |
| LOOP-04 | Terminates when all phases complete | unit | `npx vitest run test/state-machine.test.ts -t "all complete"` | Wave 0 |

### Sampling Rate
- **Per task commit:** `cd gsd-runner && npx vitest run --reporter=verbose`
- **Per wave merge:** `cd gsd-runner && npx vitest run`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `gsd-runner/vitest.config.ts` -- vitest configuration
- [ ] `gsd-runner/tsconfig.json` -- TypeScript configuration
- [ ] `gsd-runner/package.json` -- project manifest with dependencies
- [ ] `gsd-runner/test/state-machine.test.ts` -- state machine transition tests with fixture STATE.md/ROADMAP.md files
- [ ] `gsd-runner/test/state-parser.test.ts` -- parser tests for valid and malformed inputs
- [ ] `gsd-runner/test/fixtures/` -- sample STATE.md, ROADMAP.md files for various states

## Sources

### Primary (HIGH confidence)
- [Agent SDK TypeScript Reference](https://platform.claude.com/docs/en/agent-sdk/typescript) -- Full Options interface, Query object, SDKMessage types, SDKCompactBoundaryMessage, SDKResultMessage subtypes, HookEvent types
- [Agent SDK Sessions Guide](https://platform.claude.com/docs/en/agent-sdk/sessions) -- Session lifecycle, continue vs resume vs fork, session ID capture from SDKResultMessage
- [@anthropic-ai/claude-agent-sdk npm](https://www.npmjs.com/package/@anthropic-ai/claude-agent-sdk) -- Version 0.2.71, confirmed on server
- GSD command sources: `/gsd:pause-work` and `/gsd:resume-work` command definitions -- checkpoint mechanism, `.continue-here.md` format

### Secondary (MEDIUM confidence)
- [Agent SDK query() overhead issue #34](https://github.com/anthropics/claude-agent-sdk-typescript/issues/34) -- ~12s cold-start per query(), streaming mode for hot reuse
- [Claude Agent SDK Cheatsheet (AGNT.gg)](https://agnt.gg/articles/claude-agent-sdk-cheatsheet) -- Permission mode examples, hook patterns
- [Complete Guide to Agent SDK (Nader)](https://nader.substack.com/p/the-complete-guide-to-building-agents) -- Practical patterns

### Tertiary (LOW confidence)
- Compaction threshold of 2-3: Based on project research inference, not empirical data. Needs tuning.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Agent SDK API verified against official TypeScript reference, versions confirmed on server
- Architecture: HIGH - State machine pattern is pure logic, SDK message types are fully documented, compaction detection verified in official docs
- Pitfalls: HIGH - Context death spiral, exit-code-vs-success, and state corruption all documented with official sources
- Session lifecycle: MEDIUM - 12s overhead confirmed via GitHub issue, compaction threshold untested empirically

**Research date:** 2026-03-09
**Valid until:** 2026-04-09 (Agent SDK is fast-moving; check for API changes after 30 days)
