# Phase 5: Eval Subsystem — Research

**Researched:** 2026-03-29
**Domain:** Skill-layer eval workflow, approval gates, artifact contracts
**Confidence:** HIGH — all findings derived from direct file inspection of the live codebase

---

## Summary

The eval subsystem infrastructure (templates, artifact paths, field schemas) is substantially complete from Phase 2. What Phase 5 must deliver is behavioral enforcement: the skill protocols that USE that infrastructure correctly. Three categories of work exist:

1. **Skill gap in cortex-research** — `--phase evals` populates the template but the SKILL.md does not explicitly enumerate all 8 dimensions or instruct the skill to address each one. The skill says "populate all fields" but gives no dimension-level checklist, so a naive execution could produce a valid-looking proposal that silently omits dimensions.

2. **No approval-gate enforcement** — `eval-proposal.md` has an `approval_required` field and `approval_status` field. `.cortex/state.json` has an `approvals.evals` boolean. But no skill currently reads `approval_required: true` and blocks further progression. The gate exists as data; there is no skill logic that consults it.

3. **No repair-on-failure artifact** — `docs/EVALS.md` and `CONTINUITY.md` both describe the repair loop (LOOP-02), but neither the cortex-review skill nor any eval-specific skill writes a repair recommendation or repair contract when an eval fails. The repair contract path exists in cortex-investigate, but it is triggered by investigation findings, not by eval results.

EVAL-03 is the lightest lift: the `eval_plan` field is already mandatory in the contract template and cortex-spec SKILL.md enforces it. The gap is that nothing validates _existing_ contracts' `eval_plan` field points to a file that actually exists (vs. "pending"). EVAL-05 is already covered — the 8-dimension matrix is defined in EVALS.md and referenced in the template comments.

**Primary recommendation:** Phase 5 is entirely skill-layer work — updating SKILL.md files and adding one new artifact (repair recommendation). No new templates, no schema changes, no hooks.

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| EVAL-01 | `/cortex-research --phase evals` produces an eval proposal covering all 8 candidate dimensions | cortex-research SKILL.md needs explicit 8-dimension enumeration in the `--phase evals` path |
| EVAL-02 | System explicitly requests human input when eval is subjective, high-stakes, or ambiguous; blocks until answered | `approval_required` field exists in template; SKILL.md needs logic to surface it and block |
| EVAL-03 | Every active contract references a corresponding eval plan path | `eval_plan` field already mandatory; gap is validation that the path is not "pending" at assure time |
| EVAL-04 | Failed eval produces repair recommendation or opens a repair contract | No current skill writes repair-on-failure; needs new skill step in cortex-review or dedicated eval-runner |
| EVAL-05 | Candidate eval matrix covers all 8 dimensions | Matrix defined in EVALS.md and eval-proposal.md template comments; EVAL-01 changes cover this |
</phase_requirements>

---

## Gap Analysis

### EVAL-01: `/cortex-research --phase evals` — 8-dimension proposal

**What exists:**
- `cortex-research/SKILL.md` Phase 3 section for `--phase evals`: creates the directory, reads `eval-proposal.md` template, "populates all fields", writes to path. (Lines 148–163)
- `templates/cortex/eval-proposal.md`: has `{PROPOSED_DIMENSIONS}` placeholder; the template comment lists all 8 dimensions as available candidates. (Lines 18–29)
- `docs/cortex/evals/README.md`: explicitly states "every eval proposal must address all 8 dimensions — either including them with justification or explicitly excluding them with explanation". (Lines 63–65)

**What is missing:**
- The SKILL.md `--phase evals` section does NOT instruct the executor to enumerate all 8 dimensions explicitly. It says "populate all fields" but does not list the 8 dimensions or require each to be addressed with include/exclude rationale.
- Without explicit enumeration in the skill, the executor follows the template comment (which IS correct), but the skill-level contract is weaker than required. A compliant-looking proposal could include only 3 dimensions and the skill would not flag it.

**Fix:** Add an explicit 8-dimension enumeration step to the `--phase evals` path in cortex-research SKILL.md. The step should instruct the executor to address each dimension in order: either include (with `applies_because` and `approval_required`) or explicitly exclude (with reason).

---

### EVAL-02: Human approval gate when `approval_required: true`

**What exists:**
- `eval-proposal.md` template: `approval_required: {APPROVAL_REQUIRED}` and `Approval Status: {APPROVAL_STATUS}` fields. (Lines 95–109)
- `docs/EVALS.md`: "the system blocks progression until the human responds". (Line 24)
- `docs/cortex/evals/README.md`: "the human approval gate between proposal and plan is mandatory". (Line 34)
- `.cortex/state.json` schema: `approvals.evals` boolean.
- cortex-research SKILL.md Phase 4 next_action text (line 172): "If `--phase evals`: `Human must approve eval proposal before /cortex-spec writes eval-plan.md`" — this is hardcoded text in the continuity update, not conditional on `approval_required`.

**What is missing:**
- No skill reads the `approval_required` field from the written proposal and changes behavior based on it.
- No skill or mechanism writes `eval-plan.md` from the approved proposal. The lifecycle says: "After human approval... `eval-plan.md` is written", but there is no `/cortex-eval-plan` command or step in any existing skill that does this.
- "Blocking" in a skill context means: the skill MUST check the proposal's `Approval Status` field before proceeding to write `eval-plan.md`. If `approval_required: true` and `Approval Status: pending`, the skill outputs an explicit human approval request and stops.

**Architecture decision for "blocking":**
- There is no preexisting eval-plan-writing command. The natural home is either (a) a new step in cortex-spec that writes eval-plan.md if the proposal is approved, or (b) a standalone instruction the human follows after approving.
- Given the Cortex pattern (skills are the actors, not hooks), the cleanest solution is: add a `write_eval_plan` step to cortex-research (or a new mini-step section in cortex-spec) that checks `approval_status` in the eval-proposal.md before writing eval-plan.md.
- The human "approval" action is: edit `docs/cortex/evals/{slug}/eval-proposal.md` and change `Approval Status: pending` → `Approval Status: approved`. Then re-invoke the skill (or run a new `/cortex-eval-plan` step). The skill checks this field; if still `pending`, it blocks with an explicit message.

**Fix:** Add a new `--write-plan` sub-path to cortex-research (or a "Phase 5: Write Eval Plan" section), gated on reading `Approval Status` from the proposal. If `approval_required: true` and status is not `approved`, print a blocking message naming the proposal path and the required action.

---

### EVAL-03: Every active contract references an eval plan path

**What exists:**
- `templates/cortex/contract.md`: `## Eval Plan` section with comment "Required. Contract is incomplete without this field." (Lines 83–89)
- `cortex-spec/SKILL.md` Phase 4: "Eval Plan — Mandatory field... If no eval plan exists yet, set to `docs/cortex/evals/{slug}/eval-plan.md` (pending)." (Line 97)
- `docs/cortex/contracts/README.md`: `eval_plan` listed as mandatory, with note "Before the eval plan exists: set `eval_plan` to the expected path and mark it as `pending`". (Lines 64–65)

**What is missing:**
- Nothing validates that the path is not "pending" at the time the contract advances to `assure`. The spec-writing step correctly sets a placeholder; there is no gate that requires the placeholder to be resolved before closure.
- No `/cortex-status` or `/cortex-review` step checks whether active contracts in `docs/cortex/contracts/` have a non-pending `eval_plan` path.

**Fix:** Add a check to cortex-review and/or cortex-status: when reading the active contract, if `eval_plan` is `pending` or the referenced file does not exist, surface this as a blocker in `current-state.md`. This is documentation/skill enforcement, not a new template or schema.

---

### EVAL-04: Repair recommendation on eval failure

**What exists:**
- `docs/EVALS.md` Repair Loop section: "a repair recommendation is written to `docs/cortex/` in the target repo. If the repair is complex or involves significant re-scoping, a new repair contract is opened." (Lines 72–74)
- `templates/cortex/eval-proposal.md`: `{FAILURE_TAXONOMY}` table with `Repair Path` column — this is defined at proposal time but is not evaluated dynamically.
- `docs/CONTINUITY.md` LOOP-02: repair recommendations are written by `/cortex-review` or `/cortex-investigate` when they detect a failing validator. This is skill-layer behavior.
- `cortex-investigate/SKILL.md`: "Optional repair contract — only when investigation determines a repair loop is needed (Status: `DONE_WITH_CONCERNS` or `BLOCKED`)". This is triggered by investigation findings, not eval results.

**What is missing:**
- No current skill writes an eval-failure repair recommendation. The repair loop for validators (LOOP-02) is defined but no skill currently reads `docs/cortex/evals/{slug}/results-<timestamp>.md` and acts on failures.
- There is no `results-<timestamp>.md` write path in any skill. The `eval-plan.md` template has a `## Results` section with checkboxes, but there is no skill step that writes a separate results file.
- The artifact path in `docs/EVALS.md` is `docs/cortex/evals/<slug>/results-<timestamp>.md` — this file is never created by any current skill.

**Architecture decision:**
- Eval execution is either manual (human checks boxes in `eval-plan.md`) or triggered by cortex-validator-trigger (Phase 4 hook, currently pending). For Phase 5, the repair-on-failure path should be skill-layer: when a human reports eval failure (or marks a checkbox as failed in eval-plan.md), cortex-review or a new eval-results step reads the plan's Results section, identifies failures, and writes a repair recommendation.
- The simplest integration: add a "eval failure repair" step to cortex-review's protocol. When cortex-review is run against a contract in `validate` mode, it reads `eval-plan.md`'s Results section. If any dimension is marked `failed`, it:
  1. Writes a repair recommendation to `docs/cortex/evals/{slug}/repair-rec-{timestamp}.md` (or inline in the review artifact)
  2. If the failure is P0 (from the failure taxonomy), opens a repair contract via the same mechanism as cortex-investigate
  3. Updates `docs/cortex/handoffs/eval-status.md` with the failing dimensions

**Fix:** Add an eval-failure handling section to cortex-review SKILL.md. Define the artifact path for repair recommendations. Update eval-status.md template usage to be triggered by this step.

---

### EVAL-05: 8-dimension coverage

**What exists:**
- Full 8-dimension matrix in `docs/EVALS.md` (lines 48–57)
- All 8 dimensions listed in `templates/cortex/eval-proposal.md` template comments (lines 22–29) and `docs/cortex/evals/README.md` (lines 66–76)
- EVALS.md, the template, and the README are mutually consistent — same 8 dimensions, same mandatory conditions

**What is missing:**
- Nothing — EVAL-05 is covered by existing documentation and the EVAL-01 fix (explicit enumeration in the skill) will enforce it behaviorally.

**No changes needed specifically for EVAL-05.** It is satisfied by implementing EVAL-01.

---

## EVAL-01 Implementation: cortex-research SKILL.md changes

**Location:** `/home/agent/projects/cortex/skills/cortex-research/SKILL.md`
**Section:** Phase 3, `If --phase evals` block

**Required addition:** After "Read `templates/cortex/eval-proposal.md`" and before "Populate all fields", insert an explicit dimension enumeration step:

```
Step 2.5: For the `{PROPOSED_DIMENSIONS}` section, address each of the
following 8 dimensions in order. For each dimension, either:
  (a) INCLUDE it: state `applies_because` (why it's relevant to this contract)
      and set `approval_required: true` if subjective or high-stakes
  (b) EXCLUDE it: state `excluded_because` (why it does not apply)

Required dimensions to address (in order):
1. Functional correctness — always include; approval_required: false (mechanical)
2. Regression — include if any existing code is modified
3. Integration — include if multiple components interact
4. Safety/security — include for auth, data handling, input validation, secrets
5. Performance — include if contract specifies latency/throughput thresholds
6. Resilience — include for networked systems or external dependencies
7. Style — include for all code and documentation deliverables
8. UX/taste — include for user-facing output or generated content;
               ALWAYS sets approval_required: true

Set document-level `approval_required: true` if ANY dimension has approval_required: true.
```

---

## EVAL-02 Approval Gate Design

**How "blocking" works in a skill context:**

A skill cannot actually prevent a human from doing something. "Blocking" in Cortex means: the skill explicitly refuses to proceed and outputs a human-readable stop instruction naming what action is required. The contract stays in `spec` state (enforced by skills checking `approval_status` before advancing `state.json`).

**Concrete mechanism:**

Add a new phase to cortex-research SKILL.md (or a new `/cortex-eval-plan` mini-skill):

```
Phase 3b: Write Eval Plan (only after approval)

Prerequisites:
1. Read docs/cortex/evals/{slug}/eval-proposal.md
2. Check the `approval_required` field
3. Check the `Approval Status` field

If approval_required is true AND Approval Status is not "approved":
  OUTPUT:
    BLOCKED: Eval Plan Cannot Be Written
    ════════════════════════════════════════
    The eval proposal at docs/cortex/evals/{slug}/eval-proposal.md
    has approval_required: true but Approval Status: {current_status}.

    Required action:
      1. Review the proposal
      2. Edit the file: change "Approval Status: pending" → "Approval Status: approved"
         (or "rejected" if you want to revise the proposal)
      3. Re-run this command

    The contract will remain in spec state until this approval is recorded.
    ════════════════════════════════════════
  STOP. Do not write eval-plan.md.

If approval_required is false OR Approval Status is "approved":
  Proceed to write eval-plan.md from the approved proposal content.
  Update .cortex/state.json: approvals.evals = true
  Update current-state.md: next_action → "Eval plan written. Contract eval_plan field can be updated."
```

**The human's "approval" action:** Edit `eval-proposal.md`, change `Approval Status: pending` → `Approval Status: approved`. No separate file. No state.json write. The proposal IS the approval record. The skill reads it on re-invocation.

This matches the Cortex pattern: artifacts are the source of truth, not chat.

---

## EVAL-03 Contract Enforcement

**What needs to change:**

1. **cortex-spec SKILL.md** — already correct. No change needed for writing. The spec skill already sets `eval_plan` to the pending path.

2. **cortex-review SKILL.md** — add a contract validation step: when reading the active contract, check if `eval_plan` field is "pending" or the file path does not exist. If so, add to `blockers` in current-state.md:
   ```
   Blocker: contract eval_plan field is "pending" — eval proposal must be
   produced and approved before this contract can advance to assure.
   ```

3. **cortex-status SKILL.md** — same check: scan active contracts for pending eval_plan fields. Surface in the status output.

**No template or schema changes needed.** This is enforcement through skill-layer reading, not schema modification.

---

## EVAL-04 Repair Path — Artifact Design

**New artifact:** `docs/cortex/evals/{slug}/repair-rec-{timestamp}.md`

This is the repair recommendation artifact. It is written when cortex-review detects a failed eval dimension.

**Content schema:**
```
# Eval Repair Recommendation: {SLUG}

**Timestamp:** {TIMESTAMP}
**Contract:** {CONTRACT_PATH}
**Failing Dimensions:** {LIST}

## Failure Summary

| Dimension | Failure | Severity |
|-----------|---------|----------|
| {dim} | {what failed} | P0/P1/P2/P3 |

## Repair Recommendation

{For P0/P1 failures: specific repair action, whether a repair contract is needed}

## Repair Contract

{If repair is complex: path to repair contract, or "See contract-NNN.md"}
{If repair is simple: "In-contract repair — no new contract needed"}
```

**Integration with cortex-review:**

Add to cortex-review SKILL.md after the review report section:

```
Eval Failure Check:
1. If active contract exists, read docs/cortex/evals/{slug}/eval-plan.md
2. Check Results section for any failed checkboxes
3. If failures found:
   a. Write repair-rec-{timestamp}.md to docs/cortex/evals/{slug}/
   b. Update docs/cortex/handoffs/eval-status.md — mark failing dimensions
   c. If any failure is P0: write repair contract to
      docs/cortex/contracts/{slug}/contract-NNN.md (increment from highest existing)
   d. Update .cortex/state.json: mode → repair
   e. Update current-state.md: next_action → repair recommendation path
4. If no failures: update eval-status.md with passing dimensions
```

**Integration with LOOP-02 in CONTINUITY.md:** CONTINUITY.md already documents this pattern for `/cortex-review` (line 210-218). The eval failure repair is the same mechanism — just triggered by reading eval-plan.md's Results section rather than a generic validator list.

---

## EVAL-05 Approval Workflow — State Tracking

**State tracking locations:**

| Location | Field | Meaning |
|----------|-------|---------|
| `docs/cortex/evals/{slug}/eval-proposal.md` | `Approval Status: pending/approved/rejected` | The human-editable approval record |
| `.cortex/state.json` | `approvals.evals: true/false` | Machine-readable gate; set by skill after reading proposal |
| `docs/cortex/handoffs/current-state.md` | `approval_status` field | Human-readable mode indicator |

**What "approved" means:** The human has edited `eval-proposal.md` and set `Approval Status: approved`. No separate approval artifact. No separate command. The proposal file IS the approval record.

**What the skill does after approval is detected:**
1. Reads `Approval Status` from proposal file
2. Writes `eval-plan.md` (the authorized dimensions, fixtures, thresholds, run instructions from the approved proposal)
3. Sets `.cortex/state.json` `approvals.evals = true`
4. Updates `current-state.md` `approval_status: approved`
5. Outputs: "Eval plan written to `docs/cortex/evals/{slug}/eval-plan.md`. Update the contract's eval_plan field."

**Edge case — rejection:** If `Approval Status: rejected`, the skill blocks with: "Eval proposal was rejected. Revise the proposal (re-run `/cortex-research --phase evals`) before writing the plan."

---

## Plan Decomposition

### Plan 1: EVAL-01 and EVAL-05 — Explicit 8-dimension enumeration in cortex-research

**Scope:** Update `skills/cortex-research/SKILL.md` to add explicit 8-dimension enumeration in the `--phase evals` path.

**Tasks:**
- T1: Add dimension enumeration step to Phase 3 `--phase evals` block — list all 8, instruction to include or exclude each with rationale, approval_required conditions
- T2: Add instruction to derive document-level `approval_required` from any-true across dimensions
- T3: Verify template comment alignment — ensure SKILL.md enumeration matches `eval-proposal.md` template comments and `docs/cortex/evals/README.md`

**Validation:** `grep -n "Functional correctness" skills/cortex-research/SKILL.md` — all 8 dimension names appear in the `--phase evals` section.

---

### Plan 2: EVAL-02 and EVAL-05 — Approval gate and eval-plan write step

**Scope:** Add a "Write Eval Plan" phase to cortex-research SKILL.md (or create a new `/cortex-eval-plan` skill section) that gates on `Approval Status` before writing `eval-plan.md`.

**Tasks:**
- T1: Add "Phase 3b: Write Eval Plan" section to cortex-research SKILL.md with the approval check logic
- T2: Define the blocking output format (the human-readable BLOCKED message with required action)
- T3: Define the success path: read approved proposal, populate `eval-plan.md` template from it, write to path
- T4: Update Phase 4 continuity state logic for the eval plan write case: set `approvals.evals = true` in state.json
- T5: Add "If `--phase evals` and plan already written" idempotency guard: check if eval-plan.md exists before writing

**Validation:**
- `grep -n "approval_required" skills/cortex-research/SKILL.md` — appears in the `--phase evals` section with blocking logic
- `grep -n "Approval Status" skills/cortex-research/SKILL.md` — appears with conditional check

---

### Plan 3: EVAL-03 and EVAL-04 — Contract validation and repair-on-failure

**Scope:** Update cortex-review SKILL.md and cortex-status SKILL.md to enforce eval_plan references and handle eval failures. Define the repair-rec artifact.

**Tasks:**
- T1: Add eval_plan validation step to cortex-review — check active contract's eval_plan field; surface as blocker if "pending" or missing file
- T2: Add eval failure check to cortex-review — read eval-plan.md Results section, detect failed checkboxes
- T3: Define repair-rec-{timestamp}.md artifact format inline in cortex-review SKILL.md (no new template file needed for first pass)
- T4: Add repair contract opening logic to cortex-review for P0 failures (mirrors cortex-investigate's optional repair contract step)
- T5: Add eval_plan pending check to cortex-status SKILL.md output — flag in status summary
- T6: Update eval-status.md write logic in cortex-review to reflect failing/passing dimensions after eval check

**Validation:**
- `grep -n "eval_plan" skills/cortex-review/SKILL.md` — appears with "pending" check
- `grep -n "repair-rec" skills/cortex-review/SKILL.md` — repair recommendation artifact path defined
- `grep -n "eval_plan" skills/cortex-status/SKILL.md` — pending eval_plan surfaces as blocker

---

## Architecture Patterns

### Pattern: Skills as the enforcement layer

All Cortex behavioral enforcement is skill-layer. Hooks are fast file-readers that enforce entry/exit conditions (LOOP-01 is hook-based). Skills are intelligent decision-makers that implement loop bodies (LOOP-02 is skill-based). This phase follows the same pattern — no new hooks needed.

### Pattern: Proposal file as approval record

The eval-proposal.md file is both the proposal artifact and the approval record. The human edits it in-place. The skill re-reads it on next invocation. This avoids a separate approval tracking file and keeps the approval auditable in git history.

### Pattern: Repair artifacts co-located with eval artifacts

`docs/cortex/evals/{slug}/repair-rec-{timestamp}.md` sits next to the eval proposal and plan. This keeps all eval-related artifacts in one directory, matching the Cortex convention of co-locating related artifacts under the slug directory.

### Anti-patterns to avoid

- **Creating a separate `/cortex-approve` command** — unnecessary complexity. The human edits the proposal file. The skill reads it. No extra command needed.
- **Adding approval state to state.json before writing the plan** — the proposal file is the source of truth. state.json reflects the result of reading the proposal, not an independent state.
- **Writing a results file separately from the eval plan** — the eval-plan.md template has a Results section. Keep results inline in the plan; only write a separate `repair-rec` file when failures require action.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Approval state machine | Custom state tracking layer | `Approval Status` field in proposal file (already in template) |
| Repair contract numbering | Custom counter | `scan contracts/{slug}/, take highest NNN, increment` — same as cortex-investigate already does |
| Blocking mechanism | Hook-based prevention | Skill reads field, outputs BLOCKED message, stops — same pattern as existing prerequisite checks |

---

## Common Pitfalls

### Pitfall 1: Conflating EVAL-01 and EVAL-05

EVAL-01 is about the skill producing a proposal. EVAL-05 is about the candidate matrix having all 8 dimensions. EVAL-05 is already satisfied by EVALS.md. EVAL-01 is satisfied by the skill explicitly enumerating them during proposal generation. These are one code change (cortex-research SKILL.md), not two.

### Pitfall 2: Treating "blocking" as requiring a hook

Cortex hooks are PreToolUse/PostToolUse/SessionStart/TaskCompleted. An approval gate is not a hook concern — it's a skill prerequisite check, identical to how cortex-spec blocks if no clarify brief exists. The pattern is: read file, check field, output BLOCKED message, return.

### Pitfall 3: Placing eval-plan write in cortex-spec instead of cortex-research

cortex-spec already has its hands full (spec.md + gsd-handoff.md + contract-001.md). The eval lifecycle (proposal → approval → plan) belongs in the research phase. The natural home is a Phase 3b in cortex-research or a `--write-plan` sub-path. cortex-spec's job is to reference the plan path, not write the plan.

### Pitfall 4: Writing repair artifacts to the wrong location

EVALS.md specifies `docs/cortex/evals/<slug>/results-<timestamp>.md` for results. The repair recommendation should be `docs/cortex/evals/<slug>/repair-rec-{timestamp}.md` — not inside `docs/cortex/investigations/` (that's for cortex-investigate bug investigations, not eval failures). Keep eval artifacts in the evals directory.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | File existence + grep assertions (no test runner — skill files are markdown) |
| Config file | none |
| Quick run command | `bash` with grep/test commands per requirement |
| Full suite command | Run all per-requirement checks in sequence |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EVAL-01 | cortex-research SKILL.md enumerates all 8 dimensions in `--phase evals` section | grep | `grep -c "Functional correctness\|Regression\|Integration\|Safety\|Performance\|Resilience\|Style\|UX/taste" /home/agent/projects/cortex/skills/cortex-research/SKILL.md` (expect 8) | ❌ Wave 0 |
| EVAL-02 | cortex-research SKILL.md contains approval gate with BLOCKED output | grep | `grep -l "BLOCKED" /home/agent/projects/cortex/skills/cortex-research/SKILL.md` | ❌ Wave 0 |
| EVAL-02 | cortex-research SKILL.md reads Approval Status field before writing eval-plan.md | grep | `grep -c "Approval Status" /home/agent/projects/cortex/skills/cortex-research/SKILL.md` (expect >= 2) | ❌ Wave 0 |
| EVAL-03 | cortex-review SKILL.md checks eval_plan field for "pending" | grep | `grep -c "eval_plan" /home/agent/projects/cortex/skills/cortex-review/SKILL.md` (expect >= 1) | ❌ Wave 0 |
| EVAL-03 | cortex-status SKILL.md checks eval_plan pending status | grep | `grep -c "eval_plan" /home/agent/projects/cortex/skills/cortex-status/SKILL.md` (expect >= 1) | ❌ Wave 0 |
| EVAL-04 | cortex-review SKILL.md defines repair-rec artifact path | grep | `grep -l "repair-rec" /home/agent/projects/cortex/skills/cortex-review/SKILL.md` | ❌ Wave 0 |
| EVAL-04 | cortex-review SKILL.md reads eval-plan.md Results section | grep | `grep -l "Results" /home/agent/projects/cortex/skills/cortex-review/SKILL.md` | ❌ Wave 0 |
| EVAL-05 | All 8 dimension names present in eval-proposal.md template | grep | `grep -c "Functional correctness\|Regression\|Integration\|Safety\|Performance\|Resilience\|Style\|UX" /home/agent/projects/cortex/templates/cortex/eval-proposal.md` (expect >= 8) | ✅ exists |

### Sampling Rate

- **Per task commit:** Run the grep assertions for the file(s) modified in that task
- **Per wave merge:** Run full suite (all grep assertions above)
- **Phase gate:** All assertions pass before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] EVAL-01 grep test currently fails — skill enumeration not yet added
- [ ] EVAL-02 grep tests currently fail — approval gate not yet in SKILL.md
- [ ] EVAL-03 grep tests currently fail — eval_plan check not yet in cortex-review or cortex-status
- [ ] EVAL-04 grep tests currently fail — repair-rec pattern not yet in cortex-review

Note: `templates/cortex/eval-proposal.md` already contains all 8 dimension names in comments — EVAL-05 grep assertion passes against the template today.

---

## Sources

### Primary (HIGH confidence)

- `/home/agent/projects/cortex/skills/cortex-research/SKILL.md` — Phase 3 `--phase evals` path inspected directly
- `/home/agent/projects/cortex/templates/cortex/eval-proposal.md` — template fields and dimension list inspected
- `/home/agent/projects/cortex/templates/cortex/eval-plan.md` — Results section structure inspected
- `/home/agent/projects/cortex/templates/cortex/contract.md` — eval_plan field and mandatory comment inspected
- `/home/agent/projects/cortex/docs/EVALS.md` — 8-dimension matrix, lifecycle, repair loop inspected
- `/home/agent/projects/cortex/docs/cortex/evals/README.md` — all-8-dimensions requirement inspected
- `/home/agent/projects/cortex/docs/CONTINUITY.md` — LOOP-02 skill-layer pattern inspected
- `/home/agent/projects/cortex/skills/cortex-spec/SKILL.md` — eval_plan mandatory enforcement inspected
- `/home/agent/projects/cortex/skills/cortex-investigate/SKILL.md` — repair contract pattern inspected
- `/home/agent/projects/cortex/.cortex/state.json` — approvals.evals field inspected
- `/home/agent/projects/cortex/.planning/REQUIREMENTS.md` — EVAL-01 through EVAL-05 full text

### Secondary (MEDIUM confidence)

- None — all findings from direct file inspection

### Tertiary (LOW confidence)

- None

---

## Metadata

**Confidence breakdown:**
- Gap analysis: HIGH — derived from direct comparison of SKILL.md content vs. EVALS.md spec
- Architecture patterns: HIGH — follows existing Cortex patterns documented in CONTINUITY.md and skill files
- Plan decomposition: HIGH — 3 plans map cleanly to the 5 requirements with no overlap

**Research date:** 2026-03-29
**Valid until:** 2026-04-28 (skill files are stable; no external dependencies)
