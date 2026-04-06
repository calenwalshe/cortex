# Cortex Intent — Owner Alignment Layer

Manages the owner-intent.md and preferences.json artifacts that give Cortex a durable "why" layer. These files live at `docs/cortex/intent/` and are consumed by cortex-drive (ranking, safety checks), cortex-spec (necessity gate), and cortex-clarify (constraint injection).

## User-invocable
When the user types `/cortex-intent`, run this skill.
Also trigger when: "set my intent", "update preferences", "what are my objectives", "review intent".

## Arguments
- `/cortex-intent init` — Interactive bootstrap. Seeds from CLAUDE.md and project history.
- `/cortex-intent review` — Check for stale preferences, contradictions, and drift.
- `/cortex-intent update <section>` — Targeted edit to a specific section or preference.
- `/cortex-intent diff` — Show what changed since last confirmed version.

## Instructions

### Subcommand: init

1. **Check existing:** If `docs/cortex/intent/owner-intent.md` already exists, warn: "Intent already exists. Use `update` to modify or `review` to check freshness." Proceed only if user confirms overwrite.

2. **Gather signals:** Read these sources silently:
   - `~/.claude/CLAUDE.md` (global preferences)
   - `.claude/rules/*.md` (behavioral rules)
   - Recent archived slugs in `docs/cortex/archive/` (what's been built)
   - `~/.cortex/stash/` (what's queued)
   - `docs/cortex/research/autonomous-builder-ideas.md` (if exists)

3. **Ask 5-8 focused questions:**
   - "What is this project for?" (seeds Mission)
   - "What are the 3-5 most important outcomes you want?" (seeds Objectives)
   - "What must never be violated — hard rules that no work can break?" (seeds Non-Negotiables, pre-populated from CLAUDE.md constraints)
   - "When speed and correctness conflict, which wins?" (seeds Tradeoff Preferences)
   - "What would make you abandon this project or a feature within it?" (seeds Kill Criteria)
   - "How much autonomous decision-making do you want?" (seeds workflow.default_autonomy preference)
   - "What's your current priority focus?" (seeds Current Initiatives)

4. **Generate both files:**
   - Read `templates/cortex/owner-intent.md` and populate all sections.
   - Generate `preferences.json` from answers, using explicit source and current date as last_confirmed.
   - Write both to `docs/cortex/intent/`.

5. **Present for review.** Show the generated content. Owner edits or approves.

### Subcommand: review

1. **Read both files** from `docs/cortex/intent/`.

2. **Staleness check:** For each preference in preferences.json:
   - Calculate age from `last_confirmed`.
   - Apply TTL: requirement = never expires, preference = 180 days, suggestion = 90 days.
   - If expired: flag as stale with current effective strength (demoted by one level).
   - Report: "N of M preferences are stale. {list with recommended actions}."

3. **Contradiction check:** Compare non-negotiables against recent execution patterns:
   - Read last 5 entries in `docs/cortex/handoffs/decisions.md`.
   - Flag if any decision contradicts a non-negotiable.

4. **Review cadence check:** Compare `last_updated` in frontmatter against `review_cadence`. If overdue: "Intent review is N days overdue."

5. **Output review summary** with actionable recommendations.

### Subcommand: update

1. Accept a `<section>` argument (e.g., "objectives", "tradeoffs", "preferences.workflow.research_depth").
2. If section is in owner-intent.md: read file, present current content for that section, ask for changes, rewrite.
3. If section is a preferences.json key: read file, present current preference, ask for new value, update and bump `last_confirmed`.
4. Bump `last_updated` in owner-intent.md frontmatter.

### Subcommand: diff

1. Run `git diff docs/cortex/intent/` to show what changed since last commit.
2. If no uncommitted changes: run `git log --oneline -5 -- docs/cortex/intent/` to show recent history.

## Rules

- Does not modify any other Cortex artifacts (state.json, contracts, specs). Intent is input-only.
- Does not modify CLAUDE.md or memory files. Intent is a separate artifact with a clear boundary.
- Both files must always be written together. An owner-intent.md without preferences.json (or vice versa) is incomplete.
- The init subcommand must present generated content for human approval before writing. Never auto-write intent without review.
- Intent artifacts survive /cortex-close (they're project-scoped, not per-slug).

## Output Format

After init or update:

```
INTENT UPDATED
════════════════════════════════════════
Files:   docs/cortex/intent/owner-intent.md
         docs/cortex/intent/preferences.json
Updated: {timestamp}
Objectives: {N}
Non-Negotiables: {N}
Preferences: {N} ({stale_count} stale)

Consumed by: cortex-drive (ranking, safety), cortex-spec (necessity), cortex-clarify (constraints)
════════════════════════════════════════
```
