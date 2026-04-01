# Spec: cortex-discovery-loop

<!-- ART-03: Spec Template — produced by /cortex-spec -->

**Slug:** cortex-discovery-loop
**Timestamp:** 20260401T000000Z
**Status:** approved

---

## 1. Problem

Cortex's pre-spec pipeline models intelligence work as a linear sequence (clarify → research → spec), but real discovery does not work that way. Ideas evolve through framing, evidence gathering, re-framing, and bounded experiments before uncertainty is low enough to commit. The current model has no first-class path for hypothesis testing before specification, no formal trigger to return to clarify when research invalidates the original frame, and a `/cortex-spec` readiness gate that can be satisfied by a shallow dossier that defers all critical uncertainties. The result is a commitment boundary that does not meaningfully guard against premature specification — Cortex can produce an execution contract for work that is not yet understood.

---

## 2. Scope

### In Scope

- `docs/DISCOVERY_LOOP.md` — authoritative design reference for the discovery loop
- New `/cortex-experiment` command (8th command) with open/run/close lifecycle
- Two new artifact templates: `templates/cortex/learning-contract.md` and `templates/cortex/experiment-result.md`
- Structured uncertainty register schema for `docs/cortex/handoffs/open-questions.md`
- `state.json` schema extensions: `reclarify_required` flag, `experiment_complete` gate, `mode: experiment`
- Patch `scripts/cortex/scaffold_runtime.sh` to add `experiments` to DOCS_SUBDIRS
- Patch `.claude/hooks/cortex-phase-guard.sh` to permit writes to `docs/cortex/experiments/`
- Updated `/cortex-spec` SKILL.md with 3 new spec-readiness blockers
- Updated `/cortex-research` SKILL.md to set `reclarify_required: true` when evidence changes the frame
- Updated `CORTEX.md`, `docs/INTELLIGENCE_FLOW.md`, `docs/COMMANDS.md` to reflect the discovery loop

### Out of Scope

- Modifying the GSD execution model (post-spec phases stay unchanged)
- Making pre-spec work autonomous — human remains on-loop for approvals and frame revisions
- Adding more than one new top-level command (`/cortex-experiment` only)
- Implementing a general-purpose experimentation or CI platform
- Migrating existing Cortex slugs or artifacts to new schemas
- Changing the execution contract schema — learning contract is a parallel type, not a replacement
- Fixing the phase guard meta-system gap (hot-context/reup writes blocked outside CLAUDE_PROJECT_DIR) — separate issue

---

## 3. Architecture Decision

**Chosen approach:** Introduce `/cortex-experiment` as a dedicated 8th command with an explicit open/run/close lifecycle, two new artifact templates (learning-contract, experiment-result), `reclarify_required` flag propagated to `state.json`, `experiment_complete` gate in `state.json`, evolved uncertainty register in `open-questions.md`, and a tightened `/cortex-spec` readiness gate enforcing three new blockers.

**Rationale:** Experiment has a multi-step lifecycle (open → run → close) that is fundamentally different from the single-pass `--phase` pattern used by `/cortex-research`. Forcing experiment into a `--phase` flag would create a god command that handles both single-pass intelligence work and multi-step experimental lifecycle — a clear violation of single responsibility. Managing write-root permissions at the command level (rather than inferring them from a flag value) is explicit and auditable. The "7-command surface" documented in CORTEX.md is a descriptive constraint, not an architectural limit; the right number of commands is the number that correctly models the distinct operations.

### Alternatives Considered

- **Extend `/cortex-research` with `--phase experiment`** — rejected: lifecycle mismatch (multi-step vs. single-pass); two distinct artifacts (learning-contract + result) don't fit the dossier template; write-root policy would be inferred from flag value, not command — fragile and error-prone; violates single responsibility
- **`reclarify_required` as dossier field only** — rejected: `/cortex-spec` would need to scan all dossiers to find any that set the flag — fragile, order-dependent, and slow
- **Uncertainty register as a separate artifact from `open-questions.md`** — rejected: two files doing related jobs doubles continuity overhead; `/cortex-spec` would need to check two places; flat questions in open-questions.md would have no migration path

---

## 4. Interfaces

- **`.cortex/state.json`** — owned by Cortex framework; this spec reads (slug, mode, gates, artifacts) and writes (adds `reclarify_required`, `experiment_complete` gate, `mode: experiment` as valid value)
- **`docs/cortex/handoffs/open-questions.md`** — owned by Cortex clarify skill; this spec reads current flat schema and writes evolved schema (adds `type`, `severity`, `resolution_path`, `status` fields per entry)
- **`.claude/hooks/cortex-phase-guard.sh`** — owned by Cortex framework hooks; this spec reads and patches (adds `docs/cortex/experiments/` to permitted write root prefixes)
- **`scripts/cortex/scaffold_runtime.sh`** — owned by Cortex framework scripts; this spec reads and patches (adds `experiments` to `DOCS_SUBDIRS`)
- **`skills/cortex-spec/SKILL.md`** — owned by Cortex spec skill; this spec reads and updates (adds 3 new spec-readiness blockers)
- **`skills/cortex-research/SKILL.md`** — owned by Cortex research skill; this spec reads and updates (adds `reclarify_required` write step when evidence changes frame)
- **`CORTEX.md`** — owned by Cortex framework; this spec reads and updates (replaces "7-command surface" with "8-command surface", adds experiment mode)
- **`docs/INTELLIGENCE_FLOW.md`** — owned by Cortex framework docs; this spec reads and updates (replaces linear spine with discovery loop diagram)
- **`docs/COMMANDS.md`** — owned by Cortex framework docs; this spec reads and updates (adds `/cortex-experiment` entry)
- **`templates/cortex/`** — owned by Cortex templates; this spec writes two new files (learning-contract.md, experiment-result.md)
- **`docs/cortex/experiments/{slug}/`** — new write root introduced by this spec; written by `/cortex-experiment` during execution

---

## 5. Dependencies

- **`cortex-clarify` skill** — produces the clarify brief that anchors the discovery loop; must reset `reclarify_required: false` when a new brief is written
- **`cortex-research` skill** — produces dossiers that feed the loop; must be updated to set `reclarify_required: true` when evidence changes the frame
- **`cortex-spec` skill** — is the commitment gate; must be updated to check three new blockers before writing the spec
- **`.cortex/state.json` schema v1** — current schema is the baseline; all new fields are additive (no breaking changes)
- **`docs/cortex/handoffs/open-questions.md`** — current flat stub is the migration baseline; new structured fields are added alongside flat entries

---

## 6. Risks

- **Tightened spec gate blocks valid slugs that skipped experiment** — Mitigation: `experiment_complete` gate is optional; `/cortex-spec` only checks it if the uncertainty register contains critical uncertainties with `resolution_path: experiment`; slugs that resolved all uncertainties via research are unaffected
- **`reclarify_required` left true indefinitely if human forgets to re-clarify** — Mitigation: `/cortex-research` output must print a visible warning when it sets this flag; `/cortex-spec` error message must name the flag explicitly and tell the human to run `/cortex-clarify`
- **Learning contract scope creep** — Mitigation: `appetite` (timebox) is a mandatory field in the learning-contract template; `/cortex-experiment close` must require a recorded decision (promote/iterate/re-clarify/abandon) before it closes
- **Analysis paralysis in the experiment loop** — Mitigation: fixed timebox enforced in learning contract; four explicit decision rule outcomes force closure; `/cortex-experiment` should warn when a slug has more than one active learning contract simultaneously
- **"8-command surface" breaks documented invariants** — Mitigation: update `CORTEX.md` and `docs/COMMANDS.md` in the same commit that introduces the `/cortex-experiment` SKILL.md; document the rationale for the change inline

---

## 7. Sequencing

1. Write `docs/DISCOVERY_LOOP.md` — all subsequent work references this; it is the authoritative design record for mode transitions, artifact schemas, spec-readiness gate, and write-root policy. **Checkpoint:** file exists and covers all 6 required sections.
2. Write `templates/cortex/learning-contract.md` and `templates/cortex/experiment-result.md` — templates must exist before any command skill can reference them. **Checkpoint:** both files exist with correct field schemas.
3. Document uncertainty register schema — define structured fields in `docs/DISCOVERY_LOOP.md` and update `docs/cortex/handoffs/open-questions.md` with field annotations. **Checkpoint:** schema is written and the existing open-questions.md entries remain valid.
4. Extend `.cortex/state.json` schema — add `reclarify_required: false`, `experiment_complete` gate, document `mode: experiment`. **Checkpoint:** schema documentation updated; existing state files remain valid.
5. Patch `scripts/cortex/scaffold_runtime.sh` and `.claude/hooks/cortex-phase-guard.sh` — add `experiments` to DOCS_SUBDIRS and permitted write roots. **Checkpoint:** both files patched; phase guard still blocks product-path writes.
6. Write `skills/cortex-experiment/SKILL.md` — full open/run/close lifecycle. **Checkpoint:** SKILL.md exists; open, run, close actions documented with artifact paths, state writes, and gate logic.
7. Update `skills/cortex-research/SKILL.md` — add `reclarify_required` write step. **Checkpoint:** SKILL.md updated; step is clearly positioned in the research output phase.
8. Update `skills/cortex-spec/SKILL.md` — add 3 new readiness blockers. **Checkpoint:** SKILL.md updated; all three blockers are in the Prerequisites section.
9. Update `CORTEX.md`, `docs/INTELLIGENCE_FLOW.md`, `docs/COMMANDS.md` — replace linear spine with discovery loop; update command count. **Checkpoint:** all three docs consistent with the new model; no remaining references to strictly linear pre-spec flow.

---

## 8. Tasks

- [ ] Write `docs/DISCOVERY_LOOP.md` covering: mode transitions (clarify ↔ research ↔ experiment → spec), artifact schemas (learning-contract, experiment-result), uncertainty register schema (type/severity/resolution_path/status), spec-readiness gate definition, write-root policy for experiment mode, convergence guardrails (timebox, decision rule outcomes, WIP limit)
- [ ] Write `templates/cortex/learning-contract.md` with all 12 HDD/Lean Startup/Shape Up fields: ID+Status+Owner, Problem Statement, Core Hypothesis, Key Assumptions, Target Context, Experiment Design, Key Metrics/Evidence, Learning Threshold, Risks & Dependencies, Appetite/Timebox, Expected Learning, and post-experiment fields (Actual Outcomes, Validated Learning, Decision, Rationale, Next Steps)
- [ ] Write `templates/cortex/experiment-result.md` with fields: Experiment ID, Hypothesis tested, Actual Outcomes, Validated Learning, Decision (promote/iterate/re-clarify/abandon), Rationale, Next Steps
- [ ] Update `docs/cortex/handoffs/open-questions.md` with structured fields per entry: `type: frame|knowledge|design|evidence|eval`, `severity: critical|noncritical`, `resolution_path: research|experiment|human`, `status: open|resolved|deferred|accepted-risk`; add `resolved_by` pointer field; keep flat entries valid with documented defaults
- [ ] Update `.cortex/state.json` schema documentation (or a schema reference in DISCOVERY_LOOP.md) to include `reclarify_required: false` (boolean, top-level), `experiment_complete` gate (boolean, optional), and `mode: experiment` as a valid mode value
- [ ] Patch `scripts/cortex/scaffold_runtime.sh` — add `experiments` to `DOCS_SUBDIRS` array
- [ ] Patch `.claude/hooks/cortex-phase-guard.sh` — add `docs/cortex/experiments/` to the permitted write root prefixes list
- [ ] Write `skills/cortex-experiment/SKILL.md` — open action (creates learning-contract, updates state to mode: experiment), run action (no artifact write, human-driven), close action (writes experiment-result, sets experiment_complete gate, records decision, transitions mode back to research or clarify based on decision)
- [ ] Update `skills/cortex-research/SKILL.md` — add step: when research evidence changes problem frame or invalidates core assumptions, write `reclarify_required: true` to `.cortex/state.json` and surface a visible warning in output
- [ ] Update `skills/cortex-spec/SKILL.md` — add three new blockers to Phase 1 Prerequisites: (1) `reclarify_required` in state.json is false, (2) no entries in the uncertainty register have `severity: critical` and `status: open`, (3) every core assumption in the research dossier is backed by a research finding or experiment result
- [ ] Update `CORTEX.md` — replace "7-command surface" with "8-command surface"; add experiment mode to the layer architecture description; update the pre-spec narrative to reflect the discovery loop
- [ ] Update `docs/INTELLIGENCE_FLOW.md` — replace strictly linear spine (LOOP-04 and surrounding text) with discovery loop diagram annotated with backtracking paths; add note that post-spec repair loop re-enters validate, never clarify
- [ ] Update `docs/COMMANDS.md` — add `/cortex-experiment` entry with description, lifecycle actions, artifact outputs, and state transitions

---

## 9. Acceptance Criteria

- [ ] `docs/DISCOVERY_LOOP.md` exists and covers all 6 required sections: mode transitions, artifact schemas (learning-contract, experiment-result), uncertainty register schema, spec-readiness gate definition, write-root policy for experiment mode, convergence guardrails
- [ ] `templates/cortex/learning-contract.md` exists with all 12 HDD/Lean Startup/Shape Up fields present
- [ ] `templates/cortex/experiment-result.md` exists with outcome, validated learning, decision (promote/iterate/re-clarify/abandon), rationale, and next steps fields
- [ ] `skills/cortex-experiment/SKILL.md` exists and documents open/run/close lifecycle, artifact write paths, state.json write behavior (mode, experiment_complete gate), and explicit decision rule outcomes
- [ ] `skills/cortex-spec/SKILL.md` blocks execution when: `reclarify_required: true` in state.json; any uncertainty register entry has `severity: critical` and `status: open`; core assumptions in dossier lack evidence backing
- [ ] `skills/cortex-research/SKILL.md` sets `reclarify_required: true` in state.json when evidence changes the frame, and surfaces a visible warning in output
- [ ] `scripts/cortex/scaffold_runtime.sh` contains `experiments` in DOCS_SUBDIRS
- [ ] `.claude/hooks/cortex-phase-guard.sh` permits writes to `docs/cortex/experiments/` during experiment mode; product-path write guard remains intact
- [ ] `CORTEX.md` references "8-command surface" and includes `/cortex-experiment` in the command list
- [ ] `docs/INTELLIGENCE_FLOW.md` shows the discovery loop with backtracking paths from research → clarify and experiment → clarify; does not describe the pre-spec spine as strictly linear
- [ ] `docs/COMMANDS.md` contains a `/cortex-experiment` entry with lifecycle actions, artifact paths, and state transitions
- [ ] All existing clarify briefs, research dossiers, specs, and execution contracts in the repo remain valid without modification (backward compatibility verified by inspection of existing artifacts under `docs/cortex/`)
