# GSD Handoff: system-decomposition-map

**Slug:** system-decomposition-map
**Timestamp:** 20260409T193000Z
**Status:** draft

---

## Objective

Create a persistent system decomposition map artifact and integrate it into the Cortex lifecycle so that LLM sessions have cumulative architectural context across slugs — replacing the dead `project-context.md` pattern with a system-wide, human-confirmed, advisory map.

---

## Deliverables

- Template: `templates/cortex/system-map.md` — artifact schema with all sections and inline documentation
- Skill: `.claude/skills/cortex-map/SKILL.md` — `/cortex-map` command (generate, refresh, verify modes)
- Hook modification: `.claude/hooks/cortex-session-start.sh` — map pointer + freshness injection
- Skill modification: `.claude/skills/cortex-spec/SKILL.md` — Phase 2 reads map, Phase 2b proposes updates
- Skill modification: `.claude/skills/cortex-review/SKILL.md` — architecture lens reads map
- Skill modification: `.claude/skills/cortex-research/SKILL.md` — Outside-In queries use map
- Generated artifact: `docs/cortex/system-map.md` — initial map for the Cortex project

---

## Requirements

- None formalized

---

## Tasks

- [ ] Write `templates/cortex/system-map.md` with YAML frontmatter, C4 L1-L2 Mermaid diagrams, component registry table, crosscutting conventions, key decisions sections
- [ ] Write `.claude/skills/cortex-map/SKILL.md` with generate mode (LLM reads codebase + artifacts, proposes map, user confirms), refresh mode (proposes updates from recent slug work), verify mode (checks accuracy, updates `last_verified`)
- [ ] Modify `.claude/hooks/cortex-session-start.sh`: add map pointer + freshness status after facts block (line ~41)
- [ ] Modify `.claude/skills/cortex-spec/SKILL.md` Phase 2: read system map for interface context
- [ ] Modify `.claude/skills/cortex-spec/SKILL.md` Phase 2b: propose system map updates instead of writing per-slug `project-context.md`
- [ ] Modify `.claude/skills/cortex-review/SKILL.md` architecture lens: read system map as reference
- [ ] Modify `.claude/skills/cortex-research/SKILL.md` Outside-In queries: read system map for structural context
- [ ] Generate initial system map for Cortex project, verify under 3K tokens

---

## Acceptance Criteria

- [ ] Template exists with all 6 sections and inline comments
- [ ] `/cortex-map` skill exists with generate, refresh, verify modes and human confirmation gates
- [ ] Session-start hook injects map pointer when map exists, silently skips when it doesn't
- [ ] cortex-spec reads the system map for interface context
- [ ] cortex-spec proposes map updates instead of writing per-slug project-context.md
- [ ] cortex-review architecture lens reads system map
- [ ] cortex-research Outside-In queries reference system map
- [ ] Initial Cortex system map is under 3K tokens
- [ ] Freshness status correctly computes: fresh (<60d), aging (60-90d), stale (>90d)
- [ ] No command fails when system map does not exist

---

## Contract Link

docs/cortex/contracts/system-decomposition-map/contract-001.md
