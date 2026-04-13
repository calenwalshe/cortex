# Contract: system-decomposition-map — execute

**ID:** system-decomposition-map-001
**Slug:** system-decomposition-map
**Phase:** execute
**Created:** 20260409T193000Z
**Status:** draft
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Build a persistent system decomposition map artifact and integrate it into Cortex so that LLM sessions have cumulative architectural context, replacing the dead `project-context.md` pattern with a system-wide, advisory, human-confirmed map.

---

## Deliverables

- `templates/cortex/system-map.md` — system map template with all sections
- `.claude/skills/cortex-map/SKILL.md` — `/cortex-map` command skill
- `.claude/hooks/cortex-session-start.sh` — modified to inject map pointer + freshness
- `.claude/skills/cortex-spec/SKILL.md` — modified Phase 2 + Phase 2b
- `.claude/skills/cortex-review/SKILL.md` — modified architecture lens
- `.claude/skills/cortex-research/SKILL.md` — modified Outside-In queries
- `docs/cortex/system-map.md` — initial system map for Cortex project

---

## Scope

### In Scope

- System map template with YAML frontmatter, Mermaid C4 L1-L2, component registry, conventions, decisions
- `/cortex-map` skill with generate, refresh, verify modes
- Session-start hook pointer injection with freshness computation
- Skill modifications for cortex-spec, cortex-review, cortex-research
- Initial system map generation for the Cortex project

### Out of Scope

- Auto-sync or auto-update mechanisms
- Blocking gates based on map freshness
- C4 Level 4 (code-level) decomposition
- Tree-sitter or AST-based tooling
- Deletion of existing project-context.md files
- GSD or .planning/ modifications

---

## Write Roots

- `templates/cortex/system-map.md`
- `.claude/skills/cortex-map/`
- `.claude/hooks/cortex-session-start.sh`
- `.claude/skills/cortex-spec/SKILL.md`
- `.claude/skills/cortex-review/SKILL.md`
- `.claude/skills/cortex-research/SKILL.md`
- `docs/cortex/system-map.md`
- `docs/cortex/specs/system-decomposition-map/`
- `docs/cortex/contracts/system-decomposition-map/`

---

## Done Criteria

- [ ] `templates/cortex/system-map.md` exists with all 6 sections (frontmatter, System Context, Containers, Component Registry, Crosscutting Conventions, Key Decisions) and inline comments
- [ ] `.claude/skills/cortex-map/SKILL.md` exists and defines generate, refresh, and verify modes with human confirmation gates
- [ ] `cortex-session-start.sh` injects a map pointer + freshness status line when `docs/cortex/system-map.md` exists, and silently skips when it doesn't
- [ ] `cortex-spec` Phase 2 reads the system map for interface context (grep confirms instruction)
- [ ] `cortex-spec` Phase 2b proposes system map updates instead of writing per-slug `project-context.md`
- [ ] `cortex-review` architecture lens reads the system map as reference artifact (grep confirms instruction)
- [ ] `cortex-research` Outside-In queries reference the system map for structural context (grep confirms instruction)
- [ ] Initial system map generated for Cortex is under 3K tokens (wc -w < 2250)
- [ ] Session-start hook freshness: "fresh" (<60d), "aging" (60-90d), "stale" (>90d)
- [ ] No Cortex command fails when `docs/cortex/system-map.md` does not exist

---

## Validators

- [ ] [external] `test -f templates/cortex/system-map.md` — template exists
- [ ] [external] `test -f .claude/skills/cortex-map/SKILL.md` — skill exists
- [ ] [external] `grep -q 'system-map' .claude/hooks/cortex-session-start.sh` — hook references map
- [ ] [external] `grep -q 'system-map' .claude/skills/cortex-spec/SKILL.md` — spec skill references map
- [ ] [external] `grep -q 'system-map' .claude/skills/cortex-review/SKILL.md` — review skill references map
- [ ] [external] `grep -q 'system-map' .claude/skills/cortex-research/SKILL.md` — research skill references map
- [ ] [external] `test -f docs/cortex/system-map.md` — initial map exists
- [ ] [external] `wc -w < docs/cortex/system-map.md | awk '{exit ($1 > 2250)}'` — under 3K token budget
- [ ] [external] `grep -q 'last_verified' docs/cortex/system-map.md` — freshness envelope present
- [ ] [judgment] The initial system map accurately reflects the current Cortex system architecture

---

## Eval Plan

docs/cortex/evals/system-decomposition-map/eval-plan.md (pending)

---

## Approvals

- [ ] Contract approval
- [ ] Evals approval

---

## Completion Promise

<!-- CORTEX_PROMISE: system-decomposition-map-001 COMPLETE -->

---

## Failed Approaches

<!-- N/A — initial contract -->

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Delete `templates/cortex/system-map.md`
- Delete `.claude/skills/cortex-map/` directory
- Revert `.claude/hooks/cortex-session-start.sh` to pre-modification state (remove system-map block)
- Revert skill modifications in `cortex-spec`, `cortex-review`, `cortex-research` (remove system-map read instructions)
- Delete `docs/cortex/system-map.md` if generated
- Git: `git diff HEAD~1 -- .claude/hooks/ .claude/skills/ templates/` to see all modifications

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
