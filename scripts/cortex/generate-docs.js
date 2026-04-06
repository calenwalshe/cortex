#!/usr/bin/env node
// generate-docs.js — Regenerate COMMANDS.md, CORTEX.md count, README.md count from command-registry.json
//
// Usage: node scripts/cortex/generate-docs.js [--dry-run]
// --dry-run: print what would change without writing files

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const REGISTRY_PATH = path.join(ROOT, 'command-registry.json');
const COMMANDS_PATH = path.join(ROOT, 'docs', 'COMMANDS.md');
const CORTEX_PATH = path.join(ROOT, 'CORTEX.md');
const README_PATH = path.join(ROOT, 'README.md');

const dryRun = process.argv.includes('--dry-run');

// ── Load registry ───────────────────────────────────────────────────────────

const registry = JSON.parse(fs.readFileSync(REGISTRY_PATH, 'utf8'));
const commands = registry.commands;
const count = commands.length;

// ── Sort: spine by position, then validation, then utility ──────────────────

const categoryOrder = { spine: 0, validation: 1, utility: 2 };
const sorted = [...commands].sort((a, b) => {
  const catDiff = (categoryOrder[a.category] || 9) - (categoryOrder[b.category] || 9);
  if (catDiff !== 0) return catDiff;
  if (a.spine_position && b.spine_position) return a.spine_position - b.spine_position;
  if (a.spine_position) return -1;
  if (b.spine_position) return 1;
  return a.name.localeCompare(b.name);
});

// ── Generate COMMANDS.md ────────────────────────────────────────────────────

function generateInputsTable(inputs) {
  if (!inputs || inputs.length === 0) return '';
  let md = '**Inputs**\n\n';
  md += '| Argument | Required | Description | Default |\n';
  md += '|----------|----------|-------------|---------|\n';
  for (const inp of inputs) {
    const def = inp.default || '—';
    const vals = inp.values ? ` (${inp.values.join(', ')})` : '';
    md += `| \`${inp.name}\` | ${inp.required ? 'Required' : 'Optional'} | ${inp.description}${vals} | ${def} |\n`;
  }
  return md + '\n';
}

function generateOutputsTable(outputs) {
  if (!outputs || outputs.length === 0) return '';
  let md = '**Outputs**\n\n';
  md += '| Artifact | Path | Contents |\n';
  md += '|----------|------|---------|\n';
  for (const out of outputs) {
    md += `| ${out.artifact} | \`${out.path_pattern}\` | ${out.contents_summary} |\n`;
  }
  return md + '\n';
}

function generateStateEffects(effects) {
  if (!effects || effects.length === 0) return '';
  let md = '**State Effects**\n\n';
  md += '| Field | Operation | Value |\n';
  md += '|-------|-----------|-------|\n';
  for (const se of effects) {
    const val = se.value === null ? '`null`' : `\`${se.value}\``;
    md += `| \`${se.field}\` | ${se.operation} | ${val} |\n`;
  }
  return md + '\n';
}

function generateBlockConditions(conditions) {
  if (!conditions || conditions.length === 0) return '**Block Conditions**\n- None\n\n';
  let md = '**Block Conditions**\n';
  for (const bc of conditions) {
    md += `- ${bc}\n`;
  }
  return md + '\n';
}

function generateCommandSection(cmd) {
  let md = `## /${cmd.name}\n\n`;
  md += `**Syntax**\n\`\`\`bash\n${cmd.syntax}\n\`\`\`\n\n`;
  md += `**Purpose**\n${cmd.purpose}\n\n`;
  md += generateInputsTable(cmd.inputs);
  md += generateOutputsTable(cmd.outputs);
  md += generateStateEffects(cmd.state_effects);
  md += generateBlockConditions(cmd.block_conditions);
  return md;
}

// Build spine string
const spineCommands = sorted.filter(c => c.category === 'spine' && c.spine_position);
const spineStr = spineCommands.map(c => `\`/cortex-${c.name.replace('cortex-', '')}\``).join(' → ');

let commandsMd = `# Cortex Command Reference

All commands write artifacts to the target project repo (the repo where Cortex is installed and used). The Cortex framework repo itself is not modified by command invocations.

Commands follow the intelligence spine: ${spineStr}. Validation commands (\`/cortex-investigate\`, \`/cortex-review\`, \`/cortex-audit\`) and utility commands (\`/cortex-status\`, \`/cortex-fit\`, \`/cortex-stash\`, \`/cortex-drive\`, \`/cortex-intent\`) can be invoked at any point.

<!-- THIS FILE IS AUTO-GENERATED from command-registry.json -->
<!-- Do not edit manually. Run: node scripts/cortex/generate-docs.js -->

---

`;

for (const cmd of sorted) {
  commandsMd += generateCommandSection(cmd);
  commandsMd += '---\n\n';
}

// ── Generate Flag Reference ─────────────────────────────────────────────────

const allFlags = [];
for (const cmd of sorted) {
  if (!cmd.inputs) continue;
  for (const inp of cmd.inputs) {
    if (inp.name.startsWith('--')) {
      allFlags.push({
        flag: inp.name,
        command: `\`/${cmd.name}\``,
        values: inp.values ? inp.values.join(' \\| ') : '(flag — no value)',
        description: inp.description,
      });
    }
  }
}

if (allFlags.length > 0) {
  commandsMd += '## Flag Reference\n\n';
  commandsMd += '| Flag | Commands | Values | Description |\n';
  commandsMd += '|------|----------|--------|-------------|\n';
  for (const f of allFlags) {
    commandsMd += `| \`${f.flag}\` | ${f.command} | ${f.values} | ${f.description} |\n`;
  }
  commandsMd += '\n---\n\n';
}

// ── Generate Artifact Path Quick Reference ──────────────────────────────────

commandsMd += `## Artifact Path Quick Reference

All paths below are relative to the **target project repo**.

\`\`\`
docs/cortex/
`;

const pathSet = new Set();
for (const cmd of sorted) {
  if (!cmd.outputs) continue;
  for (const out of cmd.outputs) {
    if (out.path_pattern.startsWith('docs/cortex/')) {
      pathSet.add(out.path_pattern.replace('docs/cortex/', ''));
    }
  }
}
for (const p of [...pathSet].sort()) {
  commandsMd += `├── ${p}\n`;
}

commandsMd += `
.cortex/
├── state.json
└── compaction/
    └── precompact-<timestamp>.md
\`\`\`

See \`docs/CONTINUITY.md\` for continuity file schemas and \`docs/EVALS.md\` for the eval artifact lifecycle.
`;

// ── Write or diff ───────────────────────────────────────────────────────────

if (dryRun) {
  console.log(`[dry-run] Would write ${commandsMd.length} chars to docs/COMMANDS.md`);
  console.log(`[dry-run] Would update CORTEX.md: N-Command Surface → ${count}-Command Surface`);
  console.log(`[dry-run] Would update README.md: N commands → ${count} commands`);
  process.exit(0);
}

fs.writeFileSync(COMMANDS_PATH, commandsMd);
console.log(`Generated docs/COMMANDS.md (${count} commands, ${commandsMd.length} chars)`);

// ── Update CORTEX.md count ──────────────────────────────────────────────────

let cortex = fs.readFileSync(CORTEX_PATH, 'utf8');
cortex = cortex.replace(/\d+-Command Surface/g, `${count}-Command Surface`);
cortex = cortex.replace(/\d+ commands total/g, `${count} commands total`);
cortex = cortex.replace(/via \d+ commands/g, `via ${count} commands`);
cortex = cortex.replace(/# \d+-command reference/g, `# ${count}-command reference`);
fs.writeFileSync(CORTEX_PATH, cortex);
console.log(`Updated CORTEX.md (${count}-Command Surface)`);

// ── Update README.md count ──────────────────────────────────────────────────

let readme = fs.readFileSync(README_PATH, 'utf8');
readme = readme.replace(/\d+-Command Surface/g, `${count}-Command Surface`);
readme = readme.replace(/adds \d+ commands/g, `adds ${count} commands`);
fs.writeFileSync(README_PATH, readme);
console.log(`Updated README.md (${count} commands)`);
