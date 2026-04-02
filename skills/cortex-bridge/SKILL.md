# Cortex Bridge — GSD Milestone Scaffold Generator

Generates a complete GSD `.planning/` scaffold from Cortex artifacts (spec, contract, gsd-handoff). Eliminates the manual Cortex-to-GSD handoff gap. Reads existing Cortex intelligence output and produces all 6 GSD artifacts needed to begin execution: PROJECT.md, ROADMAP.md, REQUIREMENTS.md, STATE.md, config.json, and phase CONTEXT.md files.

## User-invocable

When the user types `/cortex-bridge`, run this skill.
Also trigger when: "bridge to GSD", "generate GSD scaffold", "import to GSD", "generate planning artifacts", "bridge cortex to gsd".

## Arguments

- `--slug <slug>` — explicit slug override (optional; default: read from `.cortex/state.json` field `slug`)
- `--autonomy <preset>` — override autonomy preset for this invocation only. Valid values: `supervised`, `gates-only`, `full-auto`.
- `--gate <name>=<bool>` — override a specific gate for this invocation. Can be repeated.
- `--dry-run` — print what would be generated without writing any files, creating directories, or committing.

## Instructions

### Phase 1: Resolve inputs

**1.1 Determine slug:**
1. If `--slug` argument provided, use it directly.
2. Else read `.cortex/state.json` → `slug` field.
3. If neither exists, error: "No active slug. Run /cortex-clarify first or pass --slug <slug>."

**1.2 Verify required Cortex artifacts exist.** Error with specific message if any missing:
- `docs/cortex/specs/{slug}/gsd-handoff.md` — required. If missing: "Missing gsd-handoff.md for slug '{slug}'. Run /cortex-spec first."
- `docs/cortex/specs/{slug}/spec.md` — required. If missing: "Missing spec.md for slug '{slug}'. Run /cortex-spec first."
- `docs/cortex/contracts/{slug}/contract-001.md` — required. If missing: "Missing contract-001.md for slug '{slug}'. Run /cortex-review and get contract approval first."

**1.3 Also attempt to read (optional — enhance output if present):**
- `docs/cortex/clarify/{slug}/` — latest clarify brief (most recent file by timestamp)
- `docs/cortex/research/{slug}/` — latest research dossiers

### Phase 2: Parse Cortex artifacts

Extract from each source:

**From `gsd-handoff.md`:**
- `## Objective` — overall objective statement
- `## Deliverables` — list of deliverables
- `## Requirements` — requirement IDs and descriptions (format: `- REQ-ID: description`)
- `## Tasks` — checklist of tasks (grouped into phases if sections present)
- `## Acceptance Criteria` — acceptance checklist

**From `spec.md`:**
- `## 1. Problem` — problem description (first paragraph becomes project description)
- `## 2. Scope` → `### In Scope` — in-scope items and constraints
- `## 2. Scope` → `### Out of Scope` — out-of-scope items
- `## 4. Interfaces` — interface definitions
- `## 5. Dependencies` — dependency list
- `## 6. Risks` — risk items (if present)
- `## 7. Sequencing` — phase sequencing (if present)
- `## 8. Tasks` — task breakdown (if present)

**From `contract-001.md`:**
- `## Done Criteria` — the done criteria checklist. CRITICAL: Each item in this checklist MUST appear verbatim as a success criterion in the corresponding ROADMAP phase (AUTON-06). Do NOT paraphrase, summarize, or rewrite done_criteria text. Copy exact text.
- `## Deliverables` — deliverable list
- `## Scope` — scope constraints
- `## Write Roots` — allowed write paths
- `## Validators` — validation criteria

**From clarify brief (if exists):**
- Goal, Non-goals, Constraints, Assumptions, Open Questions

**From research dossiers (if exist):**
- Summary, Findings, Recommendations, Trade-offs, Decision outcomes

### Phase 3: Generate GSD artifacts

If `.planning/` directory does not exist, create it.

If `.planning/` files already exist (PROJECT.md, ROADMAP.md, etc.), warn the user and ask for confirmation before overwriting — UNLESS `--dry-run` is active.

**3a. Generate `.planning/PROJECT.md`**

```markdown
# {Milestone Name derived from gsd-handoff Objective or slug}

## What This Is

{From spec Section 1 Problem — first paragraph, rewritten as project description}

## Core Value

{From spec Section 1 Problem — the key outcome statement; what changes when this succeeds}

## Requirements

### Active

{For each requirement ID from gsd-handoff Requirements section:}
- [ ] **{REQ-ID}**: {description}

### Out of Scope

{From spec Section 2 Out of Scope items — each as a bullet point}

## Context

{If clarify brief exists: Current baseline, Target, Ownership contract from clarify brief}
{If no clarify brief: "See contract-001.md and spec.md for full context."}

## Constraints

{From spec Section 2 In Scope constraints + contract Scope constraints — each as a bullet}

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
{If research exists: from research Trade-offs, list selected options}
{If no research: | Bridge import | Cortex artifacts imported via /cortex-bridge | {contract path} |}
```

**3b. Generate `.planning/ROADMAP.md`**

```markdown
# Roadmap: {Milestone Name}

## Overview

{From gsd-handoff Objective — verbatim}

## Phases

{Derive phases from gsd-handoff Tasks grouping or spec Section 7 Sequencing.
 If tasks are ungrouped, create a single phase containing all tasks.}

### Phase {N}: {Phase Name}

**Goal**: {Phase goal derived from task group heading or spec sequencing}
**Depends on**: {Previous phase name, or "Nothing" for phase 1}
**Requirements**: {Comma-separated REQ-IDs addressed by this phase}
**Success Criteria** (what must be TRUE):
{For EACH done_criteria item from contract-001.md that maps to this phase:}
  {N}. {EXACT TEXT of the done_criteria item — verbatim, character-for-character}
**Research**: {Likely if phase involves new integrations or unknowns, else Unlikely}
**Plans**: 0 plans

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
{For each phase generated above: | Phase N: Name | 0/0 | Not started | - |}
```

CRITICAL — AUTON-06 compliance: Each done_criteria line from `contract-001.md` `## Done Criteria` section MUST appear verbatim as a numbered success criterion in the corresponding ROADMAP phase. Copy the exact text — do NOT paraphrase, summarize, or rewrite. The verbatim text is the source of truth for what "done" means.

**3c. Generate `.planning/REQUIREMENTS.md`**

```markdown
# Requirements: {Milestone Name}

**Defined:** {today's date YYYY-MM-DD}
**Core Value:** {From PROJECT.md Core Value — same text}

## {Category} Requirements

{Category derived from requirement ID prefix — e.g., AUTON → Autonomy, AUTH → Authentication}

{For each requirement from gsd-handoff Requirements section:}
- [ ] **{REQ-ID}**: {description}

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
{For each REQ-ID: | **{REQ-ID}** | Phase {N}: {Phase Name} | Pending |}

**Coverage:**
- {Category} requirements: {N} total -- all mapped
- Unmapped: 0
```

**3d. Generate `.planning/STATE.md`**

```markdown
---
gsd_state_version: 1.0
milestone: {version from contract Status field or "v1.0"}
milestone_name: {slug}
status: planning
stopped_at: Bridge import complete
last_updated: "{current ISO timestamp}"
last_activity: {today YYYY-MM-DD} — Bridge import from Cortex artifacts
progress:
  total_phases: {N — count of phases in generated ROADMAP}
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated {today YYYY-MM-DD})

**Core value:** {From PROJECT.md Core Value}
**Current focus:** Phase 1 — {first phase name}

## Current Position

Phase: 1 — {first phase name}
Plan: Not started
Status: Ready for planning
Last activity: {today YYYY-MM-DD} — Bridge import complete

Progress: [░░░░░░░░░░░░░░░░░░░░░] 0/0 plans; 0/{N} phases complete

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: -
- Total execution time: 0 hours

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

## Accumulated Context

### Decisions

Bridge import from Cortex contract: docs/cortex/contracts/{slug}/contract-001.md

### Pending Todos

None.

### Blockers/Concerns

None.

## Session Continuity

Last session: {current ISO timestamp}
Stopped at: Bridge import complete
Resume file: None
```

**3e. Generate `.planning/config.json`**

Base config:
```json
{
  "mode": "yolo",
  "granularity": "standard",
  "parallelization": true,
  "commit_docs": true,
  "model_profile": "balanced",
  "workflow": {
    "research": true,
    "plan_check": true,
    "verifier": true,
    "nyquist_validation": true,
    "auto_advance": true
  }
}
```

**Autonomy flag sync:** After generating the base config, sync autonomy flags into `workflow` so GSD reads config.json without needing to read `.cortex/autonomy.json` directly (AUTON-10, Config Sync decision):

1. Read `.cortex/autonomy.json` (project-level) and `~/.claude/cortex-autonomy.json` (global) if they exist.
2. Resolve autonomy config using the 4-layer precedence: invocation flags (`--autonomy`, `--gate`) > project config > global config > preset defaults.
3. If resolved `gates.discuss_phase` is `false`: add `"skip_discuss_cortex": true` to the `workflow` object.
4. This keeps the Cortex→GSD dependency direction clean: GSD reads `.planning/config.json`, not `.cortex/` paths.

**3f. Generate phase CONTEXT.md files**

For each phase in the generated ROADMAP:
1. Create phase directory: `.planning/phases/{NN}-{slug}/` (where `{NN}` is zero-padded phase number, e.g., `01`, `02`)
2. Write `{padded_phase}-CONTEXT.md` into that directory.

When Cortex clarify brief and research dossiers exist:

```markdown
# Phase {N}: {Name} - Context

**Gathered:** {today YYYY-MM-DD}
**Status:** Ready for planning
**Source:** Auto-populated from Cortex artifacts via /cortex-bridge

<domain>
## Phase Boundary

{Phase goal from ROADMAP — what this phase achieves}

</domain>

<decisions>
## Implementation Decisions

{Extract relevant decisions from spec Trade-offs and research Recommendations that apply to this phase}

### Claude's Discretion

{Areas not covered by existing Cortex decisions — implementation details Claude can decide}

</decisions>

<canonical_refs>
## Canonical References

{List the Cortex artifact paths that inform this phase:}
- docs/cortex/specs/{slug}/spec.md
- docs/cortex/specs/{slug}/gsd-handoff.md
- docs/cortex/contracts/{slug}/contract-001.md
{If research exists: - docs/cortex/research/{slug}/{dossier filename}}
{If clarify exists: - docs/cortex/clarify/{slug}/{brief filename}}

</canonical_refs>

<specifics>
## Specific Ideas

{Extract relevant specifics from spec/research that apply to this phase}

</specifics>

<deferred>
## Deferred Ideas

{From spec Section 2 Out of Scope items relevant to this phase}

</deferred>

---

*Phase: {padded_phase}-{slug}*
*Context gathered: {today YYYY-MM-DD} via /cortex-bridge*
```

When clarify/research do NOT exist, generate minimal CONTEXT.md:

```markdown
# Phase {N}: {Name} - Context

**Gathered:** {today YYYY-MM-DD}
**Status:** Ready for planning
**Source:** Auto-populated from Cortex spec and contract via /cortex-bridge

<domain>
## Phase Boundary

{Phase goal from ROADMAP}

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion

No clarify brief or research dossiers found. Implementation decisions are at Claude's discretion.
Key constraints from contract-001.md Write Roots apply.

</decisions>

<canonical_refs>
## Canonical References

- docs/cortex/specs/{slug}/spec.md
- docs/cortex/specs/{slug}/gsd-handoff.md
- docs/cortex/contracts/{slug}/contract-001.md

</canonical_refs>

<specifics>
## Specific Ideas

{Extract relevant specifics from spec that apply to this phase}

</specifics>

<deferred>
## Deferred Ideas

{From spec Section 2 Out of Scope items}

</deferred>

---

*Phase: {padded_phase}-{slug}*
*Context gathered: {today YYYY-MM-DD} via /cortex-bridge*
```

### Phase 4: Commit

After writing all artifacts (skip if `--dry-run`):

```bash
node "$HOME/.claude/get-shit-done/bin/gsd-tools.cjs" commit "docs({slug}): generate GSD scaffold via /cortex-bridge" --files .planning/PROJECT.md .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/STATE.md .planning/config.json .planning/phases/
```

### Phase 5: Summary output

Print a summary table:

```
=== /cortex-bridge complete ===

Slug: {slug}
Source: docs/cortex/contracts/{slug}/contract-001.md

Generated:
  .planning/PROJECT.md        — {line count} lines
  .planning/ROADMAP.md        — {line count} lines, {N} phases
  .planning/REQUIREMENTS.md   — {N} requirements
  .planning/STATE.md          — initial state
  .planning/config.json       — workflow config
  Phase CONTEXT.md files      — {N} phases

Next: Run /gsd:drive or /gsd:plan-phase 1
```

**`--dry-run` behavior:** When `--dry-run` flag is present:
- Print the summary table showing what WOULD be generated (artifact paths, estimated line counts, phase count).
- Do NOT write any files.
- Do NOT create any directories.
- Do NOT run the commit command.
- Print `[DRY RUN] No files written.` at the end.
- Resolve and display the autonomy config that would be applied (slug discovery, gate resolution).

## Error Handling

- Missing required artifact → print specific error naming the missing file and the command needed to generate it. Do not continue.
- `.planning/` files already exist → warn and ask for confirmation before overwriting (unless `--dry-run`).
- No slug found → error: "No active slug. Run /cortex-clarify first or pass --slug <slug>."
- Malformed gsd-handoff.md (missing `## Requirements` section) → warn and generate with empty requirements, noting the gap.
- Malformed contract-001.md (missing `## Done Criteria`) → error: "contract-001.md is missing ## Done Criteria section. Cannot satisfy AUTON-06. Fix contract first."

## AUTON-06 Compliance Note

AUTON-06 requires that done_criteria items from contract-001.md appear as ROADMAP success criteria **exactly as written** — verbatim, character-for-character. This is not a style preference — it is the source of truth for what "done" means for each phase. Any deviation (paraphrase, summary, abbreviation) violates AUTON-06 and invalidates the generated scaffold.

## Autonomy Config Reference

Autonomy is resolved from `.cortex/autonomy.json` (project), `~/.claude/cortex-autonomy.json` (global), and invocation flags. Resolution order (highest to lowest precedence): invocation flags > project config > global config > preset defaults. Mandatory gates (`ux_taste_eval`, `human_action`, `reclarify`) are always forced true regardless of config.

The `discuss_phase` gate controls whether GSD's discuss action re-asks context questions already answered by Cortex artifacts. When `discuss_phase` is `false`, the bridge sets `workflow.skip_discuss_cortex: true` in config.json so GSD skips redundant questioning and generates CONTEXT.md directly from Cortex artifacts.
