# Phase 2: Artifact Scaffolding and Templates — Research

**Researched:** 2026-03-28
**Domain:** Directory scaffolding, schema design, markdown template authoring, shell scripting (bash)
**Confidence:** HIGH

---

## Summary

Phase 2 is a pure schema-and-file-creation phase. There are no external libraries to choose, no APIs to integrate, and no dependency decisions to make. The entire deliverable is: a set of directories, README files, template markdown files, a seed JSON state file, and one scaffold shell script. All schemas are fully specified in docs/ (Phase 1 deliverables) — this phase turns prose specs into physical files.

The key architectural distinction that drives every file placement decision: human-readable versionable artifacts go in the **Cortex framework repo** (`templates/cortex/`) and the **target project repo** (`docs/cortex/`, `docs/cortex/handoffs/`); machine runtime scratch state goes in the **target project repo** (`.cortex/`). The scaffold script creates the target-project structure at install time. The framework repo holds the templates that the script copies from.

Phase 2 has one design decision that needs resolution: where inside the Cortex framework repo do the `docs/cortex/` placeholder subdirs and the continuity file templates live? The deliverables description refers to `templates/cortex/` as the template source, but the scaffold script must create the full target-project layout. The planner needs to establish this as a clean separation: `templates/cortex/` in the framework repo is the template source of truth; the script copies these into a target project's `docs/cortex/` and `.cortex/` on first use.

**Primary recommendation:** Implement this phase as three task groups — (1) create framework-repo templates in `templates/cortex/`, (2) create `scripts/cortex/scaffold_runtime.sh`, (3) create the seed `docs/cortex/` placeholder structure and `.cortex/` schema files. All content is defined; the work is writing it down correctly.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| ART-01 | Clarify brief written to `docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md` | Schema fully defined in COMMANDS.md (goal, non-goals, constraints, assumptions, open questions, next research steps) |
| ART-02 | Research dossier written to `docs/cortex/research/<slug>/<phase>-<timestamp>.md` | Output format defined in legacy cortex-research SKILL.md (Intelligence Brief format) with vNext path corrections needed |
| ART-03 | Spec written to `docs/cortex/specs/<slug>/spec.md` with required schema | Nine required fields: problem, scope, arch decision, interfaces, deps, risks, sequencing, tasks, acceptance criteria |
| ART-04 | GSD handoff written to `docs/cortex/specs/<slug>/gsd-handoff.md` | Format: GSD-ready work order; structure should mirror GSD phase/plan conventions |
| ART-05 | Contract written to `docs/cortex/contracts/<slug>/contract-001.md` | Schema fully defined: id, slug, phase, objective, deliverables, scope, write roots, done criteria, validators, approvals, rollback hints — plus eval_plan field (required per EVALS.md) |
| ART-06 | Eval proposal written to `docs/cortex/evals/<slug>/eval-proposal.md` | Schema defined in EVALS.md: dimensions, fixtures, rubrics, thresholds, failure taxonomy, approval_required flag |
| ART-07 | Eval plan written to `docs/cortex/evals/<slug>/eval-plan.md` | Written after human approval; must list evals to run, fixtures, thresholds per dimension |
| ART-08 | Continuity files: current-state.md, open-questions.md, next-prompt.md, decisions.md, eval-status.md, last-compact-summary.md | All schemas fully defined in CONTINUITY.md |
| CONT-04 | `.cortex/state.json` tracks Cortex runtime mode, artifacts, approvals, gates | Full JSON schema defined in CONTINUITY.md; distinct from GSD `.planning/` state |
</phase_requirements>

---

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| bash | system | `scaffold_runtime.sh` — creates dirs, copies templates | Universal; no install dependency |
| markdown | — | All template files | Human-readable, versionable, matches existing Cortex conventions |
| JSON | — | `.cortex/state.json` schema | Machine-parseable; Claude can read/write natively |

### No External Dependencies
This phase installs nothing. No npm, pip, or other package managers needed. All files are markdown templates and one bash script.

---

## Architecture Patterns

### Framework Repo vs Target Project Repo Separation

This is the central structural decision for the phase:

```
cortex/ (FRAMEWORK REPO — this repo)
├── templates/cortex/           # Template source for all artifact types
│   ├── clarify-brief.md        # Template for ART-01
│   ├── research-dossier.md     # Template for ART-02
│   ├── spec.md                 # Template for ART-03
│   ├── gsd-handoff.md          # Template for ART-04
│   ├── contract.md             # Template for ART-05
│   ├── eval-proposal.md        # Template for ART-06
│   ├── eval-plan.md            # Template for ART-07
│   ├── current-state.md        # Continuity template (ART-08)
│   ├── open-questions.md       # Continuity template (ART-08)
│   ├── next-prompt.md          # Continuity template (ART-08)
│   ├── decisions.md            # Continuity template (ART-08)
│   ├── eval-status.md          # Continuity template (ART-08)
│   └── last-compact-summary.md # Continuity template (ART-08)
└── scripts/cortex/
    └── scaffold_runtime.sh     # Creates target-project structure

<target-project-repo>/ (WHERE CORTEX IS USED)
├── docs/cortex/
│   ├── clarify/                # ART-01 writes here at runtime
│   ├── research/               # ART-02 writes here at runtime
│   ├── specs/                  # ART-03, ART-04 write here at runtime
│   ├── contracts/              # ART-05 writes here at runtime
│   ├── evals/                  # ART-06, ART-07 write here at runtime
│   ├── investigations/         # CMD-04 writes here (Phase 3)
│   ├── reviews/                # CMD-05 writes here (Phase 3)
│   ├── audits/                 # CMD-06 writes here (Phase 3)
│   └── handoffs/               # ART-08 continuity files live here
│       ├── current-state.md
│       ├── open-questions.md
│       ├── next-prompt.md
│       ├── decisions.md
│       ├── eval-status.md
│       └── last-compact-summary.md
└── .cortex/                    # CONT-04 machine state
    ├── state.json
    ├── dirty-files.json
    ├── validator-results.json
    ├── runs/
    ├── tmp/
    └── compaction/
```

**Key rule:** The framework repo has templates; the target project repo has live runtime artifacts. The scaffold script bridges the two: it creates the target structure and copies the continuity templates as seed files.

### README Placeholder Pattern

Each `docs/cortex/<subdir>/` needs a `README.md` explaining schema and artifact conventions. These are consumed by commands (Phase 3) and humans resuming work. Content per README:
- Purpose: what artifact type lives here
- Naming convention: `<slug>/` subdirectory + filename pattern
- Required fields: schema for the artifact type
- Example invocation: which command creates it

### Template Field Delimiter Convention

Templates use `{FIELD_NAME}` placeholders with inline comments explaining each field. Example pattern from the spec schema:

```markdown
# Spec: {SLUG}

**Created:** {TIMESTAMP}
**Status:** draft | approved | superseded

## Problem
<!-- What is being built and why. One paragraph. -->
{PROBLEM_STATEMENT}

## Scope
<!-- What is in scope and what is explicitly out of scope. -->
### In Scope
{IN_SCOPE}

### Out of Scope
{OUT_OF_SCOPE}
```

This pattern is consistent with existing Cortex docs style (all phase 1 docs use this convention).

### `.cortex/state.json` Seed Schema

The seed `state.json` must match the schema in `CONTINUITY.md` exactly:

```json
{
  "slug": null,
  "mode": "clarify",
  "approval_status": "pending",
  "active_contract": null,
  "artifacts": [],
  "approvals": {
    "contract": false,
    "evals": false
  },
  "gates": {
    "clarify_complete": false,
    "research_complete": false,
    "spec_complete": false,
    "contract_approved": false
  }
}
```

The seed file has `null` slugs and all gates `false` — it represents a freshly scaffolded project with no active work.

### scaffold_runtime.sh Design

The script takes one argument: the target project root path. It:
1. Creates all `docs/cortex/` subdirectories
2. Creates all `.cortex/` runtime directories
3. Copies continuity template files from `templates/cortex/` into `docs/cortex/handoffs/`
4. Writes the seed `state.json` to `.cortex/`
5. Writes empty seed files for `dirty-files.json` and `validator-results.json`
6. Prints a summary of what was created
7. Is idempotent: re-running on an existing project must not overwrite existing artifacts (use `[ -f ]` guards)

```bash
#!/usr/bin/env bash
# Usage: scaffold_runtime.sh <target-project-root>
# Creates docs/cortex/ and .cortex/ structure in a target project.
set -euo pipefail

TARGET="${1:?Usage: scaffold_runtime.sh <target-project-root>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../../templates/cortex"

# ... mkdir -p calls, file copy with -n guards ...
```

The script path relative to the framework repo: `scripts/cortex/scaffold_runtime.sh`. The `../../templates/cortex` relative path works when the script is called from any CWD as long as it uses `$SCRIPT_DIR`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON validation | Custom validator | Claude reads the schema doc | The JSON schema is simple; validation is Phase 4's job (hooks) |
| Template rendering | A template engine | Bash `cp -n` + sed or Claude writes directly | Over-engineering for what is mostly hardcoded markdown |
| Directory creation idempotency | Complex state tracking | `mkdir -p` + `[ -f ]` guards | Shell builtins handle this trivially |

---

## Common Pitfalls

### Pitfall 1: Template Files in the Wrong Repo
**What goes wrong:** Templates written into `docs/cortex/` of the framework repo (this repo) instead of `templates/cortex/`.
**Why it happens:** The docs/ directory exists in the framework repo for architecture docs. Easy to conflate.
**How to avoid:** Clear rule: `docs/` in framework repo = architecture reference docs (COMMANDS.md, CONTINUITY.md etc). `templates/cortex/` = template source files for target projects.
**Warning signs:** A `clarify-brief.md` file appearing at `cortex/docs/cortex/clarify-brief.md`.

### Pitfall 2: Continuity File Schema Drift
**What goes wrong:** The template `current-state.md` is written with fields that don't match the schema defined in CONTINUITY.md.
**Why it happens:** CONTINUITY.md defines fields as a table; the template is markdown with placeholder text. Easy to miss a field or add an undocumented one.
**How to avoid:** Write the template directly from the CONTINUITY.md schema table — field by field. Then cross-check.
**Warning signs:** Template has a field not in the CONTINUITY.md schema table, or is missing one.

### Pitfall 3: state.json Out of Sync with CONTINUITY.md Schema
**What goes wrong:** The seed `state.json` schema differs from the documented schema (missing fields, wrong field names, wrong default values).
**Why it happens:** CONTINUITY.md shows the runtime schema with sample values; easy to copy values instead of designing the seed state.
**How to avoid:** The seed must have `null` for slug/contract, `false` for all gates/approvals, `"clarify"` for mode (the initial lifecycle state), empty arrays for artifacts.
**Warning signs:** Seed file shows `"mode": "spec"` or has a real slug value.

### Pitfall 4: scaffold_runtime.sh Overwrites Existing Artifacts
**What goes wrong:** Re-running the scaffold script on a project with active work overwrites `current-state.md` and resets `.cortex/state.json`.
**Why it happens:** Naive implementation uses `cp` without an existence check.
**How to avoid:** Every `cp` call uses `cp -n` (no-clobber) or a `[ -f "$dest" ] || cp ...` guard. Script must be explicitly documented as idempotent.
**Warning signs:** Running `scaffold_runtime.sh .` on an active project deletes live state.

### Pitfall 5: Missing `eval_plan` Field in Contract Template
**What goes wrong:** The contract template (ART-05) omits the `eval_plan` field that EVALS.md declares mandatory.
**Why it happens:** The contract schema in REQUIREMENTS.md (ART-05) lists the fields but EVALS.md adds `eval_plan` as a hard requirement in a separate doc.
**How to avoid:** Cross-check contract template against both REQUIREMENTS.md ART-05 AND EVALS.md "Contract Reference Requirement" section.
**Warning signs:** Contract template has no `eval_plan` field.

### Pitfall 6: README Placeholders Are Vague
**What goes wrong:** Subdirectory READMEs say "artifacts live here" without specifying the naming convention or required schema.
**Why it happens:** READMEs feel like throwaway files; effort goes into templates instead.
**How to avoid:** Each README must answer: (1) naming pattern, (2) required fields/schema, (3) which command creates it. Commands in Phase 3 will read these READMEs as their own spec.
**Warning signs:** A README that only says "clarify briefs are stored here."

---

## Code Examples

### Verified: state.json schema from CONTINUITY.md

```json
{
  "slug": "current-active-slug",
  "mode": "spec",
  "approval_status": "pending",
  "active_contract": "docs/cortex/contracts/<slug>/contract-001.md",
  "artifacts": [
    "docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md",
    "docs/cortex/research/<slug>/concept-<timestamp>.md",
    "docs/cortex/specs/<slug>/spec.md"
  ],
  "approvals": {
    "contract": false,
    "evals": false
  },
  "gates": {
    "clarify_complete": true,
    "research_complete": true,
    "spec_complete": true,
    "contract_approved": false
  }
}
```
Source: `/home/agent/projects/cortex/docs/CONTINUITY.md` — `.cortex/state.json Schema` section

### Verified: current-state.md required fields from CONTINUITY.md

| Field | Type | Description |
|-------|------|-------------|
| `slug` | string | Current active slug |
| `mode` | enum | clarify / research / spec / execute / validate / repair / assure / done |
| `approval_status` | enum | pending / approved / rejected |
| `active_contract_path` | string | Relative path to the active contract |
| `recent_artifacts` | array | Artifact paths written in current/most recent session |
| `open_questions` | array | Questions blocking phase transition |
| `blockers` | array | Hard blockers preventing current phase transition |
| `next_action` | string | Single recommended next step |

Source: `/home/agent/projects/cortex/docs/CONTINUITY.md` — `current-state.md Schema` section

### Verified: next-prompt.md template shape from CONTINUITY.md

```
We are working on [slug] in [mode] mode. The last completed action was [what was done].
The next step is [next action]. The active contract is at [active_contract_path].
Run /cortex-status to see the full current state.
```

Source: `/home/agent/projects/cortex/docs/CONTINUITY.md` — `next-prompt.md Format` section

### Verified: contract required fields from REQUIREMENTS.md + EVALS.md

From REQUIREMENTS.md ART-05: id, slug, phase, objective, deliverables, scope, write roots, done criteria, validators, approvals, rollback hints.

From EVALS.md "Contract Reference Requirement": `eval_plan` field pointing to eval plan path is mandatory. Contracts without this field are incomplete.

Combined contract frontmatter/header block:
```markdown
# Contract: {SLUG} — {PHASE}

**ID:** {CONTRACT_ID}
**Slug:** {SLUG}
**Phase:** {PHASE}
**Created:** {TIMESTAMP}
**Status:** draft | approved | closed

## Objective
{OBJECTIVE}

## Deliverables
{DELIVERABLES_LIST}

## Scope
### In Scope
{IN_SCOPE}
### Out of Scope
{OUT_OF_SCOPE}

## Write Roots
{WRITE_ROOTS_LIST}

## Done Criteria
{DONE_CRITERIA_LIST}

## Validators
{VALIDATORS_LIST}

## Eval Plan
{EVAL_PLAN_PATH}
<!-- Required. Must point to docs/cortex/evals/<slug>/eval-plan.md -->

## Approvals
- Contract: [ ] pending
- Evals: [ ] pending

## Rollback Hints
{ROLLBACK_HINTS}
```

---

## File Inventory for This Phase

Complete list of files to create, by destination:

### In the Cortex framework repo (`/home/agent/projects/cortex/`)

**Templates** (`templates/cortex/`):
- `clarify-brief.md` — template for ART-01
- `research-dossier.md` — template for ART-02
- `spec.md` — template for ART-03
- `gsd-handoff.md` — template for ART-04
- `contract.md` — template for ART-05 (includes eval_plan field)
- `eval-proposal.md` — template for ART-06
- `eval-plan.md` — template for ART-07
- `current-state.md` — continuity template (ART-08)
- `open-questions.md` — continuity template (ART-08)
- `next-prompt.md` — continuity template (ART-08)
- `decisions.md` — continuity template (ART-08)
- `eval-status.md` — continuity template (ART-08)
- `last-compact-summary.md` — continuity template (ART-08)

**Scripts** (`scripts/cortex/`):
- `scaffold_runtime.sh` — idempotent scaffold script

### Placeholder structure in the framework repo itself

The framework repo should also contain a `docs/cortex/` placeholder tree so that contributors and the cortex repo itself (when used as a target project) has the scaffold in place:

**Artifact subdirectory READMEs** (`docs/cortex/<subdir>/README.md`):
- `clarify/README.md`
- `research/README.md`
- `specs/README.md`
- `contracts/README.md`
- `evals/README.md`
- `investigations/README.md`
- `reviews/README.md`
- `audits/README.md`
- `handoffs/README.md`

**Continuity seed files** (`docs/cortex/handoffs/`):
- `current-state.md` (seed from template)
- `open-questions.md` (seed from template)
- `next-prompt.md` (seed from template)
- `decisions.md` (seed from template)
- `eval-status.md` (seed from template)
- `last-compact-summary.md` (seed from template)

**Machine state** (`.cortex/`):
- `state.json` (seed with null/false defaults — CONT-04)
- `dirty-files.json` (empty array seed)
- `validator-results.json` (empty object seed)
- `runs/` (empty dir — tracked with `.gitkeep`)
- `tmp/` (empty dir — tracked with `.gitkeep`)
- `compaction/` (empty dir — tracked with `.gitkeep`)

---

## Planning Guidance

### Recommended Wave Structure

**Wave 1 (independent, can parallelize):**
- Create all 13 template files in `templates/cortex/`
- Create all 9 README files for `docs/cortex/<subdir>/`

**Wave 2 (depends on templates):**
- Seed `docs/cortex/handoffs/` continuity files by copying from templates
- Create `.cortex/` seed files (`state.json`, `dirty-files.json`, `validator-results.json`)
- Create empty dirs with `.gitkeep` files

**Wave 3 (depends on all templates and structure being final):**
- Write `scripts/cortex/scaffold_runtime.sh` referencing the established template paths

This ordering avoids a dependency cycle: the script references the templates, so templates must be stable first.

### Scope Boundary

Phase 2 does NOT implement command behavior. The templates are inert markdown files — they define schemas and show field structure, but they do not run. Commands that actually write artifacts from these templates are Phase 3.

Phase 2 does NOT wire hooks. The `.cortex/dirty-files.json` and `.cortex/validator-results.json` files are seeded as empty, but the hooks that populate them are Phase 4.

Phase 2 DOES create the complete substrate so that Phase 3 has concrete paths to write to.

### Validation Approach

Since this phase is file creation only, verification is straightforward:
1. `ls` checks — every expected file exists at its expected path
2. Schema cross-check — each continuity template field matches the CONTINUITY.md schema table
3. Contract template cross-check — eval_plan field present
4. `bash -n scripts/cortex/scaffold_runtime.sh` — syntax check (no external execution needed)
5. Idempotency spot-check — run scaffold against a temp dir twice, verify second run changes nothing

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | bash + manual schema inspection |
| Config file | none |
| Quick run command | `bash -n /home/agent/projects/cortex/scripts/cortex/scaffold_runtime.sh` |
| Full suite command | `bash /home/agent/projects/cortex/scripts/cortex/scaffold_runtime.sh /tmp/cortex-test && ls /tmp/cortex-test/docs/cortex/ && ls /tmp/cortex-test/.cortex/` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ART-01 | clarify-brief.md template has all required fields | manual schema check | `cat templates/cortex/clarify-brief.md` | Wave 1 |
| ART-02 | research-dossier.md template has required sections | manual schema check | `cat templates/cortex/research-dossier.md` | Wave 1 |
| ART-03 | spec.md template has all 9 required fields | manual schema check | `cat templates/cortex/spec.md` | Wave 1 |
| ART-04 | gsd-handoff.md template exists with structure | manual schema check | `cat templates/cortex/gsd-handoff.md` | Wave 1 |
| ART-05 | contract.md template includes eval_plan field | manual schema check | `grep eval_plan templates/cortex/contract.md` | Wave 1 |
| ART-06 | eval-proposal.md template has approval_required field | manual schema check | `grep approval_required templates/cortex/eval-proposal.md` | Wave 1 |
| ART-07 | eval-plan.md template has dimension/threshold structure | manual schema check | `cat templates/cortex/eval-plan.md` | Wave 1 |
| ART-08 | All 6 continuity files exist in docs/cortex/handoffs/ | filesystem check | `ls docs/cortex/handoffs/` | Wave 2 |
| CONT-04 | .cortex/state.json has correct schema with all fields | JSON inspection | `python3 -c "import json,sys; d=json.load(open('.cortex/state.json')); print(list(d.keys()))"` | Wave 2 |

### Wave 0 Gaps
None — this phase requires no test infrastructure setup. All validation is file inspection and bash syntax checking.

---

## Open Questions

1. **Should `.cortex/` be gitignored in target projects?**
   - What we know: `.cortex/` contains both machine runtime scratch (`dirty-files.json`, `runs/`, `tmp/`) and durable state (`state.json`, `compaction/`)
   - What's unclear: Whether `state.json` and `compaction/` snapshots should be committed (for continuity) while `runs/` and `tmp/` are ignored
   - Recommendation: Create a `.cortex/.gitignore` that ignores `runs/`, `tmp/`, and `dirty-files.json`/`validator-results.json` but commits `state.json` and `compaction/`. This matches the pattern of committing durable state and ignoring scratch.

2. **What is the exact schema for `gsd-handoff.md`?**
   - What we know: It is described as a "GSD-ready work order" in COMMANDS.md and CORTEX.md; produced by `/cortex-spec`
   - What's unclear: The specific fields GSD expects — REQUIREMENTS.md ART-04 only says it must exist, not what sections it needs
   - Recommendation: Pattern the gsd-handoff template after GSD's own phase/plan conventions. Minimum viable fields: objective, deliverables, requirements, tasks, acceptance criteria, contract link. This is sufficient for Phase 3 commands to write into.

3. **Should `docs/cortex/` subdirs in the framework repo contain example artifacts?**
   - What we know: The deliverable description says "placeholder READMEs and schema docs"
   - What's unclear: Whether example artifacts (e.g., a sample clarify brief) would aid Phase 3 development
   - Recommendation: Placeholder READMEs only for this phase. Example artifacts can be added in Phase 3 as a natural byproduct of testing the commands.

---

## Sources

### Primary (HIGH confidence)
- `/home/agent/projects/cortex/docs/CONTINUITY.md` — complete state.json schema, current-state.md schema, next-prompt.md format, continuity file inventory
- `/home/agent/projects/cortex/docs/COMMANDS.md` — artifact paths, naming conventions, required fields per artifact type
- `/home/agent/projects/cortex/.planning/REQUIREMENTS.md` — ART-01 through ART-08, CONT-04 field definitions
- `/home/agent/projects/cortex/CORTEX.md` — artifact roots, ownership boundary, framework vs target-project distinction
- `/home/agent/projects/cortex/docs/EVALS.md` — contract eval_plan field requirement, eval artifact paths
- `/home/agent/projects/cortex/docs/AGENTS.md` — write scope per agent (confirms which paths need to exist for Phase 4)
- `/home/agent/projects/cortex/.planning/ROADMAP.md` — phase 2 success criteria and dependency on phase 1

### Secondary (MEDIUM confidence)
- `/home/agent/projects/cortex/skills/cortex-research/SKILL.md` — legacy Intelligence Brief output format; useful as template shape for research-dossier.md
- `/home/agent/projects/cortex/skills/cortex-status/SKILL.md` — legacy implementation; shows what commands currently do vs vNext target

---

## Metadata

**Confidence breakdown:**
- File inventory: HIGH — fully derived from docs that are Phase 1 deliverables (COMMANDS.md, CONTINUITY.md, REQUIREMENTS.md)
- Schema content: HIGH — all schemas explicitly defined in CONTINUITY.md, REQUIREMENTS.md, EVALS.md
- scaffold_runtime.sh design: HIGH — straightforward bash; no external dependencies
- gsd-handoff.md structure: MEDIUM — described as "GSD-ready work order" but exact fields not fully specified; recommendation provided

**Research date:** 2026-03-28
**Valid until:** Stable indefinitely — no external dependencies, all schemas are project-local docs
