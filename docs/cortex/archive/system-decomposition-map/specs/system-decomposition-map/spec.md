# Spec: system-decomposition-map

**Slug:** system-decomposition-map
**Timestamp:** 20260409T193000Z
**Status:** draft

---

## 1. Problem

Cortex builds systems across multiple slugs, but no artifact captures the cumulative architectural picture. Each session re-derives system context from scratch — interface maps are scattered across archived specs, cross-slug dependencies are unrecorded, and `project-context.md` (the closest existing artifact) is generated per-slug but never loaded by the session-start hook. The LLM lacks persistent architectural context, leading to redundant exploration, inconsistent interface assumptions across specs, and an architecture review lens with no reference artifact. This costs time on every slug and reduces the quality of specs and reviews.

---

## 2. Scope

### In Scope

- A system map template at `templates/cortex/system-map.md` defining the artifact schema
- A `/cortex-map` skill that generates and refreshes the system map via LLM-assisted discovery with human confirmation
- Modification to `cortex-session-start.sh` to inject a pointer + freshness status line (~50 tokens) when the map exists
- Modification to `cortex-spec`, `cortex-review`, and `cortex-research` skills to read `docs/cortex/system-map.md` when it exists
- Modification to `cortex-spec` Phase 2b to propose system map updates instead of writing per-slug `project-context.md`
- YAML frontmatter freshness envelope (`last_verified`, `valid_until`, `confidence`, `advisory: true`)
- Mermaid C4 diagrams (Levels 1-2) within the map template
- Component registry as a markdown table
- Crosscutting conventions and key decisions sections

### Out of Scope

- Auto-sync or auto-update mechanisms — the map is never written without human confirmation
- Blocking gates based on map freshness — the map is advisory only
- Code-level decomposition (C4 Level 4) — the LLM reads source files directly
- Formal ADR system — key decisions are terse entries, not full ADR records
- Tree-sitter or AST-based auto-generation — derived sections are populated by LLM codebase reading, not tooling
- Changes to GSD, `.planning/`, or any execution-layer artifacts
- Deletion of existing `project-context.md` files — they remain on disk but are no longer generated for new slugs

---

## 3. Architecture Decision

**Chosen approach:** A single Markdown file at `docs/cortex/system-map.md` with Mermaid C4 diagrams, a component registry table, crosscutting conventions, and key decisions. Delivered via pointer injection in the session-start hook + direct reads by skills.

**Rationale:** The 10K character `additionalContext` cap eliminates full hook injection. Pointer injection (~50 tokens) is negligible and benefits from prefix caching. Skills that need system context read the full file — no cap, no truncation. Markdown + Mermaid is the most token-efficient format for LLM consumption (5.5x over ASCII, 34-38% fewer tokens than JSON). YAML frontmatter provides machine-readable freshness metadata without blocking semantics.

### Alternatives Considered
- **Full hook injection:** Rejected — 10K char cap makes this infeasible for a 3K-token map. The map would be truncated or replaced with a file pointer by the harness anyway.
- **Inline into CLAUDE.md:** Rejected — violates the "keep CLAUDE.md minimal" consensus. Would consume 3K tokens on every session even when not needed.
- **YAML component graph as primary format:** Rejected — less human-readable for narrative content. YAML is used for frontmatter only; body is Markdown + Mermaid.
- **Auto-generated from code (aider repo-map style):** Rejected as the full solution — cannot capture intent, rationale, or conventions. Code-derivable facts should be refreshable, but the map's value is in human-asserted context.
- **Auto-update via cortex-spec:** Rejected — high risk of hallucination propagating to all downstream commands. Updates must be proposed and human-confirmed.
- **Separate artifact per C4 level:** Deferred — start monolithic, split if token budget is exceeded.

---

## 4. Interfaces

- **`docs/cortex/system-map.md`** — New file. Owned by the user (generated/refreshed via `/cortex-map`). Read by `cortex-spec`, `cortex-review`, `cortex-research`. Never written by any command except `/cortex-map` with human confirmation.
- **`templates/cortex/system-map.md`** — New template file. Owned by Cortex framework. Read by `/cortex-map` when generating a new map.
- **`.claude/hooks/cortex-session-start.sh`** — Existing hook. Modified to inject a map pointer + freshness status line. Reads `docs/cortex/system-map.md` frontmatter only (grep for `last_verified`).
- **`.claude/skills/cortex-spec/SKILL.md`** — Existing skill. Modified: Phase 2 reads system map for interface context; Phase 2b proposes map updates instead of writing per-slug `project-context.md`.
- **`.claude/skills/cortex-review/SKILL.md`** — Existing skill. Modified: architecture lens reads system map as reference artifact.
- **`.claude/skills/cortex-research/SKILL.md`** — Existing skill. Modified: Outside-In query reformulation reads system map for structural context.
- **`.claude/skills/cortex-map/SKILL.md`** — New skill file. The `/cortex-map` command.

---

## 5. Dependencies

- Mermaid diagram syntax — used for C4 Level 1-2 diagrams within the map. No library dependency; Mermaid is rendered by GitHub/GitLab/documentation platforms.
- YAML frontmatter parsing — used by session-start hook. Parsed via `grep` + `sed` in bash (no library needed).
- Existing Cortex skill infrastructure — skill files in `.claude/skills/`, hook files in `.claude/hooks/`.
- `docs/cortex/specs/*/project-context.md` — existing per-slug artifacts used as seed data for initial map generation.

---

## 6. Risks

- **Map bloats past 3K tokens as the system grows** — Mitigation: the `/cortex-map` skill enforces a token budget check before writing. If the proposed map exceeds 5K tokens, it warns and suggests splitting or summarizing. The component registry is the most likely section to grow; compress by grouping related components.
- **Skills read a stale map and produce wrong outputs** — Mitigation: the freshness envelope provides explicit confidence metadata. Skills should prefix map-derived context with "System map context (last verified {date}):" so the LLM can weight it appropriately. The advisory: true field signals non-authoritative status.
- **`/cortex-map` generates an inaccurate initial decomposition** — Mitigation: the command always presents the proposed map for human review before writing. The user confirms, edits, or rejects. No blind writes.
- **Hook modification breaks session-start context injection** — Mitigation: the hook change is additive (new block after line 41). The map pointer is appended to `$EXTRA` alongside facts. If the map file doesn't exist, the block is skipped silently.

---

## 7. Sequencing

1. Create `templates/cortex/system-map.md` — the template defining the map schema with all sections, frontmatter fields, and inline comments.
2. Create `.claude/skills/cortex-map/SKILL.md` — the `/cortex-map` command with generate, refresh, and verify modes.
3. Modify `.claude/hooks/cortex-session-start.sh` — add map pointer + freshness status injection after the facts block.
4. Modify `.claude/skills/cortex-spec/SKILL.md` — Phase 2 reads the map; Phase 2b proposes map updates instead of writing `project-context.md`.
5. Modify `.claude/skills/cortex-review/SKILL.md` — architecture lens reads the map as reference artifact.
6. Modify `.claude/skills/cortex-research/SKILL.md` — Outside-In queries use the map for structural context.
7. Test: run `/cortex-map` on the current Cortex project to generate an initial system map, verify format and token count.

---

## 8. Tasks

- [ ] Write `templates/cortex/system-map.md` with all sections: YAML frontmatter (freshness envelope), System Context (C4 L1 Mermaid), Containers (C4 L2 Mermaid), Component Registry (markdown table), Crosscutting Conventions, Key Decisions
- [ ] Write `.claude/skills/cortex-map/SKILL.md` with three modes: generate (initial creation from codebase + existing artifacts), refresh (propose updates from recent slug work), verify (check map accuracy against codebase, update `last_verified`)
- [ ] Modify `.claude/hooks/cortex-session-start.sh`: add block after line 41 that reads map frontmatter, computes days since `last_verified`, and appends a pointer + freshness status line to `$EXTRA`
- [ ] Modify `.claude/skills/cortex-spec/SKILL.md` Phase 2: add instruction to read `docs/cortex/system-map.md` if it exists before synthesizing interfaces
- [ ] Modify `.claude/skills/cortex-spec/SKILL.md` Phase 2b: change from writing per-slug `project-context.md` to proposing system map updates (generate diff, present to user)
- [ ] Modify `.claude/skills/cortex-review/SKILL.md` architecture lens: add instruction to read `docs/cortex/system-map.md` as reference artifact for pattern checking
- [ ] Modify `.claude/skills/cortex-research/SKILL.md` Outside-In queries: add instruction to read system map for structural context when reformulating angle queries
- [ ] Generate initial system map for the Cortex project using `/cortex-map` and verify token count is under 3K

---

## 9. Acceptance Criteria

- [ ] `templates/cortex/system-map.md` exists and contains all 6 sections (frontmatter, System Context, Containers, Component Registry, Crosscutting Conventions, Key Decisions) with inline comments explaining each field
- [ ] `.claude/skills/cortex-map/SKILL.md` exists and defines generate, refresh, and verify modes with human confirmation gates
- [ ] `cortex-session-start.sh` injects a map pointer + freshness status line when `docs/cortex/system-map.md` exists, and silently skips when it doesn't
- [ ] `cortex-spec` Phase 2 reads the system map for interface context (grep for "system-map" in the skill file confirms the instruction)
- [ ] `cortex-spec` Phase 2b proposes system map updates instead of writing per-slug `project-context.md`
- [ ] `cortex-review` architecture lens reads the system map as reference artifact (grep confirms instruction)
- [ ] `cortex-research` Outside-In queries reference the system map for structural context (grep confirms instruction)
- [ ] An initial system map generated for Cortex is under 3K tokens (verified via `wc -w` approximation: under 2250 words)
- [ ] The session-start hook correctly computes freshness status: "fresh" (<60 days), "aging" (60-90 days), "stale" (>90 days)
- [ ] No Cortex command fails or errors when `docs/cortex/system-map.md` does not exist — all reads are guarded with existence checks
