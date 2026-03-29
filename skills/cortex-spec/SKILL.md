# Cortex Spec — Intelligence-to-Execution Handoff

Compress the clarify brief and research dossier(s) into a spec, a GSD handoff document, and the first execution contract. Closes the intelligence loop by converting Cortex artifacts into a GSD-ready handoff pack.

## User-invocable

When the user types `/cortex-spec`, run this skill.

Also trigger when the user says:
- "write the spec"
- "create a spec"
- "generate handoff"
- "spec this out"
- "create the contract"

## Arguments

`/cortex-spec` — no flags or arguments; always operates on the current active slug from `.cortex/state.json`.

## Instructions

### Phase 1: Validate Prerequisites

1. Read `.cortex/state.json` to get the active slug.
   - If state.json does not exist or has no active slug: block with "No active slug found. Run /cortex-clarify first."

2. Check `docs/cortex/clarify/{slug}/` for a clarify brief.
   - If no clarify brief exists: block with "No clarify brief found for slug '{slug}'. Run /cortex-clarify first."

3. Check `docs/cortex/research/{slug}/` for at least one research dossier.
   - If no research dossier exists: block with "No research dossier found for slug '{slug}'. Run /cortex-research --phase concept first."

4. Read all available research dossiers for the active slug (all files matching `docs/cortex/research/{slug}/*.md`).

5. Read the clarify brief in full.

### Phase 2: Synthesize Spec

Read the template at `templates/cortex/spec.md`.

Populate ALL 9 mandatory sections — omitting any section is an error:

1. **Problem** — What is being built and why (one paragraph). Describes the problem, not the solution. Answers: what problem does this solve, for whom, and why now?

2. **Scope** — In-scope items (what this spec covers) and explicit out-of-scope exclusions (what is intentionally excluded to prevent scope creep).

3. **Architecture Decision** — The chosen approach, rationale, and alternatives considered and rejected. Format:
   - **Chosen approach:** {description}
   - **Rationale:** {why this over alternatives}
   - **Alternatives Considered:** bulleted list with rejection reason per alternative

4. **Interfaces** — External interfaces touched: APIs, contracts, module boundaries, file paths. Include: what the interface is, who owns it, what this spec reads vs. writes.

5. **Dependencies** — Libraries, services, or other Cortex artifacts this spec depends on. Include name, version if applicable, and what it is used for.

6. **Risks** — List of risks with one mitigation per risk. Format: `- **{Risk}** — Mitigation: {mitigation}`

7. **Sequencing** — Ordered implementation steps, numbered, each producing a verifiable checkpoint or artifact.

8. **Tasks** — Discrete implementation tasks as checkbox items (`- [ ] {task}`), small enough to commit atomically.

9. **Acceptance Criteria** — Measurable, testable criteria with clear pass/fail definitions (`- [ ] {criterion}`). These are the source of truth for the contract's done_criteria.

Write to: `docs/cortex/specs/{slug}/spec.md`
Create directory if it does not exist: `mkdir -p docs/cortex/specs/{slug}/`

### Phase 3: Write GSD Handoff

Read the template at `templates/cortex/gsd-handoff.md`.

Populate from the synthesized spec — this is the GSD-ready work order for explicit human import:

- **Objective** — Distilled from the spec's Problem and Architecture Decision sections. A stateless GSD executor reading only this section must understand what success looks like.
- **Deliverables** — Artifacts to produce, with file paths relative to target repo.
- **Requirements** — Requirement IDs from the project's REQUIREMENTS.md that this work satisfies. If none are formalized, write "None formalized".
- **Tasks** — Ordered implementation tasks with checkboxes, concrete enough that a stateless executor can follow them without guessing.
- **Acceptance Criteria** — Must match the contract's done_criteria exactly.
- **Contract Link** — Relative path to the active contract.

Write to: `docs/cortex/specs/{slug}/gsd-handoff.md`

### Phase 4: Write First Execution Contract

Read the template at `templates/cortex/contract.md`.

Populate all required fields:

- **ID** — Generate as `{slug}-001`
- **Slug** — The active slug
- **Phase** — `execute`
- **Objective** — Single clear statement of what this contract delivers ("Build X so that Y")
- **Deliverables** — From the spec's tasks section, as a list of artifacts with file paths
- **Scope** — In Scope and Out of Scope from the spec
- **Write Roots** — From the spec's Interfaces section; paths the executing agent is allowed to write to
- **Done Criteria** — From the spec's Acceptance Criteria section
- **Validators** — Validation commands or checks to run to confirm done criteria pass
- **Eval Plan** — **Mandatory field.** Include path `docs/cortex/evals/{slug}/eval-plan.md`. If no eval plan exists yet, set to `docs/cortex/evals/{slug}/eval-plan.md` (pending). A contract without this field is incomplete and must not be approved.
- **Approvals** — Both checkboxes unchecked (contract approval and evals approval)
- **Rollback Hints** — Specific file paths to delete, commands to run, state to restore

Contract numbering: `contract-001.md` for first contract. Subsequent repair contracts increment the counter (`contract-002.md`, etc.).

Write to: `docs/cortex/contracts/{slug}/contract-001.md`
Create directory if it does not exist: `mkdir -p docs/cortex/contracts/{slug}/`

### Phase 5: Update Continuity State

**Update `docs/cortex/handoffs/current-state.md`:**
- `mode`: spec
- `approval_status`: pending (spec and contract require human approval before execution)
- `active_contract_path`: `docs/cortex/contracts/{slug}/contract-001.md`
- `recent_artifacts`: append the three new artifact paths (spec.md, gsd-handoff.md, contract-001.md)
- `next_action`: Human must review and approve spec.md and contract-001.md before execution. Import gsd-handoff.md into GSD explicitly — do NOT run GSD commands from this skill.

**Update `.cortex/state.json`:**
- `mode`: spec
- `approval_status`: pending
- `active_contract`: `docs/cortex/contracts/{slug}/contract-001.md`
- Append all three artifact paths to the `artifacts` array
- `gates.spec_complete`: true

## Rules

- **Requires clarify brief AND at least one research dossier.** Blocks with an explicit error message if either is missing. Running without prerequisites is not allowed.
- **This skill does NOT auto-invoke GSD.** Cortex never calls GSD commands. The human must explicitly import `gsd-handoff.md` into GSD as a separate manual step.
- **The spec and contract require human approval before any execution begins.** This is a hard gate — approval_status must be set to `approved` before GSD execution can start.
- **All 9 spec sections are mandatory.** Omitting any section is an error. The executor must verify all 9 are present before writing the file.
- **The `eval_plan` field is mandatory on every contract.** Contracts without it are incomplete and must not advance past spec state.
- **Contract numbering starts at contract-001.md.** Subsequent repair contracts increment the counter. Never overwrite an existing contract.
- **All writes go to the target project repo.** The Cortex framework repo is never modified by command invocations.

## Output Format

```
SPEC WRITTEN
════════════════════════════════════════
Slug:     {slug}
Spec:     docs/cortex/specs/{slug}/spec.md
Handoff:  docs/cortex/specs/{slug}/gsd-handoff.md
Contract: docs/cortex/contracts/{slug}/contract-001.md

Status: PENDING HUMAN APPROVAL

Next steps:
  1. Review docs/cortex/specs/{slug}/spec.md
  2. Review docs/cortex/contracts/{slug}/contract-001.md
  3. Approve both (update Status: draft → approved)
  4. Import gsd-handoff.md into GSD manually
     (do not run GSD commands from this skill)
════════════════════════════════════════
```
