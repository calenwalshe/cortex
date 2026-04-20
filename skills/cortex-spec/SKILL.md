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

`/cortex-spec` — operates on the current active slug from `.cortex/state.json`.

- `--autonomy <preset>` — override the autonomy preset for this invocation only. Valid values: `supervised`, `gates-only`, `full-auto`. Passed to the resolver as the invocation layer (highest precedence in the 4-layer resolution).
- `--gate <name>=<bool>` — override a specific gate for this invocation only. Example: `--gate contract_approval=false`. Can be repeated. Passed to the resolver as invocation-layer gate overrides.
- `--dry-run` — print the resolved autonomy gate table without executing any command logic, writing files, or modifying state.

### --dry-run Mode

If `--dry-run` is passed:
1. Resolve autonomy config using `resolveAutonomyWithSources` from `scripts/cortex/resolve-autonomy.js`
2. Print the resolved gate table showing gate name, value, and source layer for all 13 gates
3. Print which gates this specific command checks (cortex-spec checks `reclarify`, `critical_uncertainty`, `evidence_backing`, `necessity`, `contract_approval`)
4. Do NOT execute any command logic, write any files, or modify any state
5. Exit after printing the table

## Instructions

### Phase 1: Validate Prerequisites

**Autonomy config resolution:**
Before evaluating prerequisite gates, resolve the autonomy config once for this invocation:
1. Read `.cortex/autonomy.json` (project-level) and `~/.claude/cortex-autonomy.json` (global-level) if they exist.
2. Determine the active preset (default: `supervised` if no config found).
3. Resolve all gate values using 4-layer precedence. If `--autonomy` or `--gate` flags were provided, use them as the invocation layer (highest precedence in the 4-layer resolution). Resolution order: invocation flags > project config > global config > preset defaults. Mandatory gates (`ux_taste_eval`, `human_action`, `reclarify`) are always forced true regardless of any config.
4. The resolved gate values are used in steps 6, 7, 8, and 9 below, and in Phase 5.

The following gates apply to this skill:
- `reclarify` — **MANDATORY** (always true, cannot be disabled). Controls step 6.
- `critical_uncertainty` — Controls step 7. False in `full-auto` preset.
- `evidence_backing` — Controls step 8. False in `full-auto` preset.
- `necessity` — Controls step 9. False in `full-auto` preset.
- `contract_approval` — Controls Phase 5 approval gate. False in `full-auto` preset.

1. Read `.cortex/state.json` to get the active slug.
   - If state.json does not exist or has no active slug: block with "No active slug found. Run /cortex-clarify first."

2. Check `docs/cortex/clarify/{slug}/` for a clarify brief.
   - If no clarify brief exists: block with "No clarify brief found for slug '{slug}'. Run /cortex-clarify first."

3. Read the `Complexity:` field from the clarify brief.
   - **If `complexity: trivial`:** Skip step 3a (research check). Research is not required for trivial slugs.
     Generate a **thin spec** — include only sections 1 (Problem), 2 (Acceptance Criteria), 3 (Scope), 5 (Interfaces), 8 (Sequencing as single phase), and 9 (Tasks). Omit sections 4 (Architecture Decision), 6 (Dependencies), and 7 (Risks).
   - **If `complexity: standard` or not set:** Full pipeline — enforce research check, generate full spec.
   - **If `complexity: complex`:** Full pipeline with extended validators in the contract.
   Note: If the clarify brief says `trivial` but the problem statement indicates significant unknowns, override to `standard` and note the override.

3a. Check `docs/cortex/research/{slug}/` for at least one research dossier.
   - If no research dossier exists AND complexity is not `trivial`: block with "No research dossier found for slug '{slug}'. Run /cortex-research --phase concept first."

4. Read all available research dossiers for the active slug (all files matching `docs/cortex/research/{slug}/*.md`).

5. Read the clarify brief in full.

6. **Gate: `reclarify` (MANDATORY — always enforced regardless of autonomy preset)**
   Check `.cortex/state.json` for `reclarify_required`.
   - If `reclarify_required: true`, block with:
     ```
     BLOCKED: reclarify_required is true.
     Research evidence has changed the problem frame. Run /cortex-clarify to reframe before speccing.
     ```

7. **Gate: `critical_uncertainty` (autonomy-conditional)**
   If `gates.critical_uncertainty` is `false` (per autonomy resolution above): skip this check — auto-proceed.
   When auto-proceeding (gate is false/skipped), append a decision log entry to `docs/cortex/handoffs/decisions.md` under the `## Autonomy Decisions` section:
   ```
   - {ISO8601 timestamp} | gate: critical_uncertainty | value: false (auto-skipped) | preset: {active_preset} | command: /cortex-spec
   ```
   If `gates.critical_uncertainty` is `true` (or no autonomy config exists): evaluate as follows:
   Read `docs/cortex/handoffs/open-questions.md`. Check for any entries where both `severity: critical` AND `status: open`.
   - If any such entries exist, block with:
     ```
     BLOCKED: [N] critical uncertainties are still open.
     Resolve or explicitly accept-risk each one before speccing.
     ```
   - If the file does not exist or contains only flat/legacy entries (no structured fields), treat all entries as `severity: noncritical` by default (backward-compat default per `docs/DISCOVERY_LOOP.md` §3).

8. **Gate: `evidence_backing` (autonomy-conditional)**
   If `gates.evidence_backing` is `false` (per autonomy resolution above): skip this check — auto-proceed.
   When auto-proceeding (gate is false/skipped), append a decision log entry to `docs/cortex/handoffs/decisions.md` under the `## Autonomy Decisions` section:
   ```
   - {ISO8601 timestamp} | gate: evidence_backing | value: false (auto-skipped) | preset: {active_preset} | command: /cortex-spec
   ```
   If `gates.evidence_backing` is `true` (or no autonomy config exists): evaluate as follows:
   Inspect all research dossiers for the active slug (`docs/cortex/research/{slug}/*.md`). For each core assumption listed in any dossier, verify it is backed by at least one research finding or experiment result within the dossiers.
   - If any assumption has no evidence backing, block with:
     ```
     BLOCKED: [N] core assumption(s) have no evidence backing.
     Run /cortex-research or /cortex-experiment to gather supporting evidence.
     ```

9. **Gate: `necessity` (autonomy-conditional)**
   If `gates.necessity` is `false` (per autonomy resolution above): skip this check — auto-proceed.
   When auto-proceeding (gate is false/skipped), append a decision log entry to `docs/cortex/handoffs/decisions.md` under the `## Autonomy Decisions` section:
   ```
   - {ISO8601 timestamp} | gate: necessity | value: false (auto-skipped) | preset: {active_preset} | command: /cortex-spec
   ```
   If `gates.necessity` is `true` (or no autonomy config exists): evaluate as follows:

   **Necessity Attack:** Read the clarify brief, all research dossiers, and `docs/cortex/intent/owner-intent.md` (if it exists) for the active slug. Construct a necessity check by asking these six diagnostic questions about the proposed work:
   1. Who actually has this problem? Is it the human user, or is the system solving its own problem?
   2. Does the existing system already handle this adequately, even if imperfectly?
   3. Would a human notice if this didn't exist?
   4. Is this a "solution looking for a problem"?
   5. Could the same value be achieved with a simpler approach that doesn't require a new tool?
   6. Does this serve a stated owner objective in `owner-intent.md`? If not, is the problem severe enough to justify work outside the owner's stated priorities?

   Based on the answers, determine one of four verdicts:
   - **BUILD** — Real problem, viable solution, proceed to spec.
   - **NARROW** — Scope is too broad. A smaller version would deliver the same value.
   - **DEFER** — Not enough evidence. More research needed before committing.
   - **REJECT** — This solves a problem that doesn't exist, or the existing system already handles it.

   Each verdict must include a confidence score (0.0–1.0), reasoning (2–3 sentences), and supporting evidence points.

   **Blocking behavior:**
   - **REJECT** with confidence >= 0.7: block with:
     ```
     BLOCKED: Necessity check returned REJECT (confidence: {N}).
     {reasoning}
     Evidence:
     {evidence points}
     Override with --gate necessity=false if you disagree.
     ```
   - **NARROW** with confidence >= 0.7: block with:
     ```
     BLOCKED: Necessity check returned NARROW (confidence: {N}).
     {reasoning}
     Suggestion: Reduce scope before speccing.
     Override with --gate necessity=false if you disagree.
     ```
   - **DEFER**: always block (regardless of confidence):
     ```
     BLOCKED: Necessity check returned DEFER.
     {reasoning}
     Run /cortex-research to gather more evidence before speccing.
     ```
   - **BUILD**: proceed.
   - Any verdict with confidence < 0.7: **warn but do not block**:
     ```
     WARNING: Necessity check returned {verdict} with low confidence ({N}).
     {reasoning}
     Proceeding — review the reasoning above before continuing.
     ```

   Log the verdict to `docs/cortex/handoffs/decisions.md` under `## Autonomy Decisions`:
   ```
   - {ISO8601 timestamp} | gate: necessity | verdict: {BUILD|NARROW|DEFER|REJECT} | confidence: {N} | slug: {slug} | command: /cortex-spec
   ```

See `docs/DISCOVERY_LOOP.md` §4 for full spec-readiness gate semantics.

### Phase 1b: Cross-Artifact Coherence Check

Before synthesizing the spec, verify that the spec will address all goals from the clarify brief.

1. Extract all goals from the clarify brief:
   - The `## Goal` section (primary outcome statement)
   - Each item in the `## Non-Goals` section (to ensure these are NOT accidentally included)
   - Each constraint from `## Constraints`

2. For each goal/constraint, verify it maps to at least one element in the research findings or the spec outline:
   - Goals must map to scope items or acceptance criteria
   - Constraints must map to scope constraints or architecture decisions
   - Non-goals must NOT appear as in-scope items

3. **If any goal is unaddressed:**
   Output a coherence warning:
   ```
   COHERENCE WARNING: {N} clarify-brief goal(s) not addressed in spec:
   - {goal text} — no matching scope item or acceptance criterion
   ```
   This is a warning, not a block. The spec author should either add the missing coverage or note why the goal was intentionally deferred.

4. **If any non-goal appears in scope:**
   Output a coherence error:
   ```
   COHERENCE ERROR: Non-goal included in scope:
   - {non-goal text} — found in In Scope section
   ```
   This IS a block — the spec must not include explicitly excluded items.

### Phase 1c: Read system-map.md (if available)

If `docs/cortex/system-map.md` exists, read the **Component Registry** section before synthesizing the spec. Use the component boundaries and key interfaces to inform write roots (Section 5 Interfaces) and acceptance criteria. Use the Crosscutting Conventions to confirm scope boundaries are consistent with established architectural invariants.

If `docs/cortex/system-map.md` does not exist, skip this step and proceed without error.

### Phase 1d: Read structural graph (if available)

If `.cortex/structural/` exists and contains JSON files, read all entries and inject a compact structural excerpt before synthesizing the spec. The excerpt provides actual function names and import patterns from the Cortex Python codebase, enabling precise write roots (Section 5) and accurate acceptance criteria.

**Steps:**
1. Run reconciliation: for each `.cortex/structural/*.json` entry, verify `source_path` still exists on disk; skip stale entries without error.
2. For each valid entry, produce one compact line: `{basename} ({lines}L): imports=[top-3], fns=[top-5]`
3. Prefix the excerpt with `### Structural Context (auto-indexed):` and include it in your working context before writing the spec.

Soft-fail: if `.cortex/structural/` does not exist or contains no valid entries, log a note ("no structural context available") and proceed without error.

### Phase 1e: Read operational context (if available)

Run the operational indexer to get hotspot and co-change context from the edit ledger:

```bash
python3 "$CLAUDE_PROJECT_DIR/scripts/cortex/operational-indexer.py" --summary 2>/dev/null \
  || echo '{"hotspots":[],"co_change_pairs":[],"caveat":"ledger absent"}'
```

Parse the JSON output. If `hotspots` is non-empty, inject a compact section into your working context before synthesizing the spec:

```
### Operational Context (auto-indexed):
Hotspots (most-edited): {top-3 file_path entries with edit_count}
Co-change pairs (edited together): {top-3 pairs with session_count}
Caveat: {caveat field from JSON}
```

Use hotspot files to inform **Section 5 Interfaces** write roots — frequently edited files are likely in scope. Use co-change pairs to identify coupling risks worth including in **Section 7 Risks**.

Soft-fail: if the command fails, outputs invalid JSON, or `hotspots` is empty, log "no operational context available" and proceed without error. Never block the pipeline on ledger absence.

### Phase 1f: Query vault beliefs for architecture precedents (if available)

Before synthesizing the spec, query the vault belief engine for prior architecture decisions, failed approaches, and stable findings. This informs Section 4 (Architecture Decision) and Section 7 (Risks) with evidence from past work.

```python
try:
    import sys
    sys.path.insert(0, str(Path.home() / "memory/vault/scripts"))
    from cortex_belief_bridge import query_beliefs
    result = query_beliefs(topic="{slug_topic}", slug="{slug}", max_results=15)
    if result["formatted"]:
        print("### Known Beliefs (from vault)")
        print(result["formatted"])
        # Use global stable beliefs to inform acceptance criteria
        # Use contested beliefs to inform risks section
        # Use lessons to inform alternatives considered
except Exception as e:
    print(f"[belief-bridge] vault query soft-fail: {e}")
```

Soft-fail: if vault unavailable, proceed without belief context. Log "no vault beliefs available."

### Phase 2: Synthesize Spec

Read the template at `templates/cortex/spec.md`.

Populate ALL 9 mandatory sections — omitting any section is an error:

Section order: 1=Problem, 2=Acceptance Criteria, 3=Scope, 4=Architecture Decision, 5=Interfaces, 6=Dependencies, 7=Risks, 8=Sequencing, 9=Tasks

1. **Problem** — What is being built and why (one paragraph). Describes the problem, not the solution. Answers: what problem does this solve, for whom, and why now?

2. **Acceptance Criteria** — Measurable, testable criteria with clear pass/fail definitions (`- [ ] {criterion}`). These are the source of truth for the contract's done_criteria. Owner reads §1 + §2 to approve or reject the spec — they should not need to read further to decide.

3. **Scope** — In-scope items (what this spec covers) and explicit out-of-scope exclusions (what is intentionally excluded to prevent scope creep).

4. **Architecture Decision** — The chosen approach, rationale, and alternatives considered and rejected. Format:
   - **Chosen approach:** {description}
   - **Rationale:** {why this over alternatives}
   - **Alternatives Considered:** bulleted list with rejection reason per alternative

5. **Interfaces** — External interfaces touched: APIs, contracts, module boundaries, file paths. Include: what the interface is, who owns it, what this spec reads vs. writes.

6. **Dependencies** — Libraries, services, or other Cortex artifacts this spec depends on. Include name, version if applicable, and what it is used for.

7. **Risks** — List of risks with one mitigation per risk. Format: `- **{Risk}** — Mitigation: {mitigation}`

8. **Sequencing** — Ordered implementation steps, numbered, each producing a verifiable checkpoint or artifact.

9. **Tasks** — Discrete implementation tasks as checkbox items (`- [ ] {task}`), small enough to commit atomically.

Write to: `docs/cortex/specs/{slug}/spec.md`
Create directory if it does not exist: `mkdir -p docs/cortex/specs/{slug}/`

### Phase 2b: Generate Project Context Constitution

After writing the spec, generate a `project-context.md` file that encodes the target project's tech stack, conventions, and rules for executors to reference. This file is auto-generated from spec artifacts — not manually authored.

1. Extract from the spec:
   - Tech stack and dependencies (Section 5)
   - File paths and interfaces (Section 4)
   - Architecture decisions (Section 3)
   - Constraints from the clarify brief

2. Write to `docs/cortex/specs/{slug}/project-context.md`:
   ```markdown
   # Project Context: {slug}

   <!-- Auto-generated by /cortex-spec from spec artifacts. -->
   <!-- All agents reference this file for project-level conventions. -->

   ## Tech Stack
   {dependencies and their roles from spec Section 5}

   ## Conventions
   {coding patterns, file organization, naming from spec Section 4 interfaces}

   ## Architecture Rules
   {chosen approach and constraints from spec Section 3 + clarify brief}

   ## Write Boundaries
   {write roots from the contract, if contract exists at this point}
   ```

3. If a `project-context.md` already exists for this slug, overwrite it (spec is the source of truth).

### Phase 2c: Extract vault facts from spec

After writing spec.md and project-context.md (Phase 2b), call the vault extractor to persist typed facts before invoking critique or proceeding to GSD handoff:

```bash
python3 scripts/cortex/cortex-vault-extractor.py \
  --artifact docs/cortex/specs/{slug}/spec.md \
  --slug {slug}
```

Soft-fail: if the extractor exits non-zero or is not found, log a warning and continue. Do not block Phase 2d or Phase 3.

### Phase 2c.5: L3 belief extraction (inline)

After vault fact extraction (Phase 2c), run the L3 belief engine to extract logical forms from the spec and run inference. This makes architecture decisions, scope constraints, and risk mitigations available as typed beliefs.

```python
try:
    import sys
    sys.path.insert(0, str(Path.home() / "memory/vault/scripts"))
    from cortex_belief_bridge import ingest_and_extract
    result = ingest_and_extract(
        artifact_path="docs/cortex/specs/{slug}/spec.md",
        slug="{slug}"
    )
    if result:
        print(f"[belief-bridge] Extracted {result.get('forms_extracted', 0)} forms from spec")
except Exception as e:
    print(f"[belief-bridge] L3 extraction soft-fail: {e}")
```

Soft-fail: if the bridge or L3 engine is unavailable, log a warning and continue. Do not block Phase 2d or Phase 3.

### Phase 2d: Invoke cortex-critique on spec

After writing spec.md, project-context.md, and extracting vault facts (Phase 2c), invoke cortex-critique on the spec before proceeding to GSD handoff or contract approval gate:

```
/cortex-critique --artifact docs/cortex/specs/{slug}/spec.md --gate spec --slug {slug}
```

This runs adversarial AI review of the spec, persists findings to `docs/cortex/reviews/{slug}/critique-spec.md`, and writes a gate receipt to `.cortex/state.json`.

**Failure handling:** If cortex-critique is not available or returns a non-zero exit, record `CRITIQUE_FAILED` in the gate receipt and proceed. Critique failure must not block the pipeline.

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
- **Repair Budget** — Populate `max_repair_contracts: 3` and `cooldown_between_repairs: 1` (defaults). For contract-001.md, `## Failed Approaches` is empty and `## Why Previous Approach Failed` is "N/A — initial contract".
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

**Gate: `contract_approval` (autonomy-conditional)**
If `gates.contract_approval` is `false` (per autonomy resolution from Phase 1): auto-approve — set `approval_status` to `approved` instead of `pending` in both `current-state.md` and `.cortex/state.json`.
When auto-proceeding (gate is false/skipped), append a decision log entry to `docs/cortex/handoffs/decisions.md` under the `## Autonomy Decisions` section:
```
- {ISO8601 timestamp} | gate: contract_approval | value: false (auto-skipped) | preset: {active_preset} | command: /cortex-spec
```
Update `next_action` to skip the manual approval step.
If `gates.contract_approval` is `true` (or no autonomy config exists): present a gate brief and interactive approval prompt.

**Gate brief (contract_approval):**

Read the contract just written. Extract: contract ID, done criteria count, write roots count, deliverable count. Render the brief using `templates/cortex/gate-brief.md` structure:

```
════════════════════════════════════════
GATE: Contract Approval
════════════════════════════════════════

Would approve contract {contract_id} for execution.
  - {done_criteria_count} done criteria
  - {deliverable_count} deliverables
  - {write_roots_count} write roots

Details: docs/cortex/contracts/{slug}/contract-001.md
════════════════════════════════════════
```

Then present an AskUserQuestion:
- **header:** "Contract"
- **question:** "Approve this contract for execution?"
- **options:**
  - "Approve" — set `approval_status` to `approved` in both state files, proceed normally
  - "Reject" — set `approval_status` to `rejected`, stop execution
  - "Show details" — print the full contract file content, then re-prompt

If "Approve": update state and proceed (same as auto-approve path).
If "Reject": stop. User must address feedback and re-run `/cortex-spec`.

## Rules

- **Requires clarify brief AND at least one research dossier.** Blocks with an explicit error message if either is missing. Running without prerequisites is not allowed.
- **This skill does NOT auto-invoke GSD.** Cortex never calls GSD commands. The human must explicitly import `gsd-handoff.md` into GSD as a separate manual step.
- **The spec and contract require human approval before any execution begins — unless the `contract_approval` autonomy gate is disabled.** When the gate is active, approval_status must be set to `approved` manually before GSD execution can start. When the gate is disabled, the system auto-approves.
- **All 9 spec sections are mandatory.** Omitting any section is an error. The executor must verify all 9 are present before writing the file.
- **The `eval_plan` field is mandatory on every contract.** Contracts without it are incomplete and must not advance past spec state.
- **Contract numbering starts at contract-001.md.** Subsequent repair contracts increment the counter. Never overwrite an existing contract.
- **All writes go to the target project repo.** The Cortex framework repo is never modified by command invocations.

## Output Format

**Follow the HITL report template** at `templates/cortex/hitl-report.md`. Read `docs/cortex/display.json` for `report_level` (default: 1).

**Level 1 (owner) example:**

```
## {slug} — Spec Ready

**What this is:** {One sentence: what will be built and why it matters.}

**What we found:**
- {Scope: what's in, what's explicitly out}
- {Approach: the key architectural choice, in plain language}
- {The necessity gate verdict, if it ran}

**Risks:**
- {Top 1-2 risks from the spec's risk section, in plain language}

**Your decision:** Approve this contract for execution?
════════════════════════════════════════
```

**Level 2+ adds:**
```
Spec:     docs/cortex/specs/{slug}/spec.md
Handoff:  docs/cortex/specs/{slug}/gsd-handoff.md
Contract: docs/cortex/contracts/{slug}/contract-001.md
Done criteria: {count}
Deliverables: {count}
Write roots: {count}
```
