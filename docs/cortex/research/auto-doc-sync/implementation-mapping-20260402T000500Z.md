# Research Dossier: auto-doc-sync — implementation (source-to-doc mapping table)

<!-- ART-02: Research Dossier Template — produced by /cortex-research -->

**Slug:** auto-doc-sync
**Phase:** implementation
**Timestamp:** 20260402T000500Z
**Depth:** quick

---

## Summary

The complete Cortex source-to-doc mapping table is now enumerable. There are three target doc files (`docs/COMMANDS.md`, `docs/HOOKS.md`, `docs/CONTINUITY.md`) and one edge case (`AGENTS.md`). The mapping is 1-to-1 between source files and named sections in each target doc: 8 cortex skill SKILL.md files map to 8 named command sections in COMMANDS.md; 12 hook shell scripts map to 12 named hook entries in HOOKS.md; `.cortex/state.json` schema changes map to the schema table in CONTINUITY.md. AGENTS.md is not a viable auto-doc-sync target — it documents build commands and Codex agent policy, not Cortex source file behavior, and its content is not mechanically derivable from any single source file change.

---

## Findings

### 1. COMMANDS.md Mapping

**Target doc:** `docs/COMMANDS.md`
**Target section pattern:** each command has a named `## /<command-name>` section

| Source file | Target section in COMMANDS.md |
|-------------|-------------------------------|
| `skills/cortex-clarify/SKILL.md` | `## /cortex-clarify` |
| `skills/cortex-research/SKILL.md` | `## /cortex-research` |
| `skills/cortex-spec/SKILL.md` | `## /cortex-spec` |
| `skills/cortex-investigate/SKILL.md` | `## /cortex-investigate` |
| `skills/cortex-review/SKILL.md` | `## /cortex-review` |
| `skills/cortex-audit/SKILL.md` | `## /cortex-audit` |
| `skills/cortex-status/SKILL.md` | `## /cortex-status` |
| `skills/cortex-experiment/SKILL.md` | `## /cortex-experiment` |

**Not mapped to COMMANDS.md** (not part of the Cortex intelligence command surface):
- `skills/cortex-stash/` — `cortex-stash` has no section in COMMANDS.md; it is a utility skill outside the main command spine
- `skills/cortex-fit/` — same; not in the COMMANDS.md command spine
- `skills/cortex-close/` — same
- Non-cortex skills (`ai/`, `cli/`, `google/`, `reup/`, `web/`) — outside Cortex doc surface entirely

**Mapping rule:** when a `skills/cortex-<name>/SKILL.md` changes, the hook looks for a `## /<name>` section in `docs/COMMANDS.md` and updates: Purpose, Inputs table, Outputs table, Rules list, State Effects table, Block Conditions list. The Flag Reference and Artifact Path Quick Reference at the bottom of COMMANDS.md are shared/derived sections — the hook must not touch them unless the change specifically adds or removes a flag.

### 2. HOOKS.md Mapping

**Target doc:** `docs/HOOKS.md`
**Target section pattern:** each hook has a named `### <hook-name>` entry

| Source file | Target section in HOOKS.md |
|-------------|---------------------------|
| `.claude/hooks/cortex-session-start.sh` | `### cortex-session-start` |
| `.claude/hooks/cortex-precompact.sh` | `### cortex-precompact` |
| `.claude/hooks/cortex-postcompact.sh` | `### cortex-postcompact` |
| `.claude/hooks/cortex-session-end.sh` | `### cortex-session-end` |
| `.claude/hooks/cortex-phase-guard.sh` | `### cortex-phase-guard` |
| `.claude/hooks/cortex-write-guard.sh` | `### cortex-write-guard` |
| `.claude/hooks/cortex-validator-trigger.sh` | `### cortex-validator-trigger` |
| `.claude/hooks/cortex-sync.sh` | `### cortex-sync` |
| `.claude/hooks/cortex-distribute.sh` | `### cortex-distribute` |
| `.claude/hooks/cortex-task-created.sh` | `### cortex-task-created` |
| `.claude/hooks/cortex-task-completed.sh` | `### cortex-task-completed` |
| `.claude/hooks/cortex-teammate-idle.sh` | `### cortex-teammate-idle` |

**Not mapped:**
- `.claude/hooks/cortex-distribute.py` — supporting Python script for `cortex-distribute.sh`. Changes to the `.py` script should trigger an update to the `### cortex-distribute` section only if the inputs, outputs, or side effects change. Behavioral changes to the `.py` that don't affect the documented interface are outside the hook's scope.
- `.claude/hooks/nlm-refresh.py` — not a hook; a utility script; no HOOKS.md entry.

**Mapping rule:** when a `cortex-*.sh` file changes, the hook looks for `### <script-name-without-.sh>` in `docs/HOOKS.md` and updates: Trigger conditions, Inputs, Outputs (files written), Side effects, state.json interaction. The Hook Overview table at the top of HOOKS.md (event, matcher, async, blocking columns) must also be checked — if the hook's event, matcher, or blocking behavior changes, that row must be updated. The overview table is a derived section requiring separate targeted update logic.

### 3. CONTINUITY.md Mapping

**Target doc:** `docs/CONTINUITY.md`
**Target sections:**

| Source | Target section | What triggers an update |
|--------|---------------|------------------------|
| `.cortex/state.json` | `## .cortex/state.json Schema` (the JSON block + key fields table + optional/conditional fields table) | Addition, removal, or rename of a top-level field or nested field (e.g., new `gates.*` flag, new optional field) |
| Hook scripts (any) | `## The Continuity Stack → Layer 2: Session Hooks` table | Change to a hook's event type, async flag, or high-level action description |
| Hook count (any addition/removal) | `Hook scripts are installed and wired via .claude/settings.json; Cortex currently ships **N hook scripts** and wires them across **M global Claude Code events**.` | Any hook added or removed |

**Not mapped to CONTINUITY.md:**
- Changes to skill SKILL.md files — CONTINUITY.md does not document skill behavior
- Changes to `docs/cortex/handoffs/` artifact schemas (current-state.md schema, next-prompt.md format) — these are documented inline in CONTINUITY.md but are stable; changes require manual review, not auto-update
- Changes to LOOP-01 through LOOP-04 enforcement sections — these describe which hooks enforce which contract loop requirements; auto-update is risky here because the section is explanatory prose, not a table

### 4. AGENTS.md — Not a Viable Auto-Sync Target

**Source: `AGENTS.md`** is the root-level AGENTS.md for Codex agents. Its content (build commands, validation sequence, definition of done) is not mechanically derivable from any single source file change:
- Build commands (`bash scripts/verify-fast.sh`, etc.) depend on `scripts/` content — but those scripts rarely change and AGENTS.md's build command section would need human judgment to update
- The "Documentation is updated when behavior or workflow changes" rule in AGENTS.md is a policy statement, not a table derived from source

**Decision:** exclude AGENTS.md from auto-doc-sync scope. Changes to AGENTS.md are always manual. This aligns with the clarify brief's non-goals: "Not replacing human judgment on architectural or design documentation."

### 5. Edge Cases in the Mapping

- **New skill added** (new `skills/cortex-<name>/` directory with a new SKILL.md): no corresponding COMMANDS.md section exists yet. The hook must detect this and warn rather than attempt to create a new section — section creation is initial authoring, which is explicitly a non-goal.
- **Skill removed**: if a skill directory is deleted, the hook cannot detect the deletion via a file-change trigger (deleted files don't appear in `git diff --cached` the same way). The mapping config entry for that skill should be removed manually.
- **Hook renamed**: if a `.sh` script is renamed, the old section in HOOKS.md becomes stale. The hook can only update sections for source files that exist in the current commit — it cannot detect renames without explicit `git diff --diff-filter=R` handling.
- **HOOKS.md Hook Overview table**: this top-level summary table in HOOKS.md has 6 columns (Hook, Event, Matcher, Async, Blocking). It must be kept in sync with the `### <hook>` entries below it. The auto-doc-sync hook should treat the overview table as a derived section and regenerate the relevant row whenever the underlying hook entry changes.

---

## Trade-offs

### Option A: Flat config with explicit per-entry mapping
```json
[
  {
    "id": "commands-cortex-clarify",
    "source_glob": "skills/cortex-clarify/SKILL.md",
    "target_doc": "docs/COMMANDS.md",
    "target_section": "## /cortex-clarify",
    "prompt_hint": "Update the Purpose, Inputs, Outputs, Rules, State Effects, and Block Conditions sections only. Do not touch the Flag Reference or Artifact Path Quick Reference sections."
  }
]
```
**Pros:** Explicit, human-readable, no glob ambiguity, per-entry prompt hints possible.
**Cons:** 20+ entries for the full Cortex surface; verbose; adding a new skill/hook requires a manual config entry.
**Verdict:** selected — the Cortex doc surface is stable enough that manual config maintenance is acceptable.

### Option B: Convention-based glob inference
`skills/cortex-*/SKILL.md` → section heading derived from directory name.
**Pros:** Zero config for new skills.
**Cons:** Cannot express prompt hints per entry; cannot exclude non-mapped skills (cortex-stash, cortex-fit); HOOKS.md has a different section naming convention (`###` vs `##`).
**Verdict:** deferred — viable for the skills→COMMANDS.md mapping only; not general enough for the full surface.

---

## Recommendations

- Use the **flat config** (Option A) as `.auto-doc-sync.json`. The complete initial config has 22 entries: 8 for COMMANDS.md, 12 for HOOKS.md, 2 for CONTINUITY.md (state.json fields → schema table; hook changes → Layer 2 table). AGENTS.md is excluded.
- Add a `prompt_hint` field per entry to constrain which subsections the LLM may modify. Example: COMMANDS.md entries specify `"update_sections": ["Purpose", "Inputs", "Outputs", "Rules", "State Effects", "Block Conditions"]` and explicitly list `"skip_sections": ["Flag Reference", "Artifact Path Quick Reference"]`.
- Handle the HOOKS.md Hook Overview table as a special case: any hook change triggers both `### <hook-name>` and the corresponding row in `| Hook Overview |`. This requires two target entries per hook script, or a special `also_update` field in the config.
- Detect and warn on new-skill additions (no COMMANDS.md section exists): emit a warning in stdout, skip LLM call, do not fail the commit.
- Explicitly document the exclusions in `.auto-doc-sync.json` with a `"skip": true` field plus a `"reason"` field for auditability: `{ "source_glob": "AGENTS.md", "skip": true, "reason": "AGENTS.md documents build policy; not mechanically derivable from source changes" }`.

---

## Open Questions

- The HOOKS.md Hook Overview table requires updating when any hook's event/async/blocking changes. Should this be modeled as a second mapping entry per hook (verbose) or as an `also_update` field pointing at the overview table (requires config schema extension)?
- How does the hook handle a `cortex-distribute.py` change that does affect the documented interface (e.g., a new `--surfaces` flag)? The trigger is `.py`, not `.sh` — should `.py` files be first-class source entries in `.auto-doc-sync.json`?
- The CONTINUITY.md hook-count sentence (`Cortex currently ships **N hook scripts**`) is hardcoded prose. Should the hook update this number automatically, or flag it as a manual update? Automatic update risks off-by-one errors if multiple hooks are added in one commit.

---

## Sources

- `/home/agent/projects/cortex/docs/COMMANDS.md` — full command reference; enumerated all 8 cortex command sections and their subsection structure
- `/home/agent/projects/cortex/docs/HOOKS.md` — full hook reference; enumerated all 12 hook entries, Hook Overview table structure
- `/home/agent/projects/cortex/docs/CONTINUITY.md` — continuity strategy; identified state.json schema table and Layer 2 hook table as the two auto-sync targets
- `/home/agent/projects/cortex/AGENTS.md` — Codex agent instructions; determined it is not a viable auto-sync target
- `/home/agent/projects/cortex/skills/` directory listing — confirmed 8 cortex command skills; identified 5 skills outside COMMANDS.md scope
- `/home/agent/.claude/hooks/` directory listing — confirmed 12 cortex hook scripts plus 2 non-hook Python utilities
