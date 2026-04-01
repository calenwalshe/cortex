# GSD Handoff: cortex-discovery-loop

<!-- ART-04: GSD Handoff Template — produced by /cortex-spec -->
<!-- This is a GSD-ready work order. The human imports this into GSD explicitly. -->
<!-- Cortex NEVER calls GSD commands — that is always a human step. -->

**Slug:** cortex-discovery-loop
**Timestamp:** 20260401T000000Z
**Status:** draft

---

## Objective

Evolve Cortex from a linear clarify→research→spec pipeline into a discovery loop by introducing a first-class `/cortex-experiment` command, two new artifact templates (learning-contract, experiment-result), a structured uncertainty register, `state.json` schema extensions, phase guard and scaffold patches, and tightened spec-readiness gates — so that pre-spec work can iterate through hypotheses until all critical uncertainties are resolved or explicitly accepted before committing to an execution contract.

---

## Deliverables

- Design doc: `docs/DISCOVERY_LOOP.md`
- Template: `templates/cortex/learning-contract.md`
- Template: `templates/cortex/experiment-result.md`
- Updated schema artifact: `docs/cortex/handoffs/open-questions.md` (uncertainty register schema)
- Script patch: `scripts/cortex/scaffold_runtime.sh`
- Hook patch: `.claude/hooks/cortex-phase-guard.sh`
- New skill: `skills/cortex-experiment/SKILL.md`
- Updated skill: `skills/cortex-research/SKILL.md`
- Updated skill: `skills/cortex-spec/SKILL.md`
- Updated doc: `CORTEX.md`
- Updated doc: `docs/INTELLIGENCE_FLOW.md`
- Updated doc: `docs/COMMANDS.md`

---

## Requirements

- None formalized

---

## Tasks

- [ ] Write `docs/DISCOVERY_LOOP.md` covering: mode transitions (clarify ↔ research ↔ experiment → spec), artifact schemas (learning-contract, experiment-result), uncertainty register schema (type/severity/resolution_path/status), spec-readiness gate definition, write-root policy for experiment mode, convergence guardrails (timebox, decision rule outcomes, WIP limit)
- [ ] Write `templates/cortex/learning-contract.md` with all 12 HDD/Lean Startup/Shape Up fields: ID+Status+Owner, Problem Statement, Core Hypothesis, Key Assumptions, Target Context, Experiment Design, Key Metrics/Evidence, Learning Threshold, Risks & Dependencies, Appetite/Timebox, Expected Learning, and post-experiment fields (Actual Outcomes, Validated Learning, Decision, Rationale, Next Steps)
- [ ] Write `templates/cortex/experiment-result.md` with fields: Experiment ID, Hypothesis tested, Actual Outcomes, Validated Learning, Decision (promote/iterate/re-clarify/abandon), Rationale, Next Steps
- [ ] Update `docs/cortex/handoffs/open-questions.md` with structured fields per entry: `type: frame|knowledge|design|evidence|eval`, `severity: critical|noncritical`, `resolution_path: research|experiment|human`, `status: open|resolved|deferred|accepted-risk`; add `resolved_by` pointer field; keep flat entries valid with documented defaults
- [ ] Update `.cortex/state.json` schema documentation (in DISCOVERY_LOOP.md) to include `reclarify_required: false` (boolean, top-level), `experiment_complete` gate (boolean, optional), and `mode: experiment` as a valid mode value
- [ ] Patch `scripts/cortex/scaffold_runtime.sh` — add `experiments` to `DOCS_SUBDIRS` array
- [ ] Patch `.claude/hooks/cortex-phase-guard.sh` — add `docs/cortex/experiments/` to permitted write root prefixes
- [ ] Write `skills/cortex-experiment/SKILL.md` — open action (creates learning-contract, updates state to mode: experiment), run action (human-driven, no artifact write), close action (writes experiment-result, sets experiment_complete gate, records decision, transitions mode back to research or clarify based on decision)
- [ ] Update `skills/cortex-research/SKILL.md` — add step: when evidence changes problem frame or invalidates core assumptions, write `reclarify_required: true` to `.cortex/state.json` and surface a visible warning in output
- [ ] Update `skills/cortex-spec/SKILL.md` — add three new blockers to Prerequisites: (1) `reclarify_required` is false, (2) no critical uncertainties remain open, (3) core assumptions are evidence-backed
- [ ] Update `CORTEX.md` — replace "7-command surface" with "8-command surface"; add experiment mode; update pre-spec narrative to reflect the discovery loop
- [ ] Update `docs/INTELLIGENCE_FLOW.md` — replace strictly linear spine with discovery loop diagram; annotate backtracking paths; confirm post-spec repair loop re-enters validate, never clarify
- [ ] Update `docs/COMMANDS.md` — add `/cortex-experiment` entry with description, lifecycle actions, artifact outputs, state transitions

---

## Acceptance Criteria

- [ ] `docs/DISCOVERY_LOOP.md` exists and covers all 6 required sections: mode transitions, artifact schemas (learning-contract, experiment-result), uncertainty register schema, spec-readiness gate definition, write-root policy for experiment mode, convergence guardrails
- [ ] `templates/cortex/learning-contract.md` exists with all 12 HDD/Lean Startup/Shape Up fields present
- [ ] `templates/cortex/experiment-result.md` exists with outcome, validated learning, decision (promote/iterate/re-clarify/abandon), rationale, and next steps fields
- [ ] `skills/cortex-experiment/SKILL.md` exists and documents open/run/close lifecycle, artifact write paths, state.json write behavior (mode, experiment_complete gate), and explicit decision rule outcomes
- [ ] `skills/cortex-spec/SKILL.md` blocks execution when: `reclarify_required: true`; any critical uncertainty has status open; core assumptions lack evidence backing
- [ ] `skills/cortex-research/SKILL.md` sets `reclarify_required: true` when evidence changes the frame, with visible warning in output
- [ ] `scripts/cortex/scaffold_runtime.sh` contains `experiments` in DOCS_SUBDIRS
- [ ] `.claude/hooks/cortex-phase-guard.sh` permits writes to `docs/cortex/experiments/`; product-path write guard remains intact
- [ ] `CORTEX.md` references "8-command surface" and includes `/cortex-experiment`
- [ ] `docs/INTELLIGENCE_FLOW.md` shows the discovery loop with backtracking paths; does not describe pre-spec spine as strictly linear
- [ ] `docs/COMMANDS.md` contains a `/cortex-experiment` entry with lifecycle actions, artifact paths, and state transitions
- [ ] All existing clarify briefs, research dossiers, specs, and execution contracts in the repo remain valid without modification

---

## Contract Link

docs/cortex/contracts/cortex-discovery-loop/contract-001.md
