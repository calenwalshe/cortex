#!/usr/bin/env node
'use strict';

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = os.homedir();
const CORTEX_LOCAL = path.join(HOME, 'projects', 'cortex');
const CLAUDE_DIR = path.join(HOME, '.claude');
const CORTEX_REPO = 'https://github.com/calenwalshe/cortex.git';

const args = process.argv.slice(2);
const VERBOSE = args.includes('--verbose') || args.includes('-v');
const DRY_RUN = args.includes('--dry-run');

const results = [];

function log(msg) {
  if (VERBOSE) console.log(msg);
}

function record(label, status, note = '') {
  results.push({ label, status, note });
}

function run(cmd, opts = {}) {
  if (DRY_RUN) { log(`[dry-run] ${cmd}`); return ''; }
  try {
    return execSync(cmd, { stdio: VERBOSE ? 'inherit' : 'pipe', ...opts }).toString().trim();
  } catch (err) {
    throw new Error(`Command failed: ${cmd}\n${err.message}`);
  }
}

// 1. Clone repo with submodules
function installRepo() {
  if (fs.existsSync(path.join(CORTEX_LOCAL, '.git'))) {
    log('Cortex already cloned — skipping');
    record('Clone repo', 'skipped', 'already exists at ~/projects/cortex');
    return;
  }
  log(`Cloning ${CORTEX_REPO} → ${CORTEX_LOCAL}`);
  if (!DRY_RUN) fs.mkdirSync(path.dirname(CORTEX_LOCAL), { recursive: true });
  run(`git clone --recurse-submodules ${CORTEX_REPO} ${CORTEX_LOCAL}`);
  record('Clone repo', 'installed', '~/projects/cortex');
}

// 2. Symlink cortex-* skills into ~/.claude/skills/
function installSkills() {
  const skillsDir = path.join(CLAUDE_DIR, 'skills');
  const srcDir = path.join(CORTEX_LOCAL, 'skills');

  if (!DRY_RUN) fs.mkdirSync(skillsDir, { recursive: true });

  const skills = fs.readdirSync(srcDir).filter(d => d.startsWith('cortex-'));
  let installed = 0, skipped = 0;

  for (const skill of skills) {
    const target = path.join(skillsDir, skill);
    const src = path.join(srcDir, skill);
    if (fs.existsSync(target) || fs.lstatSync(src).isSymbolicLink() && fs.existsSync(target)) {
      skipped++;
      log(`  skill ${skill} — already exists`);
      continue;
    }
    if (!DRY_RUN) fs.symlinkSync(src, target);
    log(`  skill ${skill} — linked`);
    installed++;
  }

  record(
    'Symlink skills',
    installed > 0 ? 'installed' : 'skipped',
    `${skills.length} skills (${installed} new, ${skipped} existing)`
  );
}

// 3. Append CLAUDE.md.snippet to ~/.claude/CLAUDE.md (idempotent)
function installClaudeMd() {
  const snippetPath = path.join(CORTEX_LOCAL, 'CLAUDE.md.snippet');
  const claudeMd = path.join(CLAUDE_DIR, 'CLAUDE.md');
  const marker = '# Cortex Integration';

  const snippet = fs.readFileSync(snippetPath, 'utf8');
  const existing = fs.existsSync(claudeMd) ? fs.readFileSync(claudeMd, 'utf8') : '';

  if (existing.includes(marker)) {
    log('CLAUDE.md already has Cortex block — skipping');
    record('Append CLAUDE.md', 'skipped', 'already present');
    return;
  }

  if (!DRY_RUN) {
    fs.mkdirSync(CLAUDE_DIR, { recursive: true });
    fs.appendFileSync(claudeMd, '\n' + snippet);
  }
  log('Appended Cortex block to ~/.claude/CLAUDE.md');
  record('Append CLAUDE.md', 'installed');
}

// 4. Install cortex-sync.sh into ~/.claude/hooks/
function installHook() {
  const hooksDir = path.join(CLAUDE_DIR, 'hooks');
  const src = path.join(CORTEX_LOCAL, 'hooks', 'cortex-sync.sh');
  const dest = path.join(hooksDir, 'cortex-sync.sh');

  if (!DRY_RUN) fs.mkdirSync(hooksDir, { recursive: true });

  if (fs.existsSync(dest)) {
    log('cortex-sync.sh already installed — skipping');
    record('Install cortex-sync.sh', 'skipped', 'already exists');
    return;
  }

  if (!DRY_RUN) {
    fs.copyFileSync(src, dest);
    fs.chmodSync(dest, 0o755);
  }
  log('Installed ~/.claude/hooks/cortex-sync.sh');
  record('Install cortex-sync.sh', 'installed', '~/.claude/hooks/cortex-sync.sh');
}

// 5. Wire PostToolUse hook in ~/.claude/settings.json
function wireSettings() {
  const settingsPath = path.join(CLAUDE_DIR, 'settings.json');
  const hookCommand = path.join(CLAUDE_DIR, 'hooks', 'cortex-sync.sh');

  let settings = {};
  if (fs.existsSync(settingsPath)) {
    try {
      settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
    } catch {
      record('Wire settings.json', 'error', 'could not parse existing settings.json');
      return;
    }
  }

  // Check if already wired
  const postHooks = (settings?.hooks?.PostToolUse) || [];
  const alreadyWired = postHooks.some(entry =>
    entry?.hooks?.some(h => typeof h.command === 'string' && h.command.includes('cortex-sync.sh'))
  );

  if (alreadyWired) {
    log('cortex-sync.sh already wired in settings.json — skipping');
    record('Wire settings.json', 'skipped', 'hook already present');
    return;
  }

  if (!settings.hooks) settings.hooks = {};
  if (!settings.hooks.PostToolUse) settings.hooks.PostToolUse = [];
  settings.hooks.PostToolUse.push({
    matcher: 'Write|Edit',
    hooks: [{
      type: 'command',
      command: hookCommand,
      async: true,
      statusMessage: 'Syncing Cortex skill to GitHub...'
    }]
  });

  if (!DRY_RUN) fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
  log('Wired cortex-sync.sh in ~/.claude/settings.json PostToolUse');
  record('Wire settings.json', 'installed', 'PostToolUse Write|Edit → cortex-sync.sh');
}

function printSummary() {
  const LINE = '─'.repeat(54);
  const icons = { installed: '✓', skipped: '○', error: '✗' };

  console.log(`\n${LINE}`);
  console.log(' Cortex Installation');
  console.log(LINE);

  for (const { label, status, note } of results) {
    const icon = icons[status] || '?';
    const noteStr = note ? `  ${note}` : '';
    console.log(` ${icon}  ${label}${noteStr}`);
  }

  const hasErrors = results.some(r => r.status === 'error');

  console.log(LINE);

  if (hasErrors) {
    console.log('\n Some steps failed — check errors above.\n');
    process.exit(1);
  }

  console.log(`
 Manual steps required:
   1. Add API keys to ~/.openclaw.secrets.env:
        TAVILY_API_KEY=...
        PPLX_API_KEY=...
        FIRECRAWL_API_KEY=...
        GEMINI_API_KEY=...

   2. Add GH_TOKEN to environment (needed by cortex-sync.sh):
        export GH_TOKEN=<your-github-pat>

 Verify install:
   /cortex-status   (in a Claude Code session)

${LINE}
`);
}

function main() {
  if (DRY_RUN) console.log('Dry run — no changes will be made\n');

  installRepo();
  installSkills();
  installClaudeMd();
  installHook();
  wireSettings();
  printSummary();
}

main();
