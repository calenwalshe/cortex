# Phase 2: Telegram and Observability - Research

**Researched:** 2026-03-09
**Domain:** Telegram bot integration (grammY), structured logging (pino), stuck agent detection
**Confidence:** HIGH

## Summary

Phase 2 wires Telegram gate approvals, progress notifications, heartbeat pings, structured logging, and stuck detection into the existing Phase 1 core engine. The engine already has a working daemon loop (`index.ts`), session runner (`session-runner.ts`), and state machine (`state-machine.ts`) -- this phase adds the human-in-the-loop and observability layers on top.

The Telegram integration uses grammY (v1.41.x) running long polling in the same Node.js process as the daemon. The key architectural pattern is a **Promise-based gate controller**: the daemon sends an inline keyboard message to Telegram and receives a Promise that resolves when the user taps approve/reject. This bridges the async callback-driven Telegram bot with the sequential daemon loop. grammY's `callbackQuery()` handler resolves a stored Promise keyed by message ID. No conversations plugin needed -- the pattern is ~80 lines with a Map of pending approvals.

Structured logging replaces the existing ad-hoc `pino` usage (already in `session-runner.ts` and `index.ts`) with a centralized logger module using child loggers per component. Stuck detection monitors the Agent SDK message stream for repeated identical tool calls within a sliding window and escalates to Telegram when a threshold is hit.

**Primary recommendation:** Add three new modules -- `telegram.ts` (grammY bot + gate controller), `logger.ts` (centralized pino with child loggers), and `stuck-detector.ts` (sliding window tool call tracker) -- then integrate them into the existing `session-runner.ts` and `index.ts`.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TELE-01 | Runner sends gate notifications to Telegram with inline approve/reject buttons via grammY | grammY `InlineKeyboard.text()` creates callback buttons. `bot.api.sendMessage()` with `reply_markup` sends them. Pattern verified from official grammY keyboard docs. |
| TELE-02 | Runner pipes Telegram button response back to unblock the waiting session | Promise-based gate controller: `Map<number, { resolve, reject }>` keyed by message ID. `bot.callbackQuery()` handler resolves the matching Promise. Daemon `await`s the Promise. |
| TELE-03 | Runner sends progress notifications between gates (phase started, phase complete, session restarted) | Simple `bot.api.sendMessage(chatId, text)` calls at state transitions in the daemon loop. No inline keyboard needed for progress -- plain text messages. |
| TELE-04 | Runner sends periodic heartbeat pings to confirm it's still alive | `setInterval()` in the daemon process sends a heartbeat message via `bot.api.sendMessage()`. Clear interval on shutdown. |
| OBSV-01 | Runner logs all operations as structured JSON via pino | Centralized pino logger with child loggers per component (session, telegram, loop, state-machine). Replace existing ad-hoc `pino()` instantiation in session-runner.ts and index.ts. |
| OBSV-02 | Runner detects stuck/looping agents and escalates to Telegram | Sliding window of last N tool call signatures from the Agent SDK stream. If >M identical calls in window, flag as stuck and send Telegram alert. Abort the session. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `grammy` | 1.41.x | Telegram bot framework | TypeScript-native, inline keyboard support, callback query handling, long polling built-in. Already chosen in project research. |
| `pino` | ~9.6 | Structured JSON logging | Already a dependency in package.json. Fast, child logger support, JSON-native output. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `pino-pretty` | ~13.0 | Human-readable log output | Dev mode only. Never in production -- defeats pino's performance. |

### Not Needed
| Library | Why Not |
|---------|---------|
| `@grammyjs/conversations` | Overkill for simple approve/reject gates. A Promise + Map pattern is simpler and avoids the conversations plugin's replay engine complexity. |
| `@grammyjs/menu` | Menu plugin is for complex multi-level menus. Two buttons (approve/reject) don't need it. |
| `@grammyjs/runner` | Runner plugin is for concurrent update processing. The GSD runner processes one gate at a time -- sequential is fine. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Raw Promise + Map for gate controller | `@grammyjs/conversations` plugin | Conversations adds replay engine, context types, and plugin wiring. Our use case is a single wait-for-button-press per gate -- too simple for conversations overhead. |
| `setInterval` heartbeat | `node-cron` | Cron is for scheduled jobs. Heartbeat is a simple interval in a long-running process. |
| Sliding window stuck detection | Agent SDK `maxTurns` alone | `maxTurns` prevents unbounded sessions but doesn't detect a stuck agent that burns all turns on the same failing operation. Both are needed. |

**Installation:**
```bash
npm install grammy
npm install -D pino-pretty
```

## Architecture Patterns

### Recommended Module Structure
```
gsd-runner/src/
  index.ts              # Entry point, SIGTERM, main loop (MODIFY)
  session-runner.ts     # Agent SDK session lifecycle (MODIFY - add stuck detection, progress events)
  state-machine.ts      # Pure function: disk state -> next action (NO CHANGE)
  state-parser.ts       # Parse STATE.md/ROADMAP.md (NO CHANGE)
  types.ts              # Shared types (MODIFY - add Telegram types)
  telegram.ts           # NEW: grammY bot, gate controller, progress sender, heartbeat
  logger.ts             # NEW: Centralized pino logger with child loggers
  stuck-detector.ts     # NEW: Sliding window tool call tracker
  config.ts             # Load config from env (MODIFY - add Telegram config)
```

### Pattern 1: Promise-Based Gate Controller
**What:** The daemon sends a Telegram message with approve/reject buttons and awaits a Promise. The grammY callback query handler resolves that Promise when the user taps a button.
**When to use:** Every GSD gate point (after verify-work, before advancing to next phase).
**Example:**
```typescript
// Source: grammY docs (grammy.dev/plugins/keyboard) + custom Promise pattern
import { Bot, InlineKeyboard } from 'grammy';

interface PendingGate {
  resolve: (approved: boolean) => void;
  reject: (err: Error) => void;
  timer: NodeJS.Timeout;
}

const pendingGates = new Map<number, PendingGate>();

function setupGateHandler(bot: Bot): void {
  bot.callbackQuery(/^gate:(approve|reject):(\d+)$/, async (ctx) => {
    const action = ctx.match![1];
    const gateId = parseInt(ctx.match![2]);
    const pending = pendingGates.get(gateId);
    if (!pending) {
      await ctx.answerCallbackQuery({ text: 'Gate expired or already handled' });
      return;
    }
    clearTimeout(pending.timer);
    pendingGates.delete(gateId);
    await ctx.answerCallbackQuery({ text: action === 'approve' ? 'Approved' : 'Rejected' });
    await ctx.editMessageReplyMarkup(); // Remove buttons
    pending.resolve(action === 'approve');
  });

  // Catch-all for unhandled callbacks
  bot.on('callback_query:data', async (ctx) => {
    await ctx.answerCallbackQuery();
  });
}

async function requestGateApproval(
  bot: Bot,
  chatId: number,
  message: string,
  timeoutMs: number = 4 * 60 * 60 * 1000, // 4 hours
): Promise<boolean> {
  let gateId = Date.now(); // Simple unique ID
  const keyboard = new InlineKeyboard()
    .text('Approve', `gate:approve:${gateId}`)
    .text('Reject', `gate:reject:${gateId}`);

  const sent = await bot.api.sendMessage(chatId, message, {
    reply_markup: keyboard,
    parse_mode: 'HTML',
  });

  return new Promise<boolean>((resolve, reject) => {
    const timer = setTimeout(() => {
      pendingGates.delete(gateId);
      reject(new Error(`Gate approval timed out after ${timeoutMs}ms`));
    }, timeoutMs);

    pendingGates.set(gateId, { resolve, reject, timer });
  });
}
```

### Pattern 2: Centralized Logger with Child Loggers
**What:** Single pino instance with child loggers for each component. Replaces the per-file `pino({ name: '...' })` pattern currently in session-runner.ts and index.ts.
**When to use:** All modules import from `logger.ts` instead of creating their own pino instance.
**Example:**
```typescript
// Source: pino docs (github.com/pinojs/pino/blob/main/docs/child-loggers.md)
import pino from 'pino';

const rootLogger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  name: 'gsd-runner',
});

export const logger = {
  session: rootLogger.child({ component: 'session' }),
  telegram: rootLogger.child({ component: 'telegram' }),
  loop: rootLogger.child({ component: 'loop' }),
  gate: rootLogger.child({ component: 'gate' }),
  stuck: rootLogger.child({ component: 'stuck-detector' }),
};
```

### Pattern 3: Sliding Window Stuck Detection
**What:** Track the last N tool call signatures in a circular buffer. If the same tool+args hash appears more than M times, the agent is stuck. Escalate to Telegram and abort the session.
**When to use:** During every Agent SDK session, monitoring the message stream.
**Example:**
```typescript
// Source: agent stuck detection patterns (dev.to/boucle2026)
interface ToolCall {
  tool: string;
  argsHash: string;
  timestamp: number;
}

class StuckDetector {
  private window: ToolCall[] = [];
  private readonly windowSize: number;
  private readonly threshold: number;

  constructor(windowSize = 20, threshold = 5) {
    this.windowSize = windowSize;
    this.threshold = threshold;
  }

  /**
   * Record a tool call. Returns true if the agent appears stuck.
   */
  record(tool: string, args: string): boolean {
    const argsHash = this.hash(args);
    this.window.push({ tool, argsHash, timestamp: Date.now() });
    if (this.window.length > this.windowSize) {
      this.window.shift();
    }
    // Count identical calls in window
    const key = `${tool}:${argsHash}`;
    const count = this.window.filter(c => `${c.tool}:${c.argsHash}` === key).length;
    return count >= this.threshold;
  }

  reset(): void {
    this.window = [];
  }

  private hash(s: string): string {
    // Simple hash for comparison -- not crypto
    let h = 0;
    for (let i = 0; i < s.length; i++) {
      h = ((h << 5) - h + s.charCodeAt(i)) | 0;
    }
    return h.toString(36);
  }
}
```

### Pattern 4: Heartbeat via setInterval
**What:** Periodic Telegram message confirming the daemon is alive. Cleared on shutdown.
**When to use:** Start when daemon starts, stop on SIGTERM.
**Example:**
```typescript
let heartbeatInterval: NodeJS.Timeout | null = null;

function startHeartbeat(bot: Bot, chatId: number, intervalMs = 30 * 60 * 1000): void {
  heartbeatInterval = setInterval(async () => {
    try {
      await bot.api.sendMessage(chatId, 'GSD Runner heartbeat -- still running');
    } catch (err) {
      // Log but don't crash on heartbeat failure
      logger.telegram.warn({ err }, 'Heartbeat send failed');
    }
  }, intervalMs);
}

function stopHeartbeat(): void {
  if (heartbeatInterval) {
    clearInterval(heartbeatInterval);
    heartbeatInterval = null;
  }
}
```

### Anti-Patterns to Avoid
- **Using grammY conversations plugin for simple approve/reject:** The replay engine adds complexity with no benefit for single-button-press gates. Use a Promise + Map.
- **Sharing bot token with approvals-bridge:** Two processes cannot long-poll the same bot token. Use a separate BotFather bot token.
- **Sending Telegram messages inside the Agent SDK stream loop:** Network calls inside a tight stream loop slow down message processing. Buffer events and send Telegram notifications at state boundaries (session complete, gate reached), not per-message.
- **Blocking the grammY event loop with synchronous work:** `bot.start()` runs its own event loop for long polling. The daemon loop and bot polling must coexist. Start bot polling first, then run the daemon loop -- both are async and share the Node.js event loop naturally.
- **Parsing tool call args for stuck detection from `msg.content`:** Agent SDK messages have typed fields. Use `tool_name` and `tool_input` from `SDKToolUseMessage` (or similar), not string parsing of assistant text.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Telegram bot connection | Raw `fetch()` to Telegram Bot API | grammY `Bot` class with `bot.start()` | Long polling, error handling, retry logic, rate limiting all handled. |
| Inline keyboard construction | Manual JSON `reply_markup` objects | grammY `InlineKeyboard` class | Type-safe builder, row management, callback data validation. |
| Callback query routing | Manual `if/else` on `update.callback_query.data` | grammY `bot.callbackQuery()` with regex | Middleware chain, automatic `answerCallbackQuery`, context enrichment. |
| JSON structured logging | `console.log(JSON.stringify(...))` | pino with child loggers | Performance (async writes, string interning), log levels, child context propagation. |
| Tool call hashing for stuck detection | Full JSON comparison of tool args | Simple string hash (djb2 or similar) | Full JSON comparison is expensive and unnecessary -- hash collisions are acceptable for a threshold counter. |

**Key insight:** grammY handles all Telegram protocol complexity (long polling reconnection, update offset tracking, callback query acknowledgment). The runner only needs to call `bot.api.sendMessage()` and register `bot.callbackQuery()` handlers.

## Common Pitfalls

### Pitfall 1: Bot Token Conflict with Approvals Bridge
**What goes wrong:** If the GSD runner uses the same Telegram bot token as the existing approvals-bridge, only one process can receive updates. The other silently misses all callbacks.
**Why it happens:** Telegram only delivers updates to one long-polling consumer per bot token.
**How to avoid:** Create a separate bot via BotFather for the GSD runner. Store token in `.env` as `GSD_TELEGRAM_BOT_TOKEN`.
**Warning signs:** Button presses not being received. No callback query handler firing.

### Pitfall 2: Gate Approval Deadlock
**What goes wrong:** Daemon blocks forever on `await requestGateApproval()` because nobody taps the button.
**Why it happens:** User is AFK, message is missed, Telegram notification silenced.
**How to avoid:** Configurable timeout (4 hours default). On timeout, send a reminder message and eventually halt execution. Log timeout events for debugging.
**Warning signs:** Daemon idle for hours with no log output. No phase progression.

### Pitfall 3: Forgetting to Answer Callback Queries
**What goes wrong:** Telegram shows a spinning loading indicator on the button for up to 60 seconds after tap.
**Why it happens:** `ctx.answerCallbackQuery()` not called in the handler.
**How to avoid:** Always call `ctx.answerCallbackQuery()` in every callback query handler. Add a catch-all `bot.on('callback_query:data')` handler last that answers unmatched queries.
**Warning signs:** Buttons showing loading spinners. Users thinking the bot is broken.

### Pitfall 4: Stuck Detection False Positives
**What goes wrong:** Legitimate repeated tool calls (e.g., reading multiple files with `Read` tool) trigger stuck detection.
**Why it happens:** Window too small or threshold too low. Not checking args, only tool name.
**How to avoid:** Hash both tool name AND arguments. Use a reasonable window (20 calls) and threshold (5 identical). Exclude read-only tools (Read, Glob, Grep) from stuck detection or require higher threshold for them.
**Warning signs:** Sessions being aborted during normal file-reading operations.

### Pitfall 5: grammY Bot Startup Order
**What goes wrong:** `bot.start()` is called and never returns (it runs the polling loop). Daemon loop code after `bot.start()` never executes.
**Why it happens:** `bot.start()` is a long-running async function that only resolves when the bot stops.
**How to avoid:** Start bot polling WITHOUT awaiting: `bot.start()` (fire and forget, or store the promise for shutdown). Then run the daemon loop. On shutdown, call `bot.stop()`.
**Warning signs:** Daemon appears to start but never executes any GSD commands.

### Pitfall 6: Message Rate Limiting
**What goes wrong:** Telegram returns 429 Too Many Requests when sending too many messages.
**Why it happens:** Progress notifications or heartbeats sent too frequently.
**How to avoid:** Heartbeat interval >= 30 minutes. Progress notifications at state boundaries only (phase start/complete), not per-task. grammY has built-in auto-retry for 429 errors, but avoid triggering them.
**Warning signs:** `429` errors in logs. Messages arriving delayed.

## Code Examples

### Bot Initialization and Lifecycle
```typescript
// Source: grammY docs (grammy.dev/guide)
import { Bot } from 'grammy';

interface TelegramConfig {
  botToken: string;
  chatId: number;
  gateTimeoutMs: number;
  heartbeatIntervalMs: number;
}

function createBot(config: TelegramConfig): Bot {
  const bot = new Bot(config.botToken);

  // Register gate handler
  setupGateHandler(bot);

  // Error handler
  bot.catch((err) => {
    logger.telegram.error({ err: err.error }, 'grammY error');
  });

  return bot;
}

// In main():
const bot = createBot(telegramConfig);
// Start polling (DO NOT await -- it runs forever)
bot.start({
  onStart: () => logger.telegram.info('Telegram bot started polling'),
});
startHeartbeat(bot, telegramConfig.chatId, telegramConfig.heartbeatIntervalMs);

// ... run daemon loop ...

// On shutdown:
stopHeartbeat();
await bot.stop();
```

### Integrating Stuck Detection into Session Runner
```typescript
// Source: Agent SDK message types + stuck detection pattern
// In session-runner.ts, extend the message processing loop:

for await (const message of stream) {
  const msg = message as Record<string, unknown>;

  // Existing: init, compact_boundary, result handling...

  // NEW: Track tool calls for stuck detection
  if (msg.type === 'assistant' && msg.subtype === 'tool_use') {
    const toolName = msg.tool_name as string;
    const toolInput = JSON.stringify(msg.tool_input ?? {});
    if (stuckDetector.record(toolName, toolInput)) {
      logger.stuck.error({ toolName, sessionId }, 'Stuck agent detected');
      // Abort the session
      controller.abort();
      // Return early with stuck indicator
      return { ...result, stuck: true };
    }
  }
}
```

### Integration Points in Daemon Loop
```typescript
// In index.ts runLoop(), add Telegram notifications at state transitions:

// Before executing action:
if (telegram) {
  await telegram.sendProgress(`Starting: ${action.type} phase ${action.phase}`);
}

const result = await execCommand(prompt, config, currentController, stuckDetector);

// After session complete:
if (result.stuck) {
  if (telegram) {
    await telegram.sendAlert(`Agent stuck on phase ${action.phase}. Session aborted.`);
  }
  // Don't continue loop -- wait for human intervention
  break;
}

// At gate points (after verify-work):
if (action.type === 'verify') {
  if (telegram) {
    const approved = await telegram.requestGateApproval(
      `Phase ${action.phase} verification complete. Approve to continue?`
    );
    if (!approved) {
      logger.loop.info('Gate rejected by user');
      break;
    }
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Telegraf for Telegram bots | grammY | ~2022+ | Better TypeScript types, active maintenance, inline keyboard builder |
| Winston for logging | pino | Established pattern | 5x faster, JSON-native, child loggers for component isolation |
| Manual token counting for context | Agent SDK `compact_boundary` messages | Agent SDK 0.2.x | In-stream detection, no guessing |

**Deprecated/outdated:**
- `node-telegram-bot-api`: Callback-based, weaker types. grammY is the modern TypeScript choice.
- `@grammyjs/menu` for simple keyboards: Menu plugin is for complex multi-level menus. `InlineKeyboard` is sufficient for approve/reject.

## Open Questions

1. **Agent SDK tool_use message structure**
   - What we know: Messages with `type: 'assistant'` contain tool calls. The exact subtype and field names (`tool_name`, `tool_input`) need validation during implementation.
   - What's unclear: Whether tool use is a separate message type or nested in assistant content blocks. The SDK types should clarify this.
   - Recommendation: Inspect actual SDK message types during implementation. The stuck detector can be adjusted once the real field names are confirmed.

2. **Gate placement in the phase loop**
   - What we know: Gates should fire after verify-work and potentially at other decision points.
   - What's unclear: Whether gates should also fire before plan-phase (to confirm the runner should proceed to the next phase) or only after verification.
   - Recommendation: Start with gates after verify-work only. Add additional gate points in v2 if needed.

3. **Heartbeat interval tuning**
   - What we know: 30 minutes is a reasonable starting point to avoid rate limiting.
   - What's unclear: Whether the user wants more frequent heartbeats during active execution vs. less frequent during idle/waiting.
   - Recommendation: 30-minute interval as default. Configurable via `HEARTBEAT_INTERVAL_MS` env var.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | vitest 3.x |
| Config file | `gsd-runner/vitest.config.ts` (exists from Phase 1) |
| Quick run command | `cd gsd-runner && npx vitest run --reporter=verbose` |
| Full suite command | `cd gsd-runner && npx vitest run` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TELE-01 | Gate notification sent with inline keyboard | unit | `npx vitest run test/telegram.test.ts -t "sends gate notification"` | Wave 0 |
| TELE-02 | Callback query resolves gate Promise | unit | `npx vitest run test/telegram.test.ts -t "resolves gate"` | Wave 0 |
| TELE-03 | Progress notifications at state transitions | unit | `npx vitest run test/telegram.test.ts -t "progress"` | Wave 0 |
| TELE-04 | Heartbeat interval sends messages | unit | `npx vitest run test/telegram.test.ts -t "heartbeat"` | Wave 0 |
| OBSV-01 | Structured JSON logs with component child loggers | unit | `npx vitest run test/logger.test.ts` | Wave 0 |
| OBSV-02 | Stuck detection triggers on repeated tool calls | unit | `npx vitest run test/stuck-detector.test.ts` | Wave 0 |

### Sampling Rate
- **Per task commit:** `cd gsd-runner && npx vitest run --reporter=verbose`
- **Per wave merge:** `cd gsd-runner && npx vitest run`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `gsd-runner/test/telegram.test.ts` -- gate controller, progress, heartbeat tests (mock grammY Bot)
- [ ] `gsd-runner/test/stuck-detector.test.ts` -- sliding window detection tests
- [ ] `gsd-runner/test/logger.test.ts` -- child logger creation, structured output verification
- [ ] grammY installation: `cd gsd-runner && npm install grammy`

## Sources

### Primary (HIGH confidence)
- [grammY Inline Keyboards docs](https://grammy.dev/plugins/keyboard) -- InlineKeyboard class, `.text()` callback buttons, `bot.callbackQuery()` handler, `answerCallbackQuery()` requirement
- [grammY Long Polling / Deployment Types](https://grammy.dev/guide/deployment-types) -- `bot.start()` long polling, 30-second default timeout, sequential processing
- [grammY Conversations plugin](https://grammy.dev/plugins/conversations) -- `waitFor("callback_query")` pattern, `maxMilliseconds` timeout (evaluated but NOT recommended for this use case)
- [pino child loggers](https://github.com/pinojs/pino/blob/main/docs/child-loggers.md) -- `logger.child()` for component isolation
- [pino API](https://github.com/pinojs/pino/blob/main/docs/api.md) -- Log levels, structured object-first logging

### Secondary (MEDIUM confidence)
- [Agent stuck detection from 220 loops](https://dev.to/boucle2026/how-to-tell-if-your-ai-agent-is-stuck-with-real-data-from-220-loops-4d4h) -- Sliding window pattern, tool call hashing, threshold-based detection
- [Why Agents Get Stuck in Loops](https://dev.to/gantz/why-agents-get-stuck-in-loops-and-how-to-prevent-it-nob) -- Action history tracking, diversity forcing, escalation paths
- [Pino Logger Guide 2026](https://signoz.io/guides/pino-logger/) -- Production setup, TypeScript integration

### Tertiary (LOW confidence)
- Agent SDK `tool_use` message field names: Based on inference from Phase 1 research and SDK type names. Exact field names (`tool_name`, `tool_input`) need validation during implementation.
- Stuck detection thresholds (window=20, threshold=5): Based on community patterns, not empirical testing. Needs tuning.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - grammY and pino are already-chosen dependencies, APIs verified against official docs
- Architecture: HIGH - Promise-based gate controller is a standard pattern, integration points in existing code are clear
- Telegram integration: HIGH - grammY inline keyboard, callback query, and long polling patterns verified from official docs
- Stuck detection: MEDIUM - Pattern is well-documented in community, but exact Agent SDK message types for tool calls need validation
- Pitfalls: HIGH - Bot token conflicts, callback query acknowledgment, startup order all verified from official grammY docs

**Research date:** 2026-03-09
**Valid until:** 2026-04-09 (grammY is stable; Agent SDK message types may evolve)
