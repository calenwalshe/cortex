#!/usr/bin/env node
// cortex-postcompact.js — PostCompact hook
//
// 1. Preserves existing behavior: writes last-compact-summary.md and next-prompt.md
// 2. Extracts atomic facts from Cortex artifacts into .cortex/facts.jsonl
//
// Fact categories: decision, preference, constraint, pattern, blocker, context_pointer
// Deduplication: content hash (first 8 chars of MD5)
// Performance budget: <5 seconds total

'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PROJECT_DIR = process.env.CLAUDE_PROJECT_DIR || process.cwd();
const CORTEX_DIR = path.join(PROJECT_DIR, '.cortex');
const HANDOFFS_DIR = path.join(PROJECT_DIR, 'docs', 'cortex', 'handoffs');
const STATE_JSON_PATH = path.join(CORTEX_DIR, 'state.json');
const FACTS_PATH = path.join(CORTEX_DIR, 'facts.jsonl');
const COMPACTION_DIR = path.join(CORTEX_DIR, 'compaction');
const DECISIONS_PATH = path.join(HANDOFFS_DIR, 'decisions.md');
const PLANNING_STATE_PATH = path.join(PROJECT_DIR, '.planning', 'STATE.md');

// ── helpers ──────────────────────────────────────────────────────────────────

function readFileOr(filePath, fallback) {
  try { return fs.readFileSync(filePath, 'utf8'); } catch { return fallback; }
}

function readJson(filePath) {
  try { return JSON.parse(fs.readFileSync(filePath, 'utf8')); } catch { return {}; }
}

function contentHash(text) {
  return crypto.createHash('md5').update(text.trim()).digest('hex').slice(0, 8);
}

function timestamp() {
  return new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d+Z$/, 'Z');
}

function ensureDir(dir) {
  try { fs.mkdirSync(dir, { recursive: true }); } catch {}
}

// ── Phase 1: Preserve existing behavior ──────────────────────────────────────

function writeExistingOutputs(state, ts) {
  ensureDir(HANDOFFS_DIR);

  const slug = state.slug || '(none)';
  const mode = state.mode || 'clarify';
  const contract = state.active_contract || '(none)';

  // Find latest precompact snapshot
  let latestSnapshot = '';
  try {
    const files = fs.readdirSync(COMPACTION_DIR)
      .filter(f => f.startsWith('precompact-'))
      .sort()
      .reverse();
    if (files.length) latestSnapshot = path.join(COMPACTION_DIR, files[0]);
  } catch {}

  // last-compact-summary.md
  const summary = [
    `# Last Compact Summary: ${ts}`,
    '',
    `**Compaction occurred at:** ${ts}`,
    `**Active slug:** ${slug}`,
    `**Mode at compaction:** ${mode}`,
    `**Active contract:** ${contract}`,
    '',
    latestSnapshot ? `**Pre-compaction snapshot:** ${latestSnapshot}` : '',
    '',
    'Run /cortex-status to reconstruct full working state.',
  ].join('\n');

  fs.writeFileSync(path.join(HANDOFFS_DIR, 'last-compact-summary.md'), summary);

  // next-prompt.md
  const nextPrompt = [
    `We are working on ${slug} in ${mode} mode.`,
    contract !== '(none)' ? `The active contract is at ${contract}.` : '',
    `Context was compacted at ${ts}.`,
    'Run /cortex-status to see the full current state and next recommended action.',
  ].filter(Boolean).join('\n');

  fs.writeFileSync(path.join(HANDOFFS_DIR, 'next-prompt.md'), nextPrompt);
}

// ── Phase 2: Extract facts ───────────────────────────────────────────────────

function extractFacts(state, ts) {
  const slug = state.slug || 'unknown';
  const facts = [];

  // Helper to create a fact object
  function makeFact(type, text, source) {
    const hash = contentHash(text);
    return {
      id: `fact-${ts}-${hash}`,
      type,
      slug,
      text: text.trim(),
      source,
      extracted_at: ts,
      session_context: `${slug} ${state.mode || 'unknown'} phase`,
    };
  }

  // ── 2a. Extract decisions from decisions.md ────────────────────────────
  const decisions = readFileOr(DECISIONS_PATH, '');
  if (decisions) {
    // Parse Decision Log section — each "- " line is a decision
    const logSection = decisions.split('## Decision Log')[1] || '';
    const beforeNext = logSection.split(/^## /m)[0] || logSection;
    const lines = beforeNext.split('\n').filter(l => /^- /.test(l.trim()));
    for (const line of lines) {
      const text = line.replace(/^- /, '').trim();
      if (text && text !== '(No decisions recorded — no work item in progress)') {
        facts.push(makeFact('decision', text, 'docs/cortex/handoffs/decisions.md'));
      }
    }

    // Parse Autonomy Decisions — each line is a decision
    const autoSection = decisions.split('## Autonomy Decisions')[1] || '';
    const autoBeforeNext = autoSection.split(/^## /m)[0] || autoSection;
    const autoLines = autoBeforeNext.split('\n').filter(l => /^- \d/.test(l.trim()));
    for (const line of autoLines) {
      const text = line.replace(/^- /, '').trim();
      if (text) {
        facts.push(makeFact('decision', `Autonomy: ${text}`, 'docs/cortex/handoffs/decisions.md'));
      }
    }
  }

  // ── 2b. Extract from STATE.md accumulated context ──────────────────────
  const planState = readFileOr(PLANNING_STATE_PATH, '');
  if (planState) {
    // Decisions section
    const decMatch = planState.match(/### Decisions\n([\s\S]*?)(?=\n### |\n## )/);
    if (decMatch) {
      const lines = decMatch[1].split('\n').filter(l => /\S/.test(l) && !/^None/.test(l.trim()));
      for (const line of lines) {
        const text = line.replace(/^[-*] /, '').trim();
        if (text) facts.push(makeFact('decision', text, '.planning/STATE.md'));
      }
    }

    // Blockers section
    const blockMatch = planState.match(/### Blockers\/Concerns\n([\s\S]*?)(?=\n### |\n## )/);
    if (blockMatch) {
      const lines = blockMatch[1].split('\n').filter(l => /\S/.test(l) && !/^None/.test(l.trim()));
      for (const line of lines) {
        const text = line.replace(/^[-*] /, '').trim();
        if (text) facts.push(makeFact('blocker', text, '.planning/STATE.md'));
      }
    }
  }

  // ── 2c. Extract from CONTEXT.md files ──────────────────────────────────
  const phasesDir = path.join(PROJECT_DIR, '.planning', 'phases');
  try {
    const phaseDirs = fs.readdirSync(phasesDir).sort().reverse().slice(0, 3);
    for (const dir of phaseDirs) {
      const ctxFiles = fs.readdirSync(path.join(phasesDir, dir))
        .filter(f => f.endsWith('-CONTEXT.md'));
      for (const ctxFile of ctxFiles) {
        const content = readFileOr(path.join(phasesDir, dir, ctxFile), '');
        const source = `.planning/phases/${dir}/${ctxFile}`;

        // Extract decisions section
        const decSection = content.match(/<decisions>([\s\S]*?)<\/decisions>/);
        if (decSection) {
          const lines = decSection[1].split('\n').filter(l => /^- /.test(l.trim()));
          for (const line of lines) {
            const text = line.replace(/^- /, '').trim();
            if (text) facts.push(makeFact('preference', text, source));
          }
        }

        // Extract specifics section for constraints/preferences
        const specSection = content.match(/<specifics>([\s\S]*?)<\/specifics>/);
        if (specSection) {
          const lines = specSection[1].split('\n').filter(l => /^- /.test(l.trim()));
          for (const line of lines) {
            const text = line.replace(/^- /, '').trim();
            if (text && !/^No specific/.test(text)) {
              facts.push(makeFact('constraint', text, source));
            }
          }
        }
      }
    }
  } catch {}

  // ── 2d. Extract from git log ───────────────────────────────────────────
  try {
    const { execSync } = require('child_process');
    const gitLog = execSync('git log --oneline -20', {
      cwd: PROJECT_DIR,
      encoding: 'utf8',
      timeout: 3000,
    }).trim();
    if (gitLog) {
      const commits = gitLog.split('\n').slice(0, 10);
      for (const commit of commits) {
        facts.push(makeFact('context_pointer', `Recent commit: ${commit}`, 'git log'));
      }
    }
  } catch {}

  // ── 2e. Extract artifact paths as context pointers ─────────────────────
  if (state.artifacts && Array.isArray(state.artifacts)) {
    for (const artifact of state.artifacts) {
      facts.push(makeFact('context_pointer', `Artifact: ${artifact}`, '.cortex/state.json'));
    }
  }

  return facts;
}

// ── Phase 3: Deduplicate and append to facts.jsonl ───────────────────────────

function appendFacts(facts) {
  ensureDir(CORTEX_DIR);

  // Load existing hashes for dedup
  const existingHashes = new Set();
  try {
    const existing = fs.readFileSync(FACTS_PATH, 'utf8').trim();
    if (existing) {
      for (const line of existing.split('\n')) {
        try {
          const fact = JSON.parse(line);
          // Extract hash from id: fact-{ts}-{hash}
          const hash = fact.id.split('-').pop();
          existingHashes.add(hash);
        } catch {}
      }
    }
  } catch {}

  // Filter duplicates and append
  const newFacts = facts.filter(f => {
    const hash = contentHash(f.text);
    return !existingHashes.has(hash);
  });

  if (newFacts.length > 0) {
    const lines = newFacts.map(f => JSON.stringify(f)).join('\n') + '\n';
    fs.appendFileSync(FACTS_PATH, lines);
  }

  return newFacts.length;
}

// ── supervisor logging ──────────────────────────────────────────────────────

function supervisorLog(event, extra) {
  try {
    const logPath = path.join(CORTEX_DIR, 'supervisor.jsonl');
    const state = readJson(STATE_JSON_PATH);
    const entry = JSON.stringify({
      ts: timestamp(), event, hook: 'cortex-postcompact',
      slug: state.slug || '', mode: state.mode || '', ...extra,
    });
    fs.appendFileSync(logPath, entry + '\n');
  } catch {}
}

// ── main ─────────────────────────────────────────────────────────────────────

supervisorLog('hook_fire');

try {
  const ts = timestamp();
  const state = readJson(STATE_JSON_PATH);

  // Phase 1: existing outputs
  writeExistingOutputs(state, ts);

  // Phase 2: extract facts
  const facts = extractFacts(state, ts);

  // Phase 3: deduplicate and append
  const newCount = appendFacts(facts);

  if (newCount > 0) {
    process.stderr.write(`[cortex-postcompact] Extracted ${newCount} new facts to ${FACTS_PATH}\n`);
  }
} catch (e) {
  // Never block compaction — exit 0 on any error
  supervisorLog('hook_error', { error: e.message });
  process.stderr.write(`[cortex-postcompact] Error (non-fatal): ${e.message}\n`);
}

process.exit(0);
