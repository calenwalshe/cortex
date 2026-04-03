#!/usr/bin/env node
// token-ledger.js — PostToolUse hook for per-turn token tracking
//
// Reads the last assistant turn from the session JSONL transcript,
// computes cost via pricing.json, and writes to ~/.cortex/token-ledger.db.
//
// Performance: tail-read last 8KB (O(1)), dedup via /tmp file, single
// better-sqlite3 transaction (~0.5ms). Total hook logic <5ms (TE-05).
//
// Error handling: exits 0 on ANY error — never blocks tool execution.

const fs = require('fs');
const path = require('path');
const os = require('os');

// ── early guard: better-sqlite3 must be available ───────────────────────────
let Database;
try {
  Database = require('better-sqlite3');
} catch (e) {
  process.exit(0);
}

// ── stdin with 10s timeout (matches gsd-context-monitor.js pattern) ─────────
let input = '';
const stdinTimeout = setTimeout(() => process.exit(0), 10000);
process.stdin.setEncoding('utf8');
process.stdin.on('data', chunk => input += chunk);
process.stdin.on('end', () => {
  clearTimeout(stdinTimeout);
  try {
    main(JSON.parse(input));
  } catch (e) {
    process.exit(0);
  }
});

function main(data) {
  // ── a. parse stdin fields ─────────────────────────────────────────────────
  const sessionId = data.session_id;
  if (!sessionId) process.exit(0);

  const cwd = data.cwd || process.cwd();
  const remainingPct = data.context_window
    ? data.context_window.remaining_percentage
    : null;
  const toolName = data.tool_name || null;

  // ── b. resolve transcript path ────────────────────────────────────────────
  const slug = cwd.replace(/^\//, '').replace(/\//g, '-') || 'root';
  const claudeDir = path.join(os.homedir(), '.claude', 'projects', `-${slug}`);
  // Claude Code uses the pattern: ~/.claude/projects/{slug}/{session_id}.jsonl
  // The slug is the cwd path with / replaced by - and prefixed with -
  // But also try without the leading dash for compatibility
  let transcriptPath = path.join(claudeDir, `${sessionId}.jsonl`);
  if (!fs.existsSync(transcriptPath)) {
    const altDir = path.join(os.homedir(), '.claude', 'projects', slug);
    transcriptPath = path.join(altDir, `${sessionId}.jsonl`);
    if (!fs.existsSync(transcriptPath)) {
      process.exit(0);
    }
  }

  // ── c. tail-read last 8KB ─────────────────────────────────────────────────
  const fd = fs.openSync(transcriptPath, 'r');
  const stat = fs.fstatSync(fd);
  const readSize = 8192;
  const offset = Math.max(0, stat.size - readSize);
  const buf = Buffer.alloc(Math.min(readSize, stat.size));
  fs.readSync(fd, buf, 0, buf.length, offset);
  fs.closeSync(fd);

  const tail = buf.toString('utf8');
  const lines = tail.split('\n').filter(Boolean);

  // ── d. extract last assistant turn ────────────────────────────────────────
  // Group by message.id, keep last occurrence of each (has complete usage)
  const byMid = new Map();
  for (const line of lines) {
    try {
      const entry = JSON.parse(line);
      if (entry.type === 'assistant' && entry.message && entry.message.id) {
        byMid.set(entry.message.id, entry);
      }
    } catch (e) {
      // skip unparseable lines (e.g., partial first line from tail-read)
    }
  }

  if (byMid.size === 0) process.exit(0);

  // Get the last message_id in insertion order
  let lastMid, lastEntry;
  for (const [mid, entry] of byMid) {
    lastMid = mid;
    lastEntry = entry;
  }

  const msg = lastEntry.message;
  const usage = msg.usage || {};
  const model = msg.model || 'unknown';
  const inputTokens = usage.input_tokens || 0;
  const outputTokens = usage.output_tokens || 0;
  const cacheCreationTokens = usage.cache_creation_input_tokens || 0;
  const cacheReadTokens = usage.cache_read_input_tokens || 0;

  // ── e. dedup check via /tmp file ──────────────────────────────────────────
  const dedupPath = path.join(os.tmpdir(), `ledger-last-${sessionId}`);
  let prevData = null;
  try {
    const raw = fs.readFileSync(dedupPath, 'utf8');
    prevData = JSON.parse(raw);
    if (prevData.mid === lastMid) {
      process.exit(0);
    }
  } catch (e) {
    // No previous data or parse error — continue
  }

  // Write current message_id + remaining_pct for next invocation
  try {
    fs.writeFileSync(dedupPath, JSON.stringify({ mid: lastMid, pct: remainingPct }));
  } catch (e) {
    // Non-fatal
  }

  // ── f. cost computation ───────────────────────────────────────────────────
  const pricingPath = path.join(__dirname, '..', 'scripts', 'cortex', 'pricing.json');
  let pricing;
  try {
    pricing = JSON.parse(fs.readFileSync(pricingPath, 'utf8'));
  } catch (e) {
    process.exit(0);
  }

  const rates = pricing[model] || pricing._default;
  const costUsd = (inputTokens * rates.input)
    + (outputTokens * rates.output)
    + (cacheCreationTokens * rates.cache_write)
    + (cacheReadTokens * rates.cache_read);

  // ── g. phase extraction ───────────────────────────────────────────────────
  let phase = null;
  try {
    const statePath = path.join(cwd, '.planning', 'STATE.md');
    const stateContent = fs.readFileSync(statePath, 'utf8');
    const m = stateContent.match(/^Phase:\s*(.+)$/m);
    if (m) phase = m[1].trim();
  } catch (e) {
    // No STATE.md or parse error
  }

  // ── h. project slug ──────────────────────────────────────────────────────
  const projectSlug = slug;

  // ── i. DB write (single transaction) ──────────────────────────────────────
  const dbPath = process.env.TOKEN_LEDGER_DB
    || path.join(os.homedir(), '.cortex', 'token-ledger.db');

  if (!fs.existsSync(dbPath)) process.exit(0);

  const db = new Database(dbPath);
  db.pragma('journal_mode = WAL');

  const today = new Date().toISOString().slice(0, 10);

  const txn = db.transaction(() => {
    // Insert turn
    db.prepare(`
      INSERT INTO claude_turns
        (session_id, message_id, model, input_tokens, output_tokens,
         cache_creation_tokens, cache_read_tokens, cost_usd,
         project_slug, cwd, phase, skill, remaining_pct)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      sessionId, lastMid, model, inputTokens, outputTokens,
      cacheCreationTokens, cacheReadTokens, costUsd,
      projectSlug, cwd, phase, toolName, remainingPct
    );

    // Upsert session
    db.prepare(`
      INSERT OR IGNORE INTO sessions (session_id, project_slug, model)
      VALUES (?, ?, ?)
    `).run(sessionId, projectSlug, model);

    db.prepare(`
      UPDATE sessions
      SET total_input = total_input + ?,
          total_output = total_output + ?,
          total_cost = total_cost + ?
      WHERE session_id = ?
    `).run(inputTokens, outputTokens, costUsd, sessionId);

    // Upsert daily rollup
    db.prepare(`
      INSERT INTO daily_rollup (date, provider, model, project_slug, phase,
                                input_tokens, output_tokens, cost_usd, turn_count)
      VALUES (?, 'claude', ?, ?, ?, ?, ?, ?, 1)
      ON CONFLICT(date, provider, model, project_slug, phase)
      DO UPDATE SET
        input_tokens = input_tokens + excluded.input_tokens,
        output_tokens = output_tokens + excluded.output_tokens,
        cost_usd = cost_usd + excluded.cost_usd,
        turn_count = turn_count + 1
    `).run(today, model, projectSlug, phase || '', inputTokens, outputTokens, costUsd);
  });

  txn();

  // ── j. compaction detection ───────────────────────────────────────────────
  if (remainingPct != null && prevData && prevData.pct != null) {
    const jump = remainingPct - prevData.pct;
    if (jump > 30) {
      try {
        db.prepare('UPDATE sessions SET compacted = 1 WHERE session_id = ?')
          .run(sessionId);
      } catch (e) {
        // Non-fatal
      }
    }
  }

  db.close();

  // ── k. exit silently (async hook, no output needed) ───────────────────────
  process.exit(0);
}
