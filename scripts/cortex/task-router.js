#!/usr/bin/env node
'use strict';

/**
 * task-router.js — Codex task classification router
 *
 * Reads a GSD PLAN.md file, parses task XML blocks, and classifies each task
 * as "codex-safe" or "claude-required" using a 9-rule static decision tree
 * (first match wins). Output is a JSON array on stdout for machine consumption.
 *
 * Usage: node task-router.js <path-to-PLAN.md>
 *
 * Rules (first match wins):
 *   1. autonomous === false           → ALL tasks claude-required
 *   2. type starts with "checkpoint:" → claude-required
 *   3. action matches AUTH_PATTERNS   → claude-required
 *   4. files list has > 8 entries     → claude-required
 *   5. done matches SUBJECTIVE_PATTERNS → claude-required
 *   6. action matches ARCH_PATTERNS   → claude-required
 *   7. type=auto AND tdd=true         → codex-safe
 *   8. type=auto AND verify is non-empty automated command → codex-safe
 *   9. type=auto but no usable verify → claude-required
 *  10. fallback                       → claude-required
 *
 * Zero external dependencies.
 */

const fs = require('fs');
const path = require('path');

// ── Pattern constants (case-insensitive) ────────────────────────────────────
const AUTH_PATTERNS = /\b(login|authenticate|authentication|api[- _]?key|deploy|publish|credential|secret|oauth)\b/i;
const ARCH_PATTERNS = /\b(new table|schema change|new service|switch to|breaking change|migration|new database|new endpoint pattern)\b/i;
const SUBJECTIVE_PATTERNS = /\b(looks right|feels good|user[- ]friendly|appropriate|reasonable|intuitive|clean|elegant)\b/i;

// ── Rule descriptions ───────────────────────────────────────────────────────
const RULE_DESCRIPTIONS = {
  1:  'plan autonomous=false — all tasks require Claude',
  2:  'checkpoint task type requires human interaction',
  3:  'action contains auth/deploy/credential patterns',
  4:  'task touches >8 files (high complexity)',
  5:  'acceptance criteria contains subjective language',
  6:  'action contains architectural change patterns',
  7:  'type=auto with tdd=true — well-structured for Codex',
  8:  'type=auto with automated verify command',
  9:  'type=auto but no usable verify — needs Claude judgment',
  10: 'fallback — unmatched tasks default to Claude',
};

// ── PLAN.md parsing ─────────────────────────────────────────────────────────

function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) return {};
  const fm = {};
  const autonomousMatch = match[1].match(/^autonomous:\s*(true|false)/m);
  if (autonomousMatch) {
    fm.autonomous = autonomousMatch[1] === 'true';
  }
  return fm;
}

function parseTasks(content) {
  const tasks = [];
  const taskRegex = /<task\s([^>]*)>([\s\S]*?)<\/task>/g;
  let m;
  while ((m = taskRegex.exec(content)) !== null) {
    const attrs = m[1];
    const body = m[2];

    const id = (attrs.match(/id="([^"]*)"/) || [])[1] || '';
    const type = (attrs.match(/type="([^"]*)"/) || [])[1] || '';
    const tdd = (attrs.match(/tdd="([^"]*)"/) || [])[1] || '';

    const name = extractElement(body, 'name');
    const action = extractElement(body, 'action');
    const files = extractElement(body, 'files');
    const verify = extractVerify(body);
    const done = extractElement(body, 'done') || extractElement(body, 'acceptance_criteria');

    tasks.push({ id, type, tdd, name, action, files, verify, done });
  }
  return tasks;
}

function extractElement(body, tagName) {
  const re = new RegExp(`<${tagName}>([\\s\\S]*?)<\\/${tagName}>`);
  const m = body.match(re);
  return m ? m[1].trim() : '';
}

function extractVerify(body) {
  // Try <verify><automated>...</automated></verify> first
  const automatedMatch = body.match(/<verify>\s*<automated>([\s\S]*?)<\/automated>\s*<\/verify>/);
  if (automatedMatch) return automatedMatch[1].trim();
  // Fallback to plain <verify>...</verify>
  const plainMatch = body.match(/<verify>([\s\S]*?)<\/verify>/);
  if (plainMatch) return plainMatch[1].trim();
  return '';
}

function countFiles(filesStr) {
  if (!filesStr) return 0;
  return filesStr
    .split(/[,\n]/)
    .map(f => f.trim())
    .filter(f => f.length > 0)
    .length;
}

// ── Classification engine ───────────────────────────────────────────────────

function classifyTask(task, planAutonomous) {
  // Rule 1: plan-level autonomous=false
  if (planAutonomous === false) {
    return { classification: 'claude-required', matched_rule: 1 };
  }

  // Rule 2: checkpoint type
  if (task.type.startsWith('checkpoint:')) {
    return { classification: 'claude-required', matched_rule: 2 };
  }

  // Rule 3: auth patterns in action
  if (AUTH_PATTERNS.test(task.action)) {
    return { classification: 'claude-required', matched_rule: 3 };
  }

  // Rule 4: >8 files
  if (countFiles(task.files) > 8) {
    return { classification: 'claude-required', matched_rule: 4 };
  }

  // Rule 5: subjective acceptance criteria
  if (SUBJECTIVE_PATTERNS.test(task.done)) {
    return { classification: 'claude-required', matched_rule: 5 };
  }

  // Rule 6: architectural patterns in action
  if (ARCH_PATTERNS.test(task.action)) {
    return { classification: 'claude-required', matched_rule: 6 };
  }

  // Rule 7: auto + tdd
  if (task.type === 'auto' && task.tdd === 'true') {
    return { classification: 'codex-safe', matched_rule: 7 };
  }

  // Rule 8: auto + automated verify
  if (task.type === 'auto' && task.verify && task.verify !== 'MISSING' && task.verify.length > 0) {
    return { classification: 'codex-safe', matched_rule: 8 };
  }

  // Rule 9: auto but no usable verify
  if (task.type === 'auto') {
    return { classification: 'claude-required', matched_rule: 9 };
  }

  // Rule 10: fallback
  return { classification: 'claude-required', matched_rule: 10 };
}

// ── Main ────────────────────────────────────────────────────────────────────

function main() {
  const planPath = process.argv[2];

  if (!planPath) {
    process.stderr.write('Usage: task-router.js <path-to-PLAN.md>\n');
    process.exit(1);
  }

  if (!fs.existsSync(planPath)) {
    process.stderr.write(`Error: File not found: ${planPath}\n`);
    process.exit(1);
  }

  const content = fs.readFileSync(planPath, 'utf8');
  const frontmatter = parseFrontmatter(content);
  const tasks = parseTasks(content);

  const results = [];

  for (const task of tasks) {
    const { classification, matched_rule } = classifyTask(task, frontmatter.autonomous);
    const rule_description = RULE_DESCRIPTIONS[matched_rule];

    const entry = {
      task_id: task.id,
      task_name: task.name,
      classification,
      matched_rule,
      rule_description,
    };

    results.push(entry);
    process.stderr.write(
      `[task-router] Task ${task.id} "${task.name}" → ${classification} (Rule ${matched_rule}: ${rule_description})\n`
    );
  }

  process.stdout.write(JSON.stringify(results, null, 2) + '\n');
}

main();
