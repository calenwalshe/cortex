# Contract: cortex-install-profiles — execute

<!-- ART-05: Contract Template — produced by /cortex-spec -->
<!-- IMPORTANT: A contract without the eval_plan field is incomplete and must not advance past spec state. -->

**ID:** cortex-install-profiles-001
**Slug:** cortex-install-profiles
**Phase:** execute
**Created:** 20260330T233000Z
**Status:** approved

---

## Objective

Add `--profile=core|full` to the Cortex installer and move tool skills into the repo so that a single `node bin/install.js --profile=core` command produces a firewall-safe, API-free Cortex install suitable for downstream corporate forks.

---

## Deliverables

- Modified: `bin/install.js`
- Modified: `runtime-manifest.json`
- New: `skills/web/SKILL.md`
- New: `skills/ai/SKILL.md`
- New: `skills/google/SKILL.md`
- New: `skills/cli/SKILL.md`
- Modified: `test/installer.test.sh`
- New: `DOWNSTREAM.md`

---

## Scope

### In Scope

- `--profile=core|full` flag in `bin/install.js`; default `core`
- `runtime-manifest.json` skills schema migration to tagged objects with `profiles` membership
- Tool skill SKILL.md files copied into `skills/` in the repo
- `~/.claude/.cortex-profile` marker file written after install
- Post-install API key instructions gated on `--profile=full`
- Profile test cases added to `test/installer.test.sh`
- `DOWNSTREAM.md` with arc diff workflow and `.arcconfig` template

### Out of Scope

- Bidirectional fork sync
- Phabricator/Arcanist workflow scripting
- Separate branch strategy
- Automated CI for `core` profile
- Sub-profiles beyond `core`/`full`
- `skill-sync.sh` profile awareness

---

## Write Roots

- `bin/`
- `runtime-manifest.json`
- `skills/web/`
- `skills/ai/`
- `skills/google/`
- `skills/cli/`
- `test/`
- `DOWNSTREAM.md`

---

## Done Criteria

- [ ] `node bin/install.js --profile=core` symlinks only framework skills (cortex-*); no tool skill symlinks created
- [ ] `node bin/install.js --profile=full` symlinks framework skills AND tool skills (web, ai, google, cli)
- [ ] `node bin/install.js` (no flag) behaves identically to `--profile=core`
- [ ] After any install, `~/.claude/.cortex-profile` exists and contains the active profile name
- [ ] Re-running `--profile=full` after `--profile=core` adds tool skill symlinks without error or framework skill removal
- [ ] API key setup instructions do not appear in output when `--profile=core` is used
- [ ] `bash test/installer.test.sh` exits 0; all existing tests pass; new profile tests pass
- [ ] `DOWNSTREAM.md` exists at repo root with `.arcconfig` template and rebase-before-diff workflow
- [ ] `skills/web/SKILL.md`, `skills/ai/SKILL.md`, `skills/google/SKILL.md`, `skills/cli/SKILL.md` exist in repo

---

## Validators

- [ ] `node bin/install.js --dry-run --profile=core` — output lists only cortex-* skills, no web/ai/google/cli
- [ ] `node bin/install.js --dry-run --profile=full` — output lists all skills including web/ai/google/cli
- [ ] `node bin/install.js --profile=core && cat ~/.claude/.cortex-profile` — outputs `core`
- [ ] `node bin/install.js --profile=full && cat ~/.claude/.cortex-profile` — outputs `full`
- [ ] `node bin/install.js --profile=core` output does not contain `TAVILY_API_KEY`
- [ ] `bash test/installer.test.sh` — exits 0
- [ ] `ls skills/web/SKILL.md skills/ai/SKILL.md skills/google/SKILL.md skills/cli/SKILL.md` — exits 0
- [ ] `ls DOWNSTREAM.md` — exits 0

---

## Eval Plan

[docs/cortex/evals/cortex-install-profiles/eval-plan.md](../../evals/cortex-install-profiles/eval-plan.md)

---

## Approvals

- [ ] Contract approval
- [ ] Evals approval

---

## Rollback Hints

- `git checkout HEAD -- bin/install.js` — restore original installer
- `git checkout HEAD -- runtime-manifest.json` — restore original manifest
- `rm -rf skills/web/ skills/ai/ skills/google/ skills/cli/` — remove tool skill files from repo
- `rm -f DOWNSTREAM.md` — remove downstream docs
- `rm -f ~/.claude/.cortex-profile` — remove profile marker
- No changes to `~/.claude/skills/` symlinks beyond what the installer manages — existing framework symlinks are unaffected
