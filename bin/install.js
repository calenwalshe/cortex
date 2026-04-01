#!/usr/bin/env node
'use strict';

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = os.homedir();
const CORTEX_LOCAL = path.join(HOME, 'projects', 'cortex');
const SCRIPT_REPO_ROOT = path.resolve(__dirname, '..');
const CLAUDE_DIR = path.join(HOME, '.claude');
const CORTEX_REPO = 'https://github.com/calenwalshe/cortex.git';
const MANIFEST_PATH = path.join(SCRIPT_REPO_ROOT, 'runtime-manifest.json');

const args = process.argv.slice(2);
const VERBOSE = args.includes('--verbose') || args.includes('-v');
const DRY_RUN = args.includes('--dry-run');

function parseProfile(argv) {
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--profile' && argv[i + 1] && !argv[i + 1].startsWith('-')) {
      return argv[i + 1];
    }
    if (argv[i].startsWith('--profile=')) {
      return argv[i].slice('--profile='.length);
    }
  }
  // Fall back to last-used profile from marker file
  const markerPath = path.join(os.homedir(), '.claude', '.cortex-profile');
  if (fs.existsSync(markerPath)) {
    const saved = fs.readFileSync(markerPath, 'utf8').trim();
    if (saved === 'core' || saved === 'full') return saved;
  }
  return 'core';
}

const PROFILE = parseProfile(args);
if (PROFILE !== 'core' && PROFILE !== 'full') {
  console.error(`Unknown profile: "${PROFILE}". Valid values: core, full`);
  process.exit(1);
}

function parseProjectRoot(argv) {
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--project') {
      const value = argv[i + 1];
      if (!value || value.startsWith('-')) {
        throw new Error('Missing value for --project. Usage: --project <target-project-root>');
      }
      return value;
    }
    if (arg.startsWith('--project=')) {
      const value = arg.slice('--project='.length);
      if (!value) {
        throw new Error('Missing value for --project. Usage: --project <target-project-root>');
      }
      return value;
    }
  }
  return null;
}

const PROJECT_ROOT = parseProjectRoot(args);

function loadRuntimeManifest() {
  if (!fs.existsSync(MANIFEST_PATH)) {
    throw new Error(`Runtime manifest not found: ${MANIFEST_PATH}`);
  }

  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(MANIFEST_PATH, 'utf8'));
  } catch (err) {
    throw new Error(`Failed to parse runtime manifest: ${MANIFEST_PATH}\n${err.message}`);
  }

  if (!Array.isArray(parsed.skills) || !Array.isArray(parsed.agents) || !Array.isArray(parsed.hooks) || !Array.isArray(parsed.hook_events)) {
    throw new Error(`Invalid runtime manifest schema in ${MANIFEST_PATH}`);
  }

  // Normalise skills: support both legacy string[] and current object[] formats
  parsed.skills = parsed.skills.map(s =>
    typeof s === 'string' ? { name: s, profiles: ['core', 'full'] } : s
  );

  return parsed;
}

const MANIFEST = loadRuntimeManifest();

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
    const output = execSync(cmd, { stdio: VERBOSE ? 'inherit' : 'pipe', ...opts });
    if (!output) return '';
    return output.toString().trim();
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

// 2. Symlink skills into ~/.claude/skills/ filtered by active profile
function installSkills() {
  const skillsDir = path.join(CLAUDE_DIR, 'skills');
  const srcDir = path.join(CORTEX_LOCAL, 'skills');
  const profileSkills = MANIFEST.skills.filter(s => s.profiles.includes(PROFILE));

  if (!DRY_RUN) fs.mkdirSync(skillsDir, { recursive: true });

  if (DRY_RUN) {
    for (const skill of profileSkills) {
      const target = path.join(skillsDir, skill.name);
      const src = path.join(srcDir, skill.name);
      let status = 'would-create';
      try {
        const existing = fs.readlinkSync(target);
        status = existing === src ? 'already-linked' : 'would-create';
      } catch { /* absent or not a symlink — would-create */ }
      record(`Skill: ${skill.name}`, status);
    }
    return;
  }

  let installed = 0, skipped = 0;
  for (const skill of profileSkills) {
    const target = path.join(skillsDir, skill.name);
    const src = path.join(srcDir, skill.name);
    const result = ensureSymlink(src, target);
    if (result === 'already-linked') { skipped++; } else { installed++; }
    log(`  skill ${skill.name} — ${result}`);
  }

  record(
    'Symlink skills',
    installed > 0 ? 'installed' : 'skipped',
    `${profileSkills.length} skills (${installed} new, ${skipped} existing) [profile: ${PROFILE}]`
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
    for (const { file: hook } of MANIFEST.hooks) {
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
  for (const { file: hook } of MANIFEST.hooks) {
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

  const HOOK_EVENTS = MANIFEST.hook_events.map(({ event, hook_file, matcher, timeout, async }) => ({
    event,
    file: hook_file,
    entry: () => {
      const hookEntry = { type: 'command', command: path.join(hooksDir, hook_file) };
      if (typeof timeout === 'number') hookEntry.timeout = timeout;
      if (typeof async === 'boolean') hookEntry.async = async;
      const eventEntry = { hooks: [hookEntry] };
      if (matcher) eventEntry.matcher = matcher;
      return eventEntry;
    }
  }));

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

// Write ~/.claude/.cortex-profile marker
function writeProfileMarker() {
  const markerPath = path.join(CLAUDE_DIR, '.cortex-profile');
  if (DRY_RUN) {
    record('Profile marker (~/.claude/.cortex-profile)', 'would-create', PROFILE);
    return;
  }
  fs.mkdirSync(CLAUDE_DIR, { recursive: true });
  fs.writeFileSync(markerPath, PROFILE + '\n', 'utf8');
  record('Profile marker (~/.claude/.cortex-profile)', 'installed', PROFILE);
}

function installProjectRuntime() {
  if (!PROJECT_ROOT) return;
  const resolvedProjectRoot = path.resolve(PROJECT_ROOT);
  const scaffoldScript = path.join(CORTEX_LOCAL, 'scripts', 'cortex', 'scaffold_runtime.sh');
  const quotedScript = `"${scaffoldScript.replace(/"/g, '\\"')}"`;
  const quotedTarget = `"${resolvedProjectRoot.replace(/"/g, '\\"')}"`;
  const command = `bash ${quotedScript} ${quotedTarget}`;

  if (DRY_RUN) {
    record('Project runtime scaffold', 'would-create', resolvedProjectRoot);
    return;
  }

  run(command, { stdio: 'inherit' });
  record('Project runtime scaffold', 'installed', resolvedProjectRoot);
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
      { label: 'Project runtime',                       prefix: 'Project runtime scaffold' },
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

  if (PROFILE === 'full') {
    console.log(`
 Manual steps required:
   1. Add API keys to ~/.api-keys (sourced by .bashrc):
        export TAVILY_API_KEY=...
        export PPLX_API_KEY=...
        export FIRECRAWL_API_KEY=...
        export GEMINI_API_KEY=...
        export OPENAI_API_KEY=...
        export GH_TOKEN=...
`);
  }

  console.log(` Verify install:
   /cortex-status   (in a Claude Code session)

${LINE}
`);
}

function main() {
  if (DRY_RUN) console.log(`Dry run — no changes will be made [profile: ${PROFILE}]\n`);
  installRepo();
  installSkills();
  installAgents();
  installClaudeMd();
  installHooks();
  wireSettings();
  writeProfileMarker();
  installProjectRuntime();
  printSummary();
}

main();
