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

const MANIFEST = {
  skills: [
    'cortex-audit', 'cortex-clarify', 'cortex-investigate',
    'cortex-research', 'cortex-review', 'cortex-spec', 'cortex-status'
  ],
  agents: [
    'cortex-critic.md', 'cortex-eval-designer.md',
    'cortex-scribe.md', 'cortex-specifier.md'
  ],
  hooks: [
    'cortex-phase-guard.sh', 'cortex-postcompact.sh', 'cortex-precompact.sh',
    'cortex-session-end.sh', 'cortex-session-start.sh', 'cortex-sync.sh',
    'cortex-task-completed.sh', 'cortex-task-created.sh',
    'cortex-teammate-idle.sh', 'cortex-validator-trigger.sh',
    'cortex-write-guard.sh'
  ]
};

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

// Returns 'already-linked', 'linked', or throws.
// Handles: absent (ENOENT), stale symlink (wrong target), regular file (EINVAL).
function ensureSymlink(src, target) {
  try {
    const existing = fs.readlinkSync(target);
    if (existing === src) return 'already-linked';
    fs.unlinkSync(target);
  } catch (e) {
    if (e.code === 'EINVAL') {
      // target is a regular file (e.g. old copy) — replace with symlink
      fs.unlinkSync(target);
    } else if (e.code !== 'ENOENT') {
      throw e;
    }
  }
  fs.symlinkSync(src, target);
  return 'linked';
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

  if (DRY_RUN) {
    for (const skill of MANIFEST.skills) {
      const target = path.join(skillsDir, skill);
      const src = path.join(srcDir, skill);
      let status = 'would-create';
      try {
        const existing = fs.readlinkSync(target);
        status = existing === src ? 'already-linked' : 'would-create';
      } catch { /* absent or not a symlink — would-create */ }
      record(`Skill: ${skill}`, status);
    }
    return;
  }

  let installed = 0, skipped = 0;
  for (const skill of MANIFEST.skills) {
    const target = path.join(skillsDir, skill);
    const src = path.join(srcDir, skill);
    const result = ensureSymlink(src, target);
    if (result === 'already-linked') { skipped++; } else { installed++; }
    log(`  skill ${skill} — ${result}`);
  }

  record(
    'Symlink skills',
    installed > 0 ? 'installed' : 'skipped',
    `${MANIFEST.skills.length} skills (${installed} new, ${skipped} existing)`
  );
}

// 3. Symlink cortex agents into ~/.claude/agents/
function installAgents() {
  const agentsDir = path.join(CLAUDE_DIR, 'agents');
  const srcDir = path.join(CORTEX_LOCAL, '.claude', 'agents');

  if (!DRY_RUN) fs.mkdirSync(agentsDir, { recursive: true });

  if (DRY_RUN) {
    for (const agent of MANIFEST.agents) {
      const target = path.join(agentsDir, agent);
      const src = path.join(srcDir, agent);
      let status = 'would-create';
      try {
        const existing = fs.readlinkSync(target);
        status = existing === src ? 'already-linked' : 'would-create';
      } catch { /* absent — would-create */ }
      record(`Agent: ${agent}`, status);
    }
    return;
  }

  let installed = 0, skipped = 0;
  for (const agent of MANIFEST.agents) {
    const target = path.join(agentsDir, agent);
    const src = path.join(srcDir, agent);
    const result = ensureSymlink(src, target);
    if (result === 'already-linked') { skipped++; } else { installed++; }
    log(`  agent ${agent} — ${result}`);
  }

  record('Symlink agents', installed > 0 ? 'installed' : 'skipped',
    `${MANIFEST.agents.length} agents (${installed} new, ${skipped} existing)`);
}

// 4. Append CLAUDE.md.snippet to ~/.claude/CLAUDE.md (idempotent)
function installClaudeMd() {
  const snippetPath = path.join(CORTEX_LOCAL, 'CLAUDE.md.snippet');
  const claudeMd = path.join(CLAUDE_DIR, 'CLAUDE.md');
  const marker = '# Cortex Integration';

  const existing = fs.existsSync(claudeMd) ? fs.readFileSync(claudeMd, 'utf8') : '';

  if (existing.includes(marker)) {
    log('CLAUDE.md already has Cortex block — skipping');
    record('CLAUDE.md', 'already-set', 'Cortex Integration block already present');
    return;
  }

  if (DRY_RUN) {
    record('CLAUDE.md', 'would-append', 'Cortex Integration block');
    return;
  }

  const snippet = fs.readFileSync(snippetPath, 'utf8');
  fs.mkdirSync(CLAUDE_DIR, { recursive: true });
  fs.appendFileSync(claudeMd, '\n' + snippet);
  log('Appended Cortex block to ~/.claude/CLAUDE.md');
  record('CLAUDE.md', 'installed', 'Cortex Integration block appended');
}

// 5. Symlink all 11 hooks into ~/.claude/hooks/
function installHooks() {
  const hooksDir = path.join(CLAUDE_DIR, 'hooks');
  const srcDir = path.join(CORTEX_LOCAL, '.claude', 'hooks');

  if (!DRY_RUN) fs.mkdirSync(hooksDir, { recursive: true });

  if (DRY_RUN) {
    for (const hook of MANIFEST.hooks) {
      const target = path.join(hooksDir, hook);
      const src = path.join(srcDir, hook);
      let status = 'would-create';
      try {
        const existing = fs.readlinkSync(target);
        status = existing === src ? 'already-linked' : 'would-create';
      } catch (e) {
        if (e.code === 'EINVAL') status = 'replace-copy';
        // ENOENT → would-create (default)
      }
      record(`Hook: ${hook}`, status);
    }
    return;
  }

  let installed = 0, skipped = 0;
  for (const hook of MANIFEST.hooks) {
    const target = path.join(hooksDir, hook);
    const src = path.join(srcDir, hook);
    const result = ensureSymlink(src, target);
    fs.chmodSync(target, 0o755);
    if (result === 'already-linked') { skipped++; } else { installed++; }
    log(`  hook ${hook} — ${result}`);
  }

  record('Symlink hooks', installed > 0 ? 'installed' : 'skipped',
    `${MANIFEST.hooks.length} hooks (${installed} new, ${skipped} existing)`);
}

// Dedup helper: returns true if any entry in the array already references commandFragment
function isHookAlreadyWired(entries, commandFragment) {
  return (entries || []).some(entry =>
    (entry.hooks || []).some(h =>
      typeof h.command === 'string' && h.command.includes(commandFragment)
    )
  );
}

// 6. Wire all 9 hook events in ~/.claude/settings.json
function wireSettings() {
  const settingsPath = path.join(CLAUDE_DIR, 'settings.json');
  const hooksDir = path.join(CLAUDE_DIR, 'hooks');

  // 9 events — cortex-write-guard.sh is NOT wired globally (agent-invoked only)
  const HOOK_EVENTS = [
    { event: 'SessionStart',  file: 'cortex-session-start.sh',     entry: () => ({ hooks: [{ type: 'command', command: path.join(hooksDir, 'cortex-session-start.sh') }] }) },
    { event: 'PreCompact',    file: 'cortex-precompact.sh',         entry: () => ({ hooks: [{ type: 'command', command: path.join(hooksDir, 'cortex-precompact.sh') }] }) },
    { event: 'PostCompact',   file: 'cortex-postcompact.sh',        entry: () => ({ hooks: [{ type: 'command', command: path.join(hooksDir, 'cortex-postcompact.sh') }] }) },
    { event: 'Stop',          file: 'cortex-session-end.sh',        entry: () => ({ hooks: [{ type: 'command', command: path.join(hooksDir, 'cortex-session-end.sh'), async: true }] }) },
    { event: 'PreToolUse',    file: 'cortex-phase-guard.sh',        entry: () => ({ matcher: 'Write|Edit', hooks: [{ type: 'command', command: path.join(hooksDir, 'cortex-phase-guard.sh'), timeout: 10 }] }) },
    { event: 'PostToolUse',   file: 'cortex-validator-trigger.sh',  entry: () => ({ matcher: 'Write|Edit', hooks: [{ type: 'command', command: path.join(hooksDir, 'cortex-validator-trigger.sh'), async: true }] }) },
    { event: 'TaskCreated',   file: 'cortex-task-created.sh',       entry: () => ({ hooks: [{ type: 'command', command: path.join(hooksDir, 'cortex-task-created.sh'), timeout: 5 }] }) },
    { event: 'TaskCompleted', file: 'cortex-task-completed.sh',     entry: () => ({ hooks: [{ type: 'command', command: path.join(hooksDir, 'cortex-task-completed.sh'), timeout: 10 }] }) },
    { event: 'TeammateIdle',  file: 'cortex-teammate-idle.sh',      entry: () => ({ hooks: [{ type: 'command', command: path.join(hooksDir, 'cortex-teammate-idle.sh'), timeout: 5 }] }) },
  ];

  let settings = {};
  if (fs.existsSync(settingsPath)) {
    try {
      settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
    } catch {
      record('Wire settings.json', 'error', 'could not parse existing settings.json');
      return;
    }
  }
  if (!settings.hooks) settings.hooks = {};

  let added = 0, alreadySet = 0;

  for (const { event, file, entry } of HOOK_EVENTS) {
    const existing = settings.hooks[event] || [];
    if (isHookAlreadyWired(existing, file)) {
      alreadySet++;
      if (DRY_RUN) record(`Settings: ${event}`, 'already-set', file);
      log(`  ${event} → ${file} — already wired`);
      continue;
    }

    if (DRY_RUN) {
      record(`Settings: ${event}`, 'would-add', file);
      added++;
      continue;
    }

    if (!settings.hooks[event]) settings.hooks[event] = [];
    settings.hooks[event].push(entry());
    added++;
    log(`  ${event} → ${file} — wired`);
  }

  if (!DRY_RUN) {
    fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
    record('Wire settings.json', added > 0 ? 'installed' : 'skipped',
      `${HOOK_EVENTS.length} events (${added} new, ${alreadySet} existing)`);
  }
}

function printSummary() {
  const LINE = '─'.repeat(54);

  if (DRY_RUN) {
    console.log(LINE);
    console.log(' Cortex Install Preview');
    console.log(LINE);

    const groups = [
      { label: 'Skills  (~/.claude/skills/)',           prefix: 'Skill:' },
      { label: 'Agents  (~/.claude/agents/)',           prefix: 'Agent:' },
      { label: 'Hooks   (~/.claude/hooks/)',            prefix: 'Hook:' },
      { label: 'Settings (~/.claude/settings.json)',   prefix: 'Settings:' },
      { label: 'CLAUDE.md',                             prefix: 'CLAUDE.md' },
    ];

    for (const { label, prefix } of groups) {
      const items = results.filter(r => r.label.startsWith(prefix));
      if (!items.length) continue;
      console.log(`\n ${label}`);
      for (const { label: l, status, note } of items) {
        const name = l.replace(prefix, '').trim();
        const tag = status === 'already-linked' || status === 'already-set'
          ? '[already set]  '
          : status === 'replace-copy'
          ? '[replace copy] '
          : '[would create] ';
        const noteStr = note ? ` → ${note}` : '';
        console.log(`   ${tag} ${name}${noteStr}`);
      }
    }

    const wouldCreate = results.filter(r =>
      r.status === 'would-create' || r.status === 'would-add' || r.status === 'would-append'
    ).length;
    const alreadySet  = results.filter(r =>
      r.status === 'already-linked' || r.status === 'already-set'
    ).length;
    const replaceCopy = results.filter(r => r.status === 'replace-copy').length;

    console.log(`\n${LINE}`);
    console.log(` Summary: ${wouldCreate} would-create, ${alreadySet} already-set, ${replaceCopy} replace-copy`);
    console.log(`${LINE}\n`);
    return;
  }

  // Live run summary
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
  installAgents();
  installClaudeMd();
  installHooks();
  wireSettings();
  printSummary();
}

main();
