# Cortex Map — System Decomposition Map Generator

Generates, refreshes, and verifies a persistent system decomposition map at `docs/cortex/system-map.md`. The map provides cumulative architectural context for LLM reasoning across sessions. All writes require human confirmation — the map is never auto-updated.

## User-invocable

When the user types `/cortex-map`, run this skill.
Also trigger when: "generate system map", "refresh the map", "update system map", "verify the map", "show system architecture".

## Arguments

- `/cortex-map [--mode generate|refresh|verify]` — defaults to `refresh` if map exists, `generate` if it doesn't
- `--mode generate` — create a new map from scratch by reading the codebase and existing artifacts
- `--mode refresh` — propose updates to the existing map based on recent slug work
- `--mode verify` — check map accuracy against current codebase, update `last_verified` if confirmed

## Instructions

### Phase 0: Determine mode

1. Check if `docs/cortex/system-map.md` exists.
2. If `--mode` argument is provided, use it.
3. If no `--mode` argument:
   - If map does not exist: default to `generate`
   - If map exists: default to `refresh`

### Mode: Generate

Create a new system map from scratch.

**Step 1: Gather context**

Read the following to understand the system:
1. Project CLAUDE.md files (if they exist) for project description
2. `docs/cortex/specs/*/project-context.md` — existing per-slug project context files (seed data)
3. `docs/cortex/specs/*/spec.md` — recent specs for architecture decisions and interfaces
4. `docs/cortex/contracts/*/contract-*.md` — contracts for write roots and deliverables
5. Key source directories — glob for major module directories, read top-level files
6. `docs/cortex/intent/owner-intent.md` — if it exists, for mission and objectives

**Step 2: Build the map**

1. Read `templates/cortex/system-map.md` for the schema.
2. Populate all sections:
   - **System Context (C4 L1):** Identify external actors (user, external APIs, services) and the system boundary. Keep the Mermaid diagram under 15 lines.
   - **Containers (C4 L2):** Identify major structural units (modules, services, data stores, tool layers). Keep the Mermaid diagram under 25 lines.
   - **Component Registry:** One row per major component. Include provenance tag: `[derived]` for facts verifiable from code, `[asserted]` for human-maintained context.
   - **Crosscutting Conventions:** Aggregate from existing `project-context.md` files. Deduplicate across slugs. Keep each entry to one line.
   - **Key Decisions:** Extract from specs' Architecture Decision sections. Include the slug that established each decision.
3. Set frontmatter:
   - `last_verified`: today's date
   - `valid_until`: today + 90 days
   - `confidence`: high
   - `advisory`: true
   - `generated_by`: /cortex-map
   - `slug_coverage`: list of slugs whose artifacts were consulted

**Step 3: Token budget check**

Count approximate tokens: `wc -w` on the proposed map. If over 2250 words (~3K tokens), warn and suggest which sections to compress. If over 3750 words (~5K tokens), block and require compression before writing.

**Step 4: Present for confirmation**

Display the complete proposed map to the user. Ask:
- "Write this system map to docs/cortex/system-map.md?"
- Options: Approve / Edit first / Cancel

If approved, write to `docs/cortex/system-map.md`.
If "Edit first", tell the user to make changes and re-run.
If cancelled, exit without writing.

### Mode: Refresh

Update an existing map based on recent work.

**Step 1: Read current map and recent artifacts**

1. Read `docs/cortex/system-map.md` (current map)
2. Read `.cortex/state.json` for active slug
3. Read recent spec, contract, and research artifacts for the active slug
4. Compare: what components, interfaces, or decisions in the recent work are not reflected in the map?

**Step 2: Propose updates**

Generate a proposed updated map. Show the diff between current and proposed (what's added, changed, or removed). Present to user for confirmation.

**Step 3: Write if confirmed**

Update `docs/cortex/system-map.md` with confirmed changes. Update frontmatter:
- `last_verified`: today
- `valid_until`: today + 90 days
- Append current slug to `slug_coverage` if not already present

### Mode: Verify

Check the existing map against the current codebase without proposing changes.

**Step 1: Read and validate**

1. Read `docs/cortex/system-map.md`
2. For each component in the registry: check if the referenced paths/modules still exist
3. For each container in the C4 L2 diagram: verify the module/service is still present
4. Check if any new major modules exist that aren't in the map

**Step 2: Report**

Output a verification report:
```
SYSTEM MAP VERIFICATION
════════════════════════════════════════
Map: docs/cortex/system-map.md
Last verified: {date}
Age: {N} days

Components verified:
  ✓ {component} — still exists at {path}
  ✗ {component} — path {path} not found

Missing from map:
  - {new module} at {path} — not in component registry

Verdict: {CURRENT | STALE | NEEDS UPDATE}
════════════════════════════════════════
```

**Step 3: Update timestamp if confirmed**

If the user confirms the map is still accurate (verdict: CURRENT), update frontmatter:
- `last_verified`: today
- `valid_until`: today + 90 days

If verdict is STALE or NEEDS UPDATE, suggest running `/cortex-map --mode refresh`.

## Rules

- The map is NEVER written without human confirmation. All three modes present output for review.
- The map is advisory only — it does not create blocking gates or fail commands.
- Token budget: target 3K, hard ceiling 5K. Enforce via word count check before writing.
- The map lives at `docs/cortex/system-map.md` — one per project, not per-slug.
- This skill does not modify any other Cortex artifacts (specs, contracts, state files).

## Output Format

After completing any mode, print:

```
SYSTEM MAP {GENERATED|REFRESHED|VERIFIED}
════════════════════════════════════════
Path:       docs/cortex/system-map.md
Tokens:     ~{N}K ({word_count} words)
Components: {N}
Freshness:  verified {date}, valid until {date}

Next: Map will be injected as pointer in session-start hook.
      Skills (cortex-spec, cortex-review, cortex-research) will
      read it directly when they need system context.
════════════════════════════════════════
```
