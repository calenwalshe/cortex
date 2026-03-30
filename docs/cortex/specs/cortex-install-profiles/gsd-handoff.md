# GSD Handoff: cortex-install-profiles

<!-- ART-04: GSD Handoff Template — produced by /cortex-spec -->
<!-- This is a GSD-ready work order. The human imports this into GSD explicitly. -->
<!-- Cortex NEVER calls GSD commands — that is always a human step. -->

**Slug:** cortex-install-profiles
**Timestamp:** 20260330T233000Z
**Status:** draft

---

## Objective

Add a `--profile=core|full` flag to the Cortex installer (`bin/install.js`) so that a `core` install deploys only the framework skills (no external API dependencies) and a `full` install also deploys the tool skills (web, ai, google, cli). This enables users working behind a corporate firewall (e.g., Meta) to clone the repo and install a clean, API-free Cortex environment that can receive upstream framework updates without merge conflicts from tool-skill files they will never use.

---

## Deliverables

- Modified: `bin/install.js` — `--profile` flag, skill filter, `.cortex-profile` marker writer, gated post-install instructions
- Modified: `runtime-manifest.json` — skills migrated from string array to tagged objects with `profiles` membership
- New: `skills/web/SKILL.md` — tool skill source moved into repo
- New: `skills/ai/SKILL.md` — tool skill source moved into repo
- New: `skills/google/SKILL.md` — tool skill source moved into repo
- New: `skills/cli/SKILL.md` — tool skill source moved into repo
- Modified: `test/installer.test.sh` — new profile test cases
- New: `DOWNSTREAM.md` — arc diff workflow and `.arcconfig` template for downstream fork users

---

## Requirements

- None formalized

---

## Tasks

- [ ] Copy `~/.claude/skills/web/SKILL.md` → `skills/web/SKILL.md` in the repo
- [ ] Copy `~/.claude/skills/ai/SKILL.md` → `skills/ai/SKILL.md` in the repo
- [ ] Copy `~/.claude/skills/google/SKILL.md` → `skills/google/SKILL.md` in the repo
- [ ] Copy `~/.claude/skills/cli/SKILL.md` → `skills/cli/SKILL.md` in the repo
- [ ] Migrate `runtime-manifest.json` skills array to tagged objects; tag existing framework skills with `"profiles": ["core", "full"]`; add tool skills with `"profiles": ["full"]` only
- [ ] Update `bin/install.js`: add `--profile` flag parser; read `~/.claude/.cortex-profile` as fallback when flag is absent; filter skills array by profile membership; default to `core`
- [ ] Update `bin/install.js`: write `~/.claude/.cortex-profile` with active profile name after symlinks complete
- [ ] Update `bin/install.js` `printSummary()`: gate API key setup instructions on `profile === 'full'`
- [ ] Add profile tests to `test/installer.test.sh`: `--profile=core` installs only framework skills, `--profile=full` installs all skills, `.cortex-profile` is written correctly
- [ ] Write `DOWNSTREAM.md` at repo root with `.arcconfig` template, rebase-before-diff workflow, and note on symlinks vs real dirs

---

## Acceptance Criteria

- [ ] `node bin/install.js --profile=core` symlinks only framework skills (cortex-*) into `~/.claude/skills/`; no tool skill symlinks (web/ai/google/cli) are created
- [ ] `node bin/install.js --profile=full` symlinks both framework skills and tool skills (web, ai, google, cli) into `~/.claude/skills/`
- [ ] `node bin/install.js` with no `--profile` flag behaves identically to `--profile=core`
- [ ] After any install run, `~/.claude/.cortex-profile` exists and contains the profile name that was used
- [ ] Re-running with `--profile=full` after a prior `--profile=core` install adds the tool skill symlinks without removing framework skill symlinks or erroring
- [ ] Post-install API key setup instructions (`TAVILY_API_KEY`, `PPLX_API_KEY`, etc.) do not appear in the output when `--profile=core` is used
- [ ] `bash test/installer.test.sh` exits 0 with all existing tests still passing plus the new profile tests
- [ ] `DOWNSTREAM.md` exists at repo root and contains a usable `.arcconfig` template and the rebase-before-diff workflow
- [ ] Tool skill source files exist at `skills/web/SKILL.md`, `skills/ai/SKILL.md`, `skills/google/SKILL.md`, `skills/cli/SKILL.md` in the repo

---

## Contract Link

docs/cortex/contracts/cortex-install-profiles/contract-001.md
