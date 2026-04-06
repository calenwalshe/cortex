#!/usr/bin/env node
// cortex-postcompact.js — PostCompact hook
//
// 1. Preserves existing behavior: writes last-compact-summary.md and next-prompt.md
// 2. Extracts atomic facts from Cortex artifacts into .cortex/facts.jsonl
//
// Fact categories: decision, preference, constraint, pattern, blocker, context_pointer, procedure, lesson, observation
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

  // ── 2d. Extract from git log (limited to substantive commits) ──────────
  try {
    const { execSync } = require('child_process');
    const gitLog = execSync('git log --oneline -10', {
      cwd: PROJECT_DIR,
      encoding: 'utf8',
      timeout: 3000,
    }).trim();
    if (gitLog) {
      const commits = gitLog.split('\n').slice(0, 5);
      for (const commit of commits) {
        // Only extract feat/fix commits, skip chore/docs
        if (/^[a-f0-9]+ (feat|fix)\(/.test(commit)) {
          facts.push(makeFact('context_pointer', `Shipped: ${commit}`, 'git log'));
        }
      }
    }
  } catch {}

  // ── 2e. Extract from contract Failed Approaches (E4: lessons) ─────────
  try {
    const contractsDir = path.join(PROJECT_DIR, 'docs', 'cortex', 'contracts', slug);
    const contractFiles = fs.readdirSync(contractsDir)
      .filter(f => f.match(/^contract-\d+\.md$/))
      .sort();
    for (const cf of contractFiles) {
      const content = readFileOr(path.join(contractsDir, cf), '');
      const failedMatch = content.match(/## Failed Approaches\n([\s\S]*?)(?=\n## )/);
      if (failedMatch) {
        const entries = failedMatch[1].split(/### Attempt/);
        for (const entry of entries) {
          const approachMatch = entry.match(/\*\*Approach:\*\*\s*(.*)/);
          const resultMatch = entry.match(/\*\*Result:\*\*\s*(.*)/);
          const causeMatch = entry.match(/\*\*Root cause:\*\*\s*(.*)/);
          if (approachMatch && resultMatch) {
            const text = `Tried: ${approachMatch[1].trim()}. Result: ${resultMatch[1].trim()}.${causeMatch ? ` Root cause: ${causeMatch[1].trim()}.` : ''}`;
            facts.push(makeFact('lesson', text, `docs/cortex/contracts/${slug}/${cf}`));
          }
        }
      }
    }
  } catch {}

  // ── 2f. Extract from investigation artifacts (E4: lessons + observations)
  try {
    const invDir = path.join(PROJECT_DIR, 'docs', 'cortex', 'investigations', slug);
    const invFiles = fs.readdirSync(invDir).filter(f => f.endsWith('.md')).slice(-3);
    for (const inv of invFiles) {
      const content = readFileOr(path.join(invDir, inv), '');
      const source = `docs/cortex/investigations/${slug}/${inv}`;

      // Root cause → observation
      const rcMatch = content.match(/## Root Cause\n([\s\S]*?)(?=\n## )/);
      if (rcMatch) {
        const text = rcMatch[1].trim().split('\n')[0];
        if (text && text.length > 20) facts.push(makeFact('observation', text, source));
      }

      // Repair recommendation → procedure
      const repairMatch = content.match(/## Repair Recommendation\n([\s\S]*?)(?=\n## |$)/);
      if (repairMatch) {
        const lines = repairMatch[1].split('\n').filter(l => /^\d+\. /.test(l.trim()));
        if (lines.length > 0) {
          const text = `Repair approach: ${lines.map(l => l.replace(/^\d+\. /, '').trim()).join('; ')}`;
          facts.push(makeFact('procedure', text, source));
        }
      }
    }
  } catch {}

  // ── 2g. Extract from research dossier recommendations (E4: observations)
  try {
    const resDir = path.join(PROJECT_DIR, 'docs', 'cortex', 'research', slug);
    const resFiles = fs.readdirSync(resDir).filter(f => f.endsWith('.md')).slice(-3);
    for (const rf of resFiles) {
      const content = readFileOr(path.join(resDir, rf), '');
      const source = `docs/cortex/research/${slug}/${rf}`;

      // Recommendations → observations
      const recMatch = content.match(/## Recommend(?:ed|ation)([\s\S]*?)(?=\n## |$)/);
      if (recMatch) {
        const lines = recMatch[1].split('\n').filter(l => /^\d+\. /.test(l.trim()));
        for (const line of lines.slice(0, 5)) {
          const text = line.replace(/^\d+\. /, '').replace(/\*\*/g, '').trim();
          if (text.length > 30) facts.push(makeFact('observation', text, source));
        }
      }
    }
  } catch {}

  // ── Quality filter: remove noise ──────────────────────────────────────
  return facts.filter(f => {
    const t = f.text;
    // Skip short facts
    if (t.length < 20) return false;
    // Skip bare section headings
    if (/^#{1,3} /.test(t)) return false;
    // Skip bare file paths or commit hashes with no context
    if (/^[a-f0-9]{7,40}$/.test(t)) return false;
    // Skip generic "no X" entries
    if (/^No (specific|active|decisions|blockers)/.test(t)) return false;
    // Skip artifact-only pointers with no substantive content
    if (/^Artifact: /.test(t) && t.split('/').length > 3 && t.length < 80) return false;
    return true;
  });
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
