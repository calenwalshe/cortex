# Phase 6: Installer and Operational Cleanup — Research

**Researched:** 2026-03-29
**Domain:** Node.js CLI installer, shell symlink management, Claude settings.json merge
**Confidence:** HIGH — all findings from direct inspection of local codebase

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| INST-01 | Installer uses one canonical local repo path (`~/projects/cortex`) | `bin/install.js` already uses `CORTEX_LOCAL = ~/projects/cortex`; needs no change |
| INST-02 | Installer installs/symlinks all cortex-* skills, 4 agents, 10 hooks; wires 9+ hook events | Skills: 5 of 7 currently symlinked; agents and full hook bundle not yet handled |
| INST-03 | `--dry-run` completes without requiring clone-dependent files | Current dry-run calls `readdirSync` on the local repo — crashes if repo absent |
| INST-04 | No credential-bearing remote URLs in installed git config | Audit clean; `origin` is plain HTTPS, no embedded credentials found |
| INST-05 | Running `dotfiles-setup.sh` also correctly sets up Cortex | `dotfiles-setup.sh` does not exist; question is whether to create it or fold into `bin/install.js` |
| INST-06 | Installer is idempotent — running twice produces no errors, no duplicate entries | `ln -sf` is idempotent for files; settings.json dedup logic already exists for one hook but must be generalised |
</phase_requirements>

---

## Summary

`bin/install.js` is a partial installer written in Node.js. It handles cloning, skill symlinking, CLAUDE.md snippet appending, and wiring one hook (`cortex-sync.sh`). Phase 6 must extend it to cover the full deployment surface: all 7 skills, 4 agents, 11 hooks, and all 9 hook event registrations in `~/.claude/settings.json`.

The three non-trivial problems are: (1) the `--dry-run` flag currently crashes on a fresh machine because `installSkills()` calls `fs.readdirSync()` on the uncloned repo path — it must use a hardcoded manifest instead; (2) settings.json merging needs generalised deduplication logic across all 9 hook events, not just PostToolUse; (3) `dotfiles-setup.sh` does not exist and INST-05 requires it to work — the simplest path is a thin shell wrapper that delegates to `bin/install.js`.

The credential audit is clean. No token-bearing URLs appear in any Cortex-owned files. The git remote is plain HTTPS (`https://github.com/calenwalshe/cortex.git`). Both submodules use plain HTTPS.

**Primary recommendation:** Extend `bin/install.js` with hardcoded manifests, agent/hook symlinking, full settings.json merge, and a dry-run output table. Create `dotfiles-setup.sh` as a 5-line shell wrapper that calls `node bin/install.js "$@"`.

---

## Current Installer State

### What `bin/install.js` does today

| Step | Function | Behaviour | Gap |
|------|----------|-----------|-----|
| 1 | `installRepo()` | Clones repo if absent | OK — uses canonical local path |
| 2 | `installSkills()` | Symlinks `skills/cortex-*` to `~/.claude/skills/` | Only filters `startsWith('cortex-')` — but also calls `readdirSync` on live repo; dry-run crashes |
| 3 | `installClaudeMd()` | Appends snippet to `~/.claude/CLAUDE.md` | OK — idempotent via marker check |
| 4 | `installHook()` | **Copies** `hooks/cortex-sync.sh` to `~/.claude/hooks/` | Uses `copyFileSync`, not `symlinkSync`; out of sync when repo updates |
| 5 | `wireSettings()` | Appends PostToolUse entry to `~/.claude/settings.json` | Handles one event only; no agents, no full hook bundle |

### What is currently installed (observed state)

- **Skills installed:** 5 of 7 (`cortex-clarify` and `cortex-spec` missing)
- **Agents installed:** None — `~/.claude/agents/` directory does not exist
- **Hooks installed to `~/.claude/hooks/`:** `cortex-sync.sh` (copied, not symlinked)
- **Settings.json wired:** Only `cortex-sync.sh` PostToolUse Write|Edit

### `dotfiles-setup.sh`

The file does not exist at `/home/agent/projects/cortex/dotfiles-setup.sh`. INST-05 requires it to exist and correctly invoke the installer.

---

## Skill Symlink Strategy

### Inventory

All 7 skill directories in `skills/` use the `cortex-*` naming convention:

```
skills/cortex-audit/
skills/cortex-clarify/        ← currently missing from ~/.claude/skills/
skills/cortex-investigate/
skills/cortex-research/
skills/cortex-review/
skills/cortex-spec/           ← currently missing from ~/.claude/skills/
skills/cortex-status/
```

### Symlink mechanics

Use `fs.symlinkSync(src, target)` with pre-check via `fs.lstatSync`. For idempotency:

```js
// Check if symlink exists and points to the correct target
try {
  const existing = fs.readlinkSync(target);
  if (existing === src) { skipped++; continue; }
  fs.unlinkSync(target); // stale symlink — relink
} catch { /* does not exist — create it */ }
fs.symlinkSync(src, target);
```

This handles: absent, stale (wrong target), and correct (no-op) cases without throwing.

### Dry-run approach

Current code calls `fs.readdirSync(srcDir)` on the uncloned path — this throws `ENOENT` if the repo is not present. Fix: embed a hardcoded `MANIFEST` in `install.js`:

```js
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
```

In dry-run mode: use `MANIFEST` to enumerate what would be installed, check live `~/.claude/` state, and print the diff. No reads from `~/projects/cortex/` needed.

---

## Agent and Hook Deployment Strategy

### Agents

Source: `/home/agent/projects/cortex/.claude/agents/` (4 `.md` files)
Target: `~/.claude/agents/` (create if absent)

Strategy: symlink each `.md` file. `~/.claude/agents/` directory does not currently exist — installer must `mkdirSync` it.

```
~/.claude/agents/cortex-critic.md       → ~/projects/cortex/.claude/agents/cortex-critic.md
~/.claude/agents/cortex-eval-designer.md → ~/projects/cortex/.claude/agents/cortex-eval-designer.md
~/.claude/agents/cortex-scribe.md       → ~/projects/cortex/.claude/agents/cortex-scribe.md
~/.claude/agents/cortex-specifier.md    → ~/projects/cortex/.claude/agents/cortex-specifier.md
```

### Hooks

Source: `/home/agent/projects/cortex/.claude/hooks/` (11 `.sh` files)
Target: `~/.claude/hooks/` (already exists — has GSD and RTK hooks)

Strategy: symlink each `.sh` file. The existing `cortex-sync.sh` in `~/.claude/hooks/` is a **copy** not a symlink — the installer must detect this case and replace it with a symlink (or leave it if the content is identical; replacing with symlink is cleaner for future updates).

Note: `cortex-write-guard.sh` exists in `.claude/hooks/` but is not registered in `.claude/settings.json`. It is used by individual agent prompt instructions, not via Claude event hooks. Symlink it anyway (complete deployment), but do not add a settings.json entry for it.

### Settings.json merge

The project-level `.claude/settings.json` references hooks via `"$CLAUDE_PROJECT_DIR"/.claude/hooks/<name>.sh`. The user-level `~/.claude/settings.json` must reference absolute paths to `~/.claude/hooks/<name>.sh` (the symlinks).

**Event map** — 9 events to wire:

| Claude Event | Hook file | Matcher | Extra options |
|---|---|---|---|
| SessionStart | cortex-session-start.sh | (none) | — |
| PreCompact | cortex-precompact.sh | (none) | — |
| PostCompact | cortex-postcompact.sh | (none) | — |
| Stop | cortex-session-end.sh | (none) | `async: true` |
| PreToolUse | cortex-phase-guard.sh | `Write\|Edit` | `timeout: 10` |
| PostToolUse | cortex-validator-trigger.sh | `Write\|Edit` | `async: true` |
| TaskCreated | cortex-task-created.sh | (none) | `timeout: 5` |
| TaskCompleted | cortex-task-completed.sh | (none) | `timeout: 10` |
| TeammateIdle | cortex-teammate-idle.sh | (none) | `timeout: 5` |

**Deduplication:** For each event, walk all existing entries and check for any hook entry whose `command` contains the hook filename. If found: skip. If not found: append the new entry object. This is O(n) per event and tolerates arbitrary pre-existing entries from GSD, RTK, etc.

**Overlap with current user settings.json:**

| Event | Currently has cortex entry? | Action |
|---|---|---|
| SessionStart | No | Add |
| PreToolUse | No | Add |
| PostToolUse | Yes (`cortex-sync.sh`) | Check; add `cortex-validator-trigger.sh` entry |
| PostCompact | No | Add |
| PreCompact | No | Add |
| Stop | No | Add |
| TaskCreated | No | Add |
| TaskCompleted | No | Add |
| TeammateIdle | No | Add |

---

## Dry-Run Design

`--dry-run` must complete on a fresh machine with no local repo.

### Output format

```
Dry run — no changes will be made

──────────────────────────────────────────────────
 Cortex Install Preview
──────────────────────────────────────────────────
 Skills  (~/.claude/skills/)
   [would create]  cortex-audit       → ~/projects/cortex/skills/cortex-audit
   [already linked] cortex-investigate → ~/projects/cortex/skills/cortex-investigate
   [would create]  cortex-clarify     → ~/projects/cortex/skills/cortex-clarify
   ...

 Agents  (~/.claude/agents/)
   [would create]  cortex-critic.md   → ~/projects/cortex/.claude/agents/cortex-critic.md
   ...

 Hooks   (~/.claude/hooks/)
   [would create]  cortex-session-start.sh → ~/projects/cortex/.claude/hooks/cortex-session-start.sh
   [replace copy]  cortex-sync.sh → ~/projects/cortex/.claude/hooks/cortex-sync.sh
   ...

 Settings (~/.claude/settings.json)
   [would add]  SessionStart  → cortex-session-start.sh
   [would add]  Stop          → cortex-session-end.sh
   [already set] PostToolUse  → cortex-sync.sh
   ...

 CLAUDE.md
   [would append]  Cortex Integration block

──────────────────────────────────────────────────
 Summary: 12 would-create, 3 already-set, 1 replace-copy
──────────────────────────────────────────────────
```

Implementation: dry-run uses `MANIFEST` + reads live `~/.claude/` state (which always exists). It does NOT read from `~/projects/cortex/`. The check is: does the symlink target exist and point to the right place? Answer using MANIFEST path strings.

---

## Credential Audit Findings

**Finding: CLEAN**

| Target | Result |
|---|---|
| `bin/install.js` | No credential URLs. `CORTEX_REPO` constant is `https://github.com/calenwalshe/cortex.git` (no embedded credentials) |
| `.claude/hooks/cortex-sync.sh` | No credential URLs. Uses `$HOME/projects/cortex` canonical path. Push soft-fails if no remote |
| `hooks/cortex-sync.sh` (root) | Identical to above — same file |
| `scripts/cortex/scaffold_runtime.sh` | No network operations or URLs |
| `.gitmodules` | Two HTTPS submodule URLs, no credentials |
| `git remote -v` | `https://github.com/calenwalshe/cortex.git` — plain HTTPS |

INST-04 is satisfied by the current state. No remediation required.

Note: `install.js` prints a manual-steps section suggesting `GH_TOKEN` be exported. That is runtime guidance, not a stored credential. The comment in `cortex-sync.sh` notes the credential URL was previously removed (the "Bug fixes applied" comment block). The fix is already in place.

---

## Plan Decomposition

### Plan 1 — Installer Core Rewrite (INST-01, INST-02, INST-03, INST-06)

**Scope:** Rewrite `bin/install.js` to cover full deployment surface with idempotency.

Tasks:
1. Add `MANIFEST` constant with all 7 skills, 4 agents, 11 hooks
2. Rewrite `installSkills()` to use MANIFEST in dry-run; use live `readdirSync` only when repo exists
3. Add `installAgents()` — symlink 4 agent `.md` files to `~/.claude/agents/`
4. Add `installHooks()` — symlink 11 hook `.sh` files to `~/.claude/hooks/`; replace copy of cortex-sync.sh with symlink
5. Rewrite `wireSettings()` — generalise to all 9 hook events using the event map; per-command dedup
6. Rewrite `--dry-run` output — table format using MANIFEST, reads only `~/.claude/` (never `~/projects/cortex/`)
7. Fix dry-run `printSummary()` to show [would create] / [already set] / [replace copy] breakdown

### Plan 2 — dotfiles-setup.sh and Operational Cleanup (INST-05, INST-04)

**Scope:** Create `dotfiles-setup.sh` wrapper, verify credential cleanliness, end-to-end test.

Tasks:
1. Create `dotfiles-setup.sh` at repo root as a thin shell wrapper:
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   node "$SCRIPT_DIR/bin/install.js" "$@"
   ```
2. `chmod +x dotfiles-setup.sh`
3. Verify `dotfiles-setup.sh --dry-run` works from any working directory (CWD-independent)
4. Confirm credential audit: run targeted `grep` for `https://.*:.*@` in all non-`upstream` files
5. Wire INST-05 verification: running `dotfiles-setup.sh` from a clean state installs same result as `node bin/install.js`

### Plan 3 — Validation and Smoke Tests (all INST-*)

**Scope:** Automated tests for the installer.

Tasks:
1. Write `test/installer.test.sh` — bash test script using a temp `~/.claude/` directory
2. Test: dry-run completes on empty `~/projects/` (no repo) — exit 0, output contains "would create"
3. Test: install run symlinks all 7 skills, 4 agents, 11 hooks correctly
4. Test: second run is clean (all "skipped", exit 0)
5. Test: settings.json after install has exactly 9 cortex hook entries, no duplicates
6. Test: no credential URLs in installed git config

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash (no external test runner needed) |
| Config file | `test/installer.test.sh` (to be created) |
| Quick run command | `bash test/installer.test.sh` |
| Full suite command | `bash test/installer.test.sh` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INST-01 | Installer uses `~/projects/cortex` canonical path | unit | `grep CORTEX_LOCAL bin/install.js \| grep "projects/cortex"` | ✅ |
| INST-02 | All 7 skills, 4 agents, 10 hooks installed and wired | integration | `bash test/installer.test.sh --check-installed` | ❌ Wave 0 |
| INST-03 | `--dry-run` exits 0 when repo absent | smoke | `bash test/installer.test.sh --check-dry-run` | ❌ Wave 0 |
| INST-04 | No credential URLs in git config or scripts | audit | `grep -rn 'https://.*:.*@' bin/ hooks/ .claude/ scripts/ --include='*.sh' --include='*.js'` | ✅ |
| INST-05 | `dotfiles-setup.sh --dry-run` exits 0 | smoke | `bash dotfiles-setup.sh --dry-run` | ❌ Wave 0 |
| INST-06 | Running installer twice produces no errors | idempotency | `bash test/installer.test.sh --check-idempotency` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `node bin/install.js --dry-run` (smoke — exit 0)
- **Per wave merge:** `bash test/installer.test.sh`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `test/installer.test.sh` — covers INST-02, INST-03, INST-05, INST-06 with isolated temp dir
- [ ] `dotfiles-setup.sh` — covers INST-05 (file must exist before tests run)

---

## Architecture Patterns

### Symlink idempotency pattern

```js
// Source: direct Node.js fs module inspection
function ensureSymlink(src, target) {
  try {
    const existing = fs.readlinkSync(target);
    if (existing === src) return 'already-linked';
    fs.unlinkSync(target); // stale — relink
  } catch (e) {
    if (e.code === 'EINVAL') {
      // target exists but is a regular file (e.g. old copy)
      fs.unlinkSync(target);
    } else if (e.code !== 'ENOENT') {
      throw e;
    }
  }
  fs.symlinkSync(src, target);
  return 'linked';
}
```

### Settings.json hook dedup pattern

```js
function isHookAlreadyWired(entries, commandFragment) {
  return (entries || []).some(entry =>
    (entry.hooks || []).some(h =>
      typeof h.command === 'string' && h.command.includes(commandFragment)
    )
  );
}
```

### MANIFEST-driven dry-run pattern

```js
if (DRY_RUN) {
  // Use MANIFEST — never read ~/projects/cortex/
  for (const skill of MANIFEST.skills) {
    const target = path.join(skillsDir, skill);
    const status = checkSymlinkState(target, path.join(srcDir, skill));
    record(`skill: ${skill}`, status === 'ok' ? 'skipped' : 'would-create');
  }
  return;
}
// Normal path: read from live repo
const skills = fs.readdirSync(srcDir).filter(d => d.startsWith('cortex-'));
```

---

## Common Pitfalls

### Pitfall 1: Dry-run reads from uncloned repo

**What goes wrong:** `fs.readdirSync(srcDir)` throws `ENOENT` if `~/projects/cortex/` was never cloned.
**Root cause:** Dry-run was added to the flag check but `installSkills()` always reads live filesystem.
**How to avoid:** Separate dry-run path uses `MANIFEST`; live path uses `readdirSync`.

### Pitfall 2: Copying instead of symlinking hooks

**What goes wrong:** `fs.copyFileSync` installs a snapshot — the user's `~/.claude/hooks/cortex-sync.sh` falls out of sync when the repo updates.
**Root cause:** `installHook()` uses `copyFileSync`. The fix is `symlinkSync` for all hook files.
**Warning signs:** Hook file in `~/.claude/hooks/` differs from `~/projects/cortex/.claude/hooks/` after a `git pull`.

### Pitfall 3: Settings.json merge clobbering existing entries

**What goes wrong:** Writing `settings.hooks.PostToolUse = [newEntry]` removes the existing GSD `gsd-context-monitor.js` PostToolUse entry.
**Root cause:** Overwrite instead of append.
**How to avoid:** Always read existing array, check for duplicates, append only new entries. Never overwrite arrays.

### Pitfall 4: Missing `~/.claude/agents/` directory

**What goes wrong:** `fs.symlinkSync` fails with `ENOENT` because the parent directory doesn't exist.
**Root cause:** `~/.claude/agents/` is not created by default.
**How to avoid:** `fs.mkdirSync(agentsDir, { recursive: true })` before any symlink operations.

---

## State of the Art

| Old Approach | Current Approach | Impact |
|---|---|---|
| Copy hook files | Symlink hook files | Updates take effect immediately after `git pull` |
| Single hook event wired | All 9 hook events wired | Full cortex intelligence layer active globally |
| Dry-run crashes on fresh machine | MANIFEST-driven dry-run | Installer can be evaluated before committing to clone |

---

## Open Questions

1. **cortex-write-guard.sh and settings.json**
   - What we know: `cortex-write-guard.sh` exists in `.claude/hooks/` but is NOT in `.claude/settings.json`. It is referenced in agent system prompts for per-agent write restrictions.
   - What's unclear: Should it be wired as a PreToolUse hook globally, or only activated when an agent sub-session is running?
   - Recommendation: Symlink the file (complete deployment) but do NOT add it to settings.json for now. It's an agent-invoked guard, not a global one.

2. **Upgrade path for existing cortex-sync.sh copy**
   - What we know: `~/.claude/hooks/cortex-sync.sh` is currently a copy, not a symlink.
   - What's unclear: Should installer silently replace it with a symlink, or warn the user?
   - Recommendation: Replace silently — `ensureSymlink` detects the `EINVAL` (regular file case) and replaces with symlink. Record status as `replaced-copy`.

---

## Sources

### Primary (HIGH confidence)

- Direct inspection of `/home/agent/projects/cortex/bin/install.js` — full installer logic
- Direct inspection of `/home/agent/projects/cortex/.claude/settings.json` — project hook registry
- Direct inspection of `/home/agent/.claude/settings.json` — user settings state
- Direct inspection of `/home/agent/.claude/skills/` symlink state — 5 of 7 installed
- `git -C ~/projects/cortex remote -v` — credential audit
- `git -C ~/projects/cortex config --list | grep url` — credential audit

### Secondary (MEDIUM confidence)

- None required — all findings are from direct local inspection.

---

## Metadata

**Confidence breakdown:**
- Current installer state: HIGH — read the actual source
- Gap analysis: HIGH — compared installed state to requirements
- Dry-run fix: HIGH — confirmed ENOENT throw experimentally
- Settings.json merge: HIGH — enumerated both files and derived diff
- Credential audit: HIGH — grepped all owned files

**Research date:** 2026-03-29
**Valid until:** Indefinite (local codebase, not a moving external dependency)
