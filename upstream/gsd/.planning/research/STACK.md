# Stack Research

**Domain:** Process orchestrator / daemon for autonomous Claude Code session management
**Researched:** 2026-03-09
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Node.js | 20.20.0 (already installed) | Runtime | Already on server, LTS, required by Claude Code CLI. No new runtime deps needed. |
| TypeScript | ~5.7 | Type safety | The Claude Agent SDK is TypeScript-first. Types for message streams, options, hooks are critical for a state machine that must handle every message variant correctly. |
| `@anthropic-ai/claude-agent-sdk` | 0.2.71 | Claude Code programmatic API | **This is the centerpiece.** The Agent SDK provides `query()` as an async generator that streams typed messages. It supports `resume` (session continuity), `maxTurns`, `maxBudgetUsd`, `abortController` (graceful cancel), `allowedTools`, `permissionMode`, hooks (`PreToolUse`, `PostToolUse`, `Stop`, `SessionStart`), and custom MCP tools. This replaces the need to spawn `claude` CLI as a child process and parse stdout. |
| grammY | 1.41.1 | Telegram bot framework | Modern, TypeScript-native, lightweight. Better types than Telegraf, more maintained than node-telegram-bot-api. Inline keyboard support for approve/reject buttons. 137K weekly downloads. |

### Why Agent SDK Over CLI Spawning

The original PROJECT.md assumed spawning `claude -p` via child_process. The Agent SDK (`@anthropic-ai/claude-agent-sdk`) is strictly better for this use case:

| Concern | CLI spawn approach | Agent SDK approach |
|---------|-------------------|-------------------|
| Session resume | Parse `--resume <id>` from stdout | `options: { resume: sessionId }` — typed, first-class |
| Message streaming | Parse NDJSON from stdout pipe | `for await (const msg of query(...))` — typed async generator |
| Cancellation | `process.kill(pid)` | `query.close()` or `abortController.abort()` |
| Budget control | `--max-budget-usd` flag | `options: { maxBudgetUsd: 5.0 }` |
| Turn limits | `--max-turns` flag | `options: { maxTurns: N }` |
| Permission control | `--dangerously-skip-permissions` | `permissionMode: 'bypassPermissions'` or custom `canUseTool` callback |
| Hooks | None (post-hoc log parsing) | `hooks: { PostToolUse: [...] }` — inline callbacks |
| Error handling | Exit codes + stderr parsing | Typed error messages in stream |
| Custom tools | Not possible | MCP tools via `createSdkMcpServer()` |
| Multi-turn conversations | Restart process each time | `streamInput()` for ongoing conversation |

**Verdict:** Use the Agent SDK. It was built for exactly this use case — "production automation" per Anthropic's own docs.

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `zod` | 3.x | Schema validation | Validate STATE.md parsing, Telegram callback data, config files. Also required by Agent SDK's `tool()` function for MCP tool schemas. |
| `@grammyjs/menu` | ~1.2 | Inline menu plugin | Simplifies inline keyboard management for approve/reject/escalate button flows. Handles callback routing cleanly. |
| `yaml` | ~2.7 | YAML parsing | If STATE.md or ROADMAP.md use YAML frontmatter (they use markdown, but YAML headers are common). Use `js-yaml` if you prefer, but `yaml` has better TS types. |
| `pino` | ~9.6 | Structured logging | JSON logs for daemon operation. Fast, low-overhead, supports child loggers per component (orchestrator, telegram, session). |
| `dotenv` | ~16.4 | Env config | Load `.env` for API keys, Telegram tokens, chat IDs. |
| `chokidar` | ~4.0 | File watcher | Watch STATE.md and ROADMAP.md for external changes (manual edits, other tools). Triggers re-evaluation of current phase. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `tsx` | TypeScript execution | Run `.ts` files directly without compile step. Use for development. |
| `tsup` | Build/bundle | Single-file ESM bundle for production. Fast, zero-config for simple projects. |
| `vitest` | Testing | Fast, TypeScript-native, watch mode. Test the state machine transitions. |
| `@types/node` | Node.js types | Match the installed Node 20.x version. |

## Architecture-Relevant SDK Capabilities

### Session Lifecycle (maps directly to requirements)

```typescript
import { query } from "@anthropic-ai/claude-agent-sdk";

// Start a new session
const session = query({
  prompt: "/gsd:plan-phase",
  options: {
    cwd: "/path/to/project",
    allowedTools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"],
    permissionMode: "bypassPermissions",  // autonomous mode
    allowDangerouslySkipPermissions: true,
    maxBudgetUsd: 5.0,
    maxTurns: 50,
    settingSources: ["project"],  // loads CLAUDE.md
    abortController: controller,
  }
});

// Capture session ID for resume
let sessionId: string;
for await (const msg of session) {
  if (msg.type === "system" && msg.subtype === "init") {
    sessionId = msg.session_id;
  }
  if ("result" in msg) {
    // Session complete — parse result, decide next action
  }
}

// Resume after context checkpoint
const resumed = query({
  prompt: "/gsd:resume-work",
  options: { resume: sessionId }
});
```

### Custom MCP Tool for Telegram Escalation

```typescript
import { tool, createSdkMcpServer } from "@anthropic-ai/claude-agent-sdk";
import { z } from "zod";

const escalateTool = tool(
  "escalate-to-human",
  "Send an approval request to the human operator via Telegram and wait for response",
  { message: z.string(), options: z.array(z.string()).optional() },
  async ({ message, options }) => {
    // Send Telegram message with inline buttons
    // Block until callback received
    // Return the human's decision
    return { content: [{ type: "text", text: "approved" }] };
  }
);

const server = createSdkMcpServer({
  name: "gsd-escalation",
  tools: [escalateTool]
});

// Pass to query
const session = query({
  prompt: "...",
  options: { mcpServers: { "gsd-escalation": server } }
});
```

## Telegram Integration Strategy

### Do NOT reuse the existing approvals-bridge

The existing `approvals-bridge` (Python, websockets + python-telegram-bot) is tightly coupled to OpenClaw's gateway WebSocket protocol. It routes `exec.approval.requested` events from OpenClaw's gateway. The GSD runner has no OpenClaw gateway — it talks directly to the Claude Agent SDK.

**Instead:** Build a lightweight grammY bot that:
1. Receives escalation requests from the orchestrator (in-process function call, not HTTP/WebSocket)
2. Sends inline keyboard messages to Telegram
3. Waits for callback query (approve/reject button press)
4. Returns the decision to the orchestrator

This is ~100 lines of code. The approvals-bridge is 850 lines because it handles WebSocket reconnection, protocol handshakes, Gmail approvals, health endpoints, and reminders — none of which apply here.

### grammY vs reusing python-telegram-bot

| Criterion | grammY (recommended) | python-telegram-bot (existing) |
|-----------|---------------------|-------------------------------|
| Language match | TypeScript (same as orchestrator) | Python (cross-language IPC needed) |
| Integration | In-process function call | HTTP API or subprocess |
| Inline keyboards | First-class, typed | Works but separate process |
| Maintenance | One codebase | Two codebases, two languages |

**Can they share the same Telegram bot token?** Yes, but only one process can poll for updates. Options:
1. **Separate bot token** (recommended for v1): Create a second BotFather bot for the GSD runner. Avoids conflicts with approvals-bridge polling.
2. **Webhook mode**: Both bots use webhooks with different paths on Caddy. More complex setup.

**Recommendation:** Separate bot token. Simple, no conflicts.

## Installation

```bash
# Core
npm install @anthropic-ai/claude-agent-sdk grammy zod pino dotenv

# Supporting
npm install chokidar yaml @grammyjs/menu

# Dev dependencies
npm install -D typescript tsx tsup vitest @types/node
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| `@anthropic-ai/claude-agent-sdk` | CLI spawn via `child_process.spawn` | Only if the Agent SDK has a blocking bug. The SDK wraps the CLI internally anyway, so spawning directly gives you a lower-level version of the same thing with no typing. |
| grammY | Telegraf 4.x | If you already have a Telegraf codebase to extend. Telegraf's TypeScript types are less clean. |
| grammY | node-telegram-bot-api | If you want zero abstraction. NTBA is callback-based, no middleware, weaker types. |
| pino | winston | If you need transport plugins (Datadog, etc). Overkill for a single-server daemon. |
| `yaml` | `js-yaml` | If you want the more popular package. `js-yaml` has 60M weekly downloads vs `yaml`'s 30M. Types are slightly worse. |
| tsup | esbuild directly | If you need custom build logic. tsup wraps esbuild with sane defaults. |
| chokidar | `fs.watch` / `fs.watchFile` | Never — Node's built-in watchers are unreliable across platforms and have known bugs with recursive watching. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `execa` | ESM-only since v6, adds complexity for child process management you don't need (Agent SDK handles process spawning internally) | `@anthropic-ai/claude-agent-sdk` |
| `pm2` / `forever` | The daemon IS the process manager. Adding pm2 on top creates confusion about who manages what. Use systemd for the daemon itself. | systemd unit file |
| `bull` / `bullmq` | Redis-backed job queue is overkill for single-project sequential execution. The orchestrator is a simple state machine, not a job queue. | In-memory state machine with file-based persistence (STATE.md) |
| `express` / `fastify` | No HTTP API needed for v1. Telegram bot handles human interaction. Health checks can be a simple TCP socket if needed. | grammY's built-in webhook server (if needed later) |
| OpenClaw approvals-bridge | Wrong architecture — coupled to OpenClaw gateway protocol, Python, would need cross-language IPC | grammY in-process |
| `node-cron` / `cron` | No scheduled execution needed. The daemon runs continuously when started, not on a schedule. | Simple event loop |
| `@anthropic-ai/claude-code` (old package name) | Deprecated, renamed to `@anthropic-ai/claude-agent-sdk`. The old package may stop receiving updates. | `@anthropic-ai/claude-agent-sdk` |

## Stack Patterns

**For the state machine (core orchestrator):**
- Pure TypeScript, no framework. A state machine with states: `idle`, `planning`, `executing`, `verifying`, `awaiting-approval`, `checkpointing`, `resuming`, `complete`, `error`.
- State persisted to disk via STATE.md (read on startup, updated on transitions).
- Each state transition invokes `query()` with the appropriate GSD command.

**For Telegram integration:**
- grammY bot runs in the same Node.js process as the orchestrator.
- Escalation is a Promise: orchestrator calls `await escalate("message")`, which sends Telegram message and resolves when button is pressed.
- No HTTP server needed — grammY polls Telegram for updates (long polling).

**For session lifecycle:**
- Agent SDK's `resume` option handles session continuity natively.
- `maxTurns` as a proxy for context window filling — when turns exhausted, checkpoint and restart.
- `abortController` for graceful shutdown on SIGTERM.

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `@anthropic-ai/claude-agent-sdk@0.2.x` | Node.js 18+ | Requires Claude Code CLI installed globally (already have 2.1.71) |
| `grammy@1.41.x` | Node.js 18+ | Also supports Deno and Bun, but we use Node |
| `typescript@5.7.x` | Node.js 20.x | Target ES2022 for top-level await support |
| `zod@3.x` | Agent SDK 0.2.x | Agent SDK supports both Zod 3 and Zod 4 for tool schemas |

## Sources

- [Claude Code CLI reference](https://code.claude.com/docs/en/cli-reference) -- verified all CLI flags, confirmed --print/--output-format/--resume capabilities (HIGH confidence)
- [Claude Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview) -- verified query() API, session management, hooks, MCP tools, permissions (HIGH confidence)
- [Claude Agent SDK TypeScript reference](https://platform.claude.com/docs/en/agent-sdk/typescript) -- verified full Options interface, Query object methods, message types (HIGH confidence)
- [@anthropic-ai/claude-agent-sdk npm](https://www.npmjs.com/package/@anthropic-ai/claude-agent-sdk) -- version 0.2.71, published 2026-03-08 (HIGH confidence)
- [grammY comparison page](https://grammy.dev/resources/comparison) -- verified grammY vs Telegraf vs NTBA tradeoffs (HIGH confidence)
- [grammy npm](https://www.npmjs.com/package/grammy) -- version 1.41.1, 137K weekly downloads (HIGH confidence)
- [npm trends: grammy vs telegraf vs node-telegram-bot-api](https://npmtrends.com/grammy-vs-node-telegram-bot-api-vs-telegraf-vs-telegram-bot-api) -- download comparison (MEDIUM confidence)
- Existing approvals-bridge source at `/home/agent/agent-stack/approvals-bridge/approvals_bridge.py` -- analyzed to determine reuse viability (HIGH confidence, direct code inspection)
- Local server inspection: Node 20.20.0, Claude Code 2.1.71, npm 10.8.2 (HIGH confidence, verified on machine)

---
*Stack research for: GSD Autonomous Runner*
*Researched: 2026-03-09*
