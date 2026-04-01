# Contract: cortex-discovery-loop — execute

<!-- ART-05: Contract Template — produced by /cortex-spec -->
<!-- IMPORTANT: A contract without the eval_plan field is incomplete and must not advance past spec state. -->

**ID:** cortex-discovery-loop-001
**Slug:** cortex-discovery-loop
**Phase:** execute
**Created:** 20260401T000000Z
**Status:** approved

---

## Objective

Build the Cortex discovery loop — introducing `/cortex-experiment`, two new artifact templates, a structured uncertainty register, state schema extensions, phase guard and scaffold patches, and tightened spec-readiness gates — so that pre-spec work can iterate through hypotheses until all critical uncertainties are resolved or explicitly accepted before committing to GSD execution.

---

## Deliverables

- Design doc: `docs/DISCOVERY_LOOP.md`
- Template: `templates/cortex/learning-contract.md`
- Template: `templates/cortex/experiment-result.md`
- Schema update: `docs/cortex/handoffs/open-questions.md` (uncertainty register fields)
- Script patch: `scripts/cortex/scaffold_runtime.sh`
- Hook patch: `.claude/hooks/cortex-phase-guard.sh`
- New skill: `skills/cortex-experiment/SKILL.md`
- Updated skill: `skills/cortex-research/SKILL.md`
- Updated skill: `skills/cortex-spec/SKILL.md`
- Updated doc: `CORTEX.md`
- Updated doc: `docs/INTELLIGENCE_FLOW.md`
- Updated doc: `docs/COMMANDS.md`

---

## Scope

### In Scope

- `docs/DISCOVERY_LOOP.md` design document
- `/cortex-experiment` SKILL.md (8th command, open/run/close lifecycle)
- `templates/cortex/learning-contract.md` and `templates/cortex/experiment-result.md`
- Uncertainty register schema evolution in `docs/cortex/handoffs/open-questions.md`
- `state.json` schema extensions: `reclarify_required`, `experiment_complete` gate, `mode: experiment`
- Phase guard patch: add `docs/cortex/experiments/` to permitted write roots
- Scaffold patch: add `experiments` to DOCS_SUBDIRS
- `/cortex-spec` SKILL.md: 3 new readiness blockers
- `/cortex-research` SKILL.md: `reclarify_required` write step
- `CORTEX.md`, `docs/INTELLIGENCE_FLOW.md`, `docs/COMMANDS.md` updates

### Out of Scope

- GSD execution model (post-spec phases unchanged)
- Autonomous pre-spec work
- Additional new top-level commands beyond `/cortex-experiment`
- General-purpose experimentation or CI platform
- Migration of existing slugs or artifacts to new schemas
- Execution contract schema changes
- Phase guard meta-system gap fix (hot-context/reup outside CLAUDE_PROJECT_DIR)

---

## Write Roots

- `docs/DISCOVERY_LOOP.md`
- `docs/INTELLIGENCE_FLOW.md`
- `docs/COMMANDS.md`
- `docs/cortex/handoffs/open-questions.md`
- `templates/cortex/`
- `scripts/cortex/scaffold_runtime.sh`
- `.claude/hooks/cortex-phase-guard.sh`
- `skills/cortex-experiment/`
- `skills/cortex-research/SKILL.md`
- `skills/cortex-spec/SKILL.md`
- `CORTEX.md`

---

## Done Criteria

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
- [ ] All existing clarify briefs, research dossiers, specs, and execution contracts in the repo remain valid without modification (backward compatibility verified by inspection)

---

## Validators

- [ ] `ls docs/DISCOVERY_LOOP.md templates/cortex/learning-contract.md templates/cortex/experiment-result.md` — all three files exist
- [ ] `ls skills/cortex-experiment/SKILL.md` — experiment skill file exists
- [ ] `grep -n "experiments" scripts/cortex/scaffold_runtime.sh` — DOCS_SUBDIRS contains `experiments`
- [ ] `grep -n "experiments" .claude/hooks/cortex-phase-guard.sh` — permitted roots contains `docs/cortex/experiments/`
- [ ] `grep -n "reclarify_required" skills/cortex-spec/SKILL.md` — spec gate references reclarify_required
- [ ] `grep -n "reclarify_required" skills/cortex-research/SKILL.md` — research skill sets reclarify_required
- [ ] `grep -n "8-command" CORTEX.md` — CORTEX.md references 8-command surface
- [ ] `grep -n "cortex-experiment" docs/COMMANDS.md` — COMMANDS.md includes /cortex-experiment
- [ ] `grep -rn "discovery.loop\|clarify.*research.*experiment\|experiment.*spec" docs/INTELLIGENCE_FLOW.md` — INTELLIGENCE_FLOW.md reflects discovery loop
- [ ] Inspect existing artifacts under `docs/cortex/` — no existing clarify briefs, dossiers, specs, or contracts are modified by this work

---

## Eval Plan

docs/cortex/evals/cortex-discovery-loop/eval-plan.md (pending)

---

## Approvals

- [x] Contract approval
- [ ] Evals approval

---

## Rollback Hints

- Delete `docs/DISCOVERY_LOOP.md` if written
- Delete `templates/cortex/learning-contract.md` and `templates/cortex/experiment-result.md`
- Delete `skills/cortex-experiment/` directory
- Revert `skills/cortex-research/SKILL.md` to remove `reclarify_required` write step
- Revert `skills/cortex-spec/SKILL.md` to remove 3 new readiness blockers
- Revert `scripts/cortex/scaffold_runtime.sh` — remove `experiments` from DOCS_SUBDIRS
- Revert `.claude/hooks/cortex-phase-guard.sh` — remove `docs/cortex/experiments/` from permitted roots
- Revert `CORTEX.md`, `docs/INTELLIGENCE_FLOW.md`, `docs/COMMANDS.md` to pre-discovery-loop versions
- Restore `docs/cortex/handoffs/open-questions.md` to flat stub schema
- All rollbacks are `git checkout <file>` or `git revert <commit>` — no database state to restore
