# Downstream Fork Guide

This document describes how to maintain a downstream fork of Cortex — for example, an internal Meta deployment — that tracks upstream framework updates while keeping internal additions isolated.

---

## Overview

The upstream Cortex repo (`calenwalshe/cortex`) contains:
- **Framework skills** (`cortex-*`) — installed by both `core` and `full` profiles
- **Tool skills** (`web`, `ai`, `google`, `cli`) — installed by `full` profile only

A downstream fork installs with `--profile=core`, which omits the tool skills entirely. This means upstream merges never touch the tool-skill files, eliminating merge conflicts in those paths.

---

## Initial Setup (clone → internal Phabricator)

```bash
# 1. Clone the upstream repo
git clone https://github.com/calenwalshe/cortex.git
cd cortex

# 2. Install core profile
node bin/install.js --profile=core

# 3. Push to your internal Phabricator repo
git remote add internal <your-phabricator-remote-url>
git push internal main
```

---

## Arcanist Configuration

Create `.arcconfig` at the repo root for your internal fork:

```json
{
  "project_id": "cortex",
  "conduit_uri": "https://phabricator.your-company.com/",
  "base": "origin/main"
}
```

Set your editor and diff arc defaults in `~/.arcrc`:

```json
{
  "config": {
    "editor": "vim"
  }
}
```

---

## Submitting Internal Changes (arc diff workflow)

Always rebase on top of the latest internal `main` before submitting a diff:

```bash
# 1. Fetch latest internal main
git fetch internal

# 2. Rebase your branch
git rebase internal/main

# 3. Submit the diff
arc diff
```

Do NOT use `arc diff` on a branch that has not been rebased — Phabricator will include upstream commits in your diff.

---

## Pulling Upstream Framework Updates

```bash
# 1. Fetch upstream
git fetch origin

# 2. Rebase internal main on top of upstream main
git checkout main
git rebase origin/main

# 3. Resolve any conflicts (tool-skill paths are excluded from core profile,
#    so conflicts should only occur in files you have actually modified)

# 4. Push to internal remote
git push internal main --force-with-lease
```

The `--profile=core` install ensures the `skills/web/`, `skills/ai/`, `skills/google/`, and `skills/cli/` directories are never symlinked in your environment. Upstream changes to those files will not appear in your install and do not need conflict resolution.

---

## Re-installing After a Merge

After pulling upstream changes, re-run the installer to pick up any new framework skills or hook changes:

```bash
node bin/install.js --profile=core
```

The installer is idempotent — re-running it updates changed symlinks and adds new ones without removing existing ones.

---

## Active Profile Detection

The active profile is stored in `~/.claude/.cortex-profile`. Tools and scripts can read this to branch on profile:

```bash
PROFILE="$(cat ~/.claude/.cortex-profile 2>/dev/null || echo core)"
```

---

## What Stays Internal

- Internal SKILL.md additions (tools specific to your environment)
- Internal agent definitions
- Any `CLAUDE.md` modifications for your team

These never flow back upstream. Keep them on a separate branch or in files that have no upstream equivalent.

---

## Symlinks vs Real Directories

If you previously installed tool skills manually (before the profile system), those paths exist as real directories rather than symlinks. The installer detects this (`EINVAL` on `readlinkSync`) and replaces them with symlinks automatically. Your existing SKILL.md content is overwritten with the canonical repo version — back up any local modifications before running.
