# Spec: cortex-install-profiles

<!-- ART-03: Spec Template — produced by /cortex-spec -->

**Slug:** cortex-install-profiles
**Timestamp:** 20260330T233000Z
**Status:** draft

---

## 1. Problem

The Cortex installer (`bin/install.js`) currently installs a fixed set of framework skills with no mechanism to selectively include or exclude capabilities at install time. Users working in network-restricted environments — such as Meta's internal network — cannot safely use the tool skills (`/web`, `/ai`, `/google`, `/cli`) that call external APIs and expose API key requirements, but there is no install-time option to omit them. Equally, there is no supported path for maintaining a downstream fork of Cortex: an engineer cloning the repo to a corporate environment has no documented workflow for (a) getting a clean, firewall-safe install and (b) pulling upstream framework improvements without merge conflicts from tool-skill files that will never exist in their environment. The result is manual, fragile setup with no repeatability guarantee.

---

## 2. Scope

### In Scope

- `--profile=core|full` flag added to `bin/install.js`; default profile is `core`
- Tool skill source files (`web`, `ai`, `google`, `cli`) moved into `skills/` in the cortex repo so the installer can manage them
- `runtime-manifest.json` skills array migrated from flat strings to tagged objects with `profiles` membership
- `~/.claude/.cortex-profile` marker file written after every install so tooling and re-runs know the active profile
- Post-install API key setup instructions gated on `--profile=full` only
- `test/installer.test.sh` extended with profile-specific test cases
- `DOWNSTREAM.md` added to the repo root with arc diff rebase workflow and `.arcconfig` template for Meta fork users

### Out of Scope

- Bidirectional sync between this repo and any downstream fork
- Managing or scripting the Phabricator / Arcanist (`arc diff`, `arc land`) workflow itself
- Separate branch strategy — both profiles share `main`
- Automated CI testing the `core` profile in isolation
- Sub-profiles beyond `core` / `full`
- OAuth2 or private file access for any tool skill
- Migrating tool skills between machines via `skill-sync.sh`

---

## 3. Architecture Decision

**Chosen approach:** Extend `runtime-manifest.json` so each skill entry is an object with a `profiles` array (`["core", "full"]` for framework skills, `["full"]` for tool skills). `bin/install.js` parses `--profile=core|full` and filters the skills list to only those whose `profiles` array includes the requested profile. After installation, writes the profile name to `~/.claude/.cortex-profile`.

**Rationale:** The manifest is already the single source of truth for everything the installer touches. Extending it with profile tags avoids adding any new state outside the manifest, keeps filter logic to a single `Array.filter()` call in install.js, and makes it trivially extensible to future profiles without structural changes. A flat string array cannot carry profile membership without duplication; tagged objects do so with zero duplication.

### Alternatives Considered

- **Separate `core_skills`/`full_skills` arrays in the manifest:** Any skill belonging to both profiles would be duplicated. Adding a third profile creates `N` arrays. Rejected — duplication and poor extensibility.
- **Separate branch strategy (`main` = full, `core` branch = stripped):** Diverges git history, creates merge overhead for every upstream change, and violates the stated constraint of single-branch deployment. Rejected.
- **Profile-specific manifest files (`runtime-manifest.core.json`):** Two files means two sources of truth; a change to a shared skill must be made in both files. Rejected.
- **Shell script installer:** The installer is already Node.js; introducing a shell script would split installer logic across two runtimes. Rejected — build on what exists.

---

## 4. Interfaces

- **`runtime-manifest.json`** — owned by this repo, read + written — schema migration: `"skills"` from `string[]` to `Array<{name: string, profiles: string[]}>`. Agents and hooks arrays unchanged.
- **`bin/install.js`** — owned by this repo, written — adds `--profile` flag parser, profile-based skill filter, and `~/.claude/.cortex-profile` writer.
- **`~/.claude/.cortex-profile`** — new file, written by installer — plain text, contains `core` or `full`. Read by installer on re-runs to default to last-used profile when `--profile` flag is omitted.
- **`skills/{web,ai,google,cli}/SKILL.md`** — new files, written to repo — source files for the four tool skills, previously unmanaged outside the repo.
- **`test/installer.test.sh`** — owned by this repo, written — new test cases for `--profile=core` and `--profile=full` paths.
- **`DOWNSTREAM.md`** — new file at repo root, written — documentation for downstream fork users.

---

## 5. Dependencies

- **Node.js** (existing) — runtime for `bin/install.js`; no version change required
- **`runtime-manifest.json`** (existing, extended) — manifest schema is extended but install.js is the only consumer
- **`test/installer.test.sh`** (existing, extended) — existing test infrastructure reused; no new test tooling needed
- **Existing tool skill SKILL.md files** (`~/.claude/skills/{web,ai,google,cli}/SKILL.md`) — source content to copy into the repo; already written and confirmed working

---

## 6. Risks

- **Breaking existing manifest consumers if schema change is not handled** — Mitigation: `bin/install.js` is the only file that reads `runtime-manifest.json`; update install.js and the manifest in a single atomic commit so no intermediate state with a broken consumer is ever committed.
- **Existing manually-installed tool skill directories overwritten on re-run** — Mitigation: the current `ensureSymlink()` function already detects real directories (EINVAL) and replaces them with symlinks; behaviour is documented in DOWNSTREAM.md so existing users know what to expect.
- **`~/.claude/.cortex-profile` colliding with Claude Code tooling** — Mitigation: the file is a dotfile inside `~/.claude/` but has a namespaced name (`.cortex-profile`); Claude Code's own settings live in `settings.json`, so no collision is possible with current Claude Code. Confirmed safe.
- **Tool skill SKILL.md files diverging from copies in `~/.claude/skills/`** — Mitigation: once the tool skills are in the repo and managed by the installer, `~/.claude/skills/{web,ai,google,cli}` become symlinks pointing into the repo; the repo copy is the canonical copy.

---

## 7. Sequencing

1. **Copy tool skill SKILL.md files into the repo** (`skills/web/`, `skills/ai/`, `skills/google/`, `skills/cli/`) — verifiable checkpoint: `ls skills/web/SKILL.md skills/ai/SKILL.md skills/google/SKILL.md skills/cli/SKILL.md` exits 0.
2. **Migrate `runtime-manifest.json` schema** — change `skills` from `["cortex-clarify", ...]` to `[{"name": "cortex-clarify", "profiles": ["core", "full"]}, ...]`; add tool skill entries with `"profiles": ["full"]`. Verifiable: JSON is valid, no skill names are duplicated.
3. **Update `bin/install.js`** — parse `--profile` flag (support `--profile=full`, `--profile full`, default `core`); read `.cortex-profile` if no flag; filter skills by profile; write `.cortex-profile` after install. Verifiable: `--dry-run` output lists only framework skills for `--profile=core`.
4. **Gate post-install instructions on profile** — only show API key block in `printSummary()` when profile is `full`. Verifiable: `--profile=core` output does not mention `TAVILY_API_KEY`.
5. **Extend `test/installer.test.sh`** — add tests: core profile produces only framework symlinks; full profile also produces tool skill symlinks; `.cortex-profile` contains correct value; no regressions. Verifiable: `bash test/installer.test.sh` exits 0.
6. **Write `DOWNSTREAM.md`** — arc diff rebase workflow, `.arcconfig` template, `git fetch` reminder, note on `skill-sync.sh` and symlinks. Verifiable: file exists at repo root.

---

## 8. Tasks

- [ ] Copy `~/.claude/skills/web/SKILL.md` → `skills/web/SKILL.md` in the repo
- [ ] Copy `~/.claude/skills/ai/SKILL.md` → `skills/ai/SKILL.md` in the repo
- [ ] Copy `~/.claude/skills/google/SKILL.md` → `skills/google/SKILL.md` in the repo
- [ ] Copy `~/.claude/skills/cli/SKILL.md` → `skills/cli/SKILL.md` in the repo
- [ ] Migrate `runtime-manifest.json` skills array to tagged objects; add tool skills with `"profiles": ["full"]`; tag all existing framework skills with `"profiles": ["core", "full"]`
- [ ] Update `bin/install.js`: add `--profile` flag parser; read `.cortex-profile` as fallback when flag absent; filter skills array by profile membership; default to `core`
- [ ] Update `bin/install.js`: write `~/.claude/.cortex-profile` with active profile name after symlinks complete
- [ ] Update `bin/install.js` `printSummary()`: gate API key setup instructions on `profile === 'full'`
- [ ] Add profile tests to `test/installer.test.sh`: `--profile=core` installs only framework skills, `--profile=full` installs all skills, `.cortex-profile` is written with correct value
- [ ] Write `DOWNSTREAM.md` at repo root with `.arcconfig` template, rebase-before-diff workflow, and note on symlinks vs real dirs

---

## 9. Acceptance Criteria

- [ ] `node bin/install.js --profile=core` symlinks only framework skills (cortex-*) into `~/.claude/skills/`; no tool skill symlinks (web/ai/google/cli) are created
- [ ] `node bin/install.js --profile=full` symlinks both framework skills and tool skills (web, ai, google, cli) into `~/.claude/skills/`
- [ ] `node bin/install.js` with no `--profile` flag behaves identically to `--profile=core`
- [ ] After any install run, `~/.claude/.cortex-profile` exists and contains the profile name that was used
- [ ] Re-running with `--profile=full` after a prior `--profile=core` install adds the tool skill symlinks without removing framework skill symlinks or erroring
- [ ] Post-install API key setup instructions (`TAVILY_API_KEY`, `PPLX_API_KEY`, etc.) do not appear in the output when `--profile=core` is used
- [ ] `bash test/installer.test.sh` exits 0 with all existing tests still passing plus the new profile tests
- [ ] `DOWNSTREAM.md` exists at repo root and contains a usable `.arcconfig` template and the rebase-before-diff workflow
- [ ] Tool skill source files exist at `skills/web/SKILL.md`, `skills/ai/SKILL.md`, `skills/google/SKILL.md`, `skills/cli/SKILL.md` in the repo
