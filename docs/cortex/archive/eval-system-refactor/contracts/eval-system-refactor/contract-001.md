# Contract: eval-system-refactor — execute

<!-- ART-05: Contract Template — produced by /cortex-spec -->
<!-- IMPORTANT: A contract without the eval_plan field is incomplete and must not advance past spec state. -->

**ID:** eval-system-refactor-001
**Slug:** eval-system-refactor
**Phase:** execute
**Created:** 20260410T020000Z
**Status:** approved
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Build an independent eval execution pipeline — codex-driven, cross-vendor, read-only — plus an automated proposal→plan generator, so that every slug ships with independently verified results rather than self-reported ones.

---

## Deliverables

- Script: `scripts/cortex/generate-eval-plan.py`
- Test: `test/test_generate_eval_plan.py`
- Template: `templates/cortex/eval-capsule.md`
- Schema: `schemas/eval-result.schema.json`
- Script: `scripts/cortex/generate-eval-capsule.py`
- Test: `test/test_generate_eval_capsule.py`
- Script: `scripts/cortex/codex-eval-executor.sh`
- Test: `test/test_codex_eval_executor.sh`
- Script: `scripts/cortex/format-eval-results.py`
- Test: `test/test_format_eval_results.py`
- Skill: `.claude/skills/cortex-eval-run/SKILL.md`
- Modified: `.claude/hooks/cortex-task-completed.sh`
- Modified: `.claude/skills/cortex-review/SKILL.md`
- Modified: `.claude/skills/cortex-research/SKILL.md`
- Stub: `.cortex/eval-ledger.jsonl`
- Archive: `.claude/agents/archive/cortex-eval-designer.md`
- Updated: `docs/EVALS.md`

---

## Scope

### In Scope

- `generate-eval-plan.py` + tests — automated proposal→plan transformer
- `eval-capsule.md` template and `eval-result.schema.json`
- `generate-eval-capsule.py` + tests — capsule assembler with rejection-rules validation
- `codex-eval-executor.sh` + tests — forked from exec-wrapper, no merge-on-success, eval-specific events
- `format-eval-results.py` + tests — JSON → markdown + eval-status.md updater
- `/cortex-eval-run` SKILL — explicit pipeline invocation
- `cortex-task-completed.sh` update — non-blocking on missing evals
- `cortex-review` SKILL update — eval results scan + repair recommendations
- `cortex-research` SKILL Phase 3 overwrite guard
- `.cortex/eval-ledger.jsonl` stub + `task_type = "eval"` ledger tagging
- Archive `cortex-eval-designer.md`
- `docs/EVALS.md` ASPIRATIONAL / IMPLEMENTED annotations

### Out of Scope

- Backfilling 8 unexecuted eval-plans
- Full repair contract automation
- Collapsing proposal/plan into one artifact
- UX/taste and subjective safety eval execution via codex
- Full FP rate computation, rolling window, alerting
- Hook-based auto-trigger of eval execution
- Changing the 8-dimension candidate matrix
- Modifying contract or spec format beyond eval-related fields

---

## Write Roots

- `scripts/cortex/`
- `test/`
- `templates/cortex/eval-capsule.md`
- `schemas/eval-result.schema.json`
- `.claude/skills/cortex-eval-run/`
- `.claude/skills/cortex-research/SKILL.md`
- `.claude/skills/cortex-review/SKILL.md`
- `.claude/hooks/cortex-task-completed.sh`
- `.claude/agents/archive/`
- `.cortex/eval-ledger.jsonl`
- `docs/EVALS.md`
- `docs/cortex/handoffs/eval-status.md`

---

## Done Criteria

- [ ] `generate-eval-plan.py` correctly transforms the `kalshi-adaptive-loop` eval-proposal: approved dimensions only, fixtures verbatim, run instructions preserved, rubrics absent, failure taxonomy absent
- [ ] `test/test_generate_eval_plan.py` passes with ≥5 test cases and 0 failures
- [ ] Running `/cortex-research --phase evals` on a slug with `Approval Status: approved` produces an error and does not overwrite
- [ ] `eval-capsule.md` template has all 6 required sections: Slug, Approved Dimensions, Fixtures Per Dimension, Thresholds Per Dimension, Rejection Rules, Deliverable Files
- [ ] `eval-result.schema.json` is valid JSON Schema; validates a conforming sample object; rejects an object missing `overall_verdict`
- [ ] `generate-eval-capsule.py` raises non-zero exit when eval-plan has no `## Rejection Rules` section
- [ ] `generate-eval-capsule.py` enforces 200-line / 12KB per-file cap on deliverables
- [ ] `test/test_generate_eval_capsule.py` passes with ≥5 test cases and 0 failures
- [ ] A successful `codex-eval-executor.sh` run does not produce any new git commits (git log unchanged)
- [ ] `codex-eval-executor.sh` exits with correct `fallback_reason` on timeout, crash, and parse error
- [ ] `test/test_codex_eval_executor.sh` passes with ≥10 test cases and 0 failures
- [ ] `format-eval-results.py` output matches `kalshi-adaptive-loop/results-20260407T064500Z.md` format (table structure, section headings, Overall verdict line)
- [ ] `format-eval-results.py` writes at least one dimension score row to `eval-status.md`
- [ ] `test/test_format_eval_results.py` passes with ≥5 test cases and 0 failures
- [ ] `/cortex-eval-run` SKILL reads active contract eval_plan field, invokes generate-capsule → executor → format-results in sequence, produces `results-{timestamp}.md` at `docs/cortex/evals/{slug}/`
- [ ] `cortex-task-completed.sh` exits 0 and writes "evals pending" to eval-status.md when eval-plan is referenced but results absent (not blocking)
- [ ] `cortex-review` SKILL outputs a repair recommendation paragraph naming the dimension and quoting evidence for any FAIL verdict in results
- [ ] `.cortex/eval-ledger.jsonl` exists with header comment
- [ ] `.claude/agents/archive/cortex-eval-designer.md` exists with `# ARCHIVED` header comment referencing this spec
- [ ] `docs/EVALS.md` contains `ASPIRATIONAL` in the repair loop section and `IMPLEMENTED` in the results and proposal/plan lifecycle sections

---

## Validators

- [ ] [external] `python3 -m pytest test/test_generate_eval_plan.py -v`
- [ ] [external] `python3 -m pytest test/test_generate_eval_capsule.py -v`
- [ ] [external] `python3 -m pytest test/test_format_eval_results.py -v`
- [ ] [external] `bash test/test_codex_eval_executor.sh`
- [ ] [external] `python3 -c "import json, jsonschema; s = json.load(open('schemas/eval-result.schema.json')); jsonschema.Draft7Validator.check_schema(s); print('schema OK')"`
- [ ] [external] `test -f .cortex/eval-ledger.jsonl && echo "ledger exists"`
- [ ] [external] `test -f .claude/agents/archive/cortex-eval-designer.md && echo "archive OK"`
- [ ] [external] `grep -q "ASPIRATIONAL" docs/EVALS.md && grep -q "IMPLEMENTED" docs/EVALS.md && echo "annotations OK"`
- [ ] [judgment] `codex-eval-executor.sh` divergences from `codex-exec-wrapper.sh` are documented with `# EVAL-SPECIFIC:` comments and listed in a header note in the executor file

---

## Eval Plan

docs/cortex/evals/eval-system-refactor/eval-plan.md (pending)

---

## Approvals

- [x] Contract approval
- [ ] Evals approval

---

## Completion Promise

<!-- The executing agent MUST emit this signal when all done criteria are satisfied: -->
<!-- CORTEX_PROMISE: eval-system-refactor-001 COMPLETE -->

---

## Failed Approaches

N/A — initial contract

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Delete `scripts/cortex/generate-eval-plan.py`, `generate-eval-capsule.py`, `codex-eval-executor.sh`, `format-eval-results.py`
- Delete `test/test_generate_eval_plan.py`, `test_generate_eval_capsule.py`, `test_codex_eval_executor.sh`, `test_format_eval_results.py`
- Delete `templates/cortex/eval-capsule.md`, `schemas/eval-result.schema.json`
- Delete `.claude/skills/cortex-eval-run/SKILL.md`
- Revert `.claude/skills/cortex-research/SKILL.md` (remove overwrite guard), `.claude/skills/cortex-review/SKILL.md` (remove eval scan section), `.claude/hooks/cortex-task-completed.sh` (restore blocking behaviour) via `git checkout` of those files
- Delete `.cortex/eval-ledger.jsonl`
- Restore `.claude/agents/cortex-eval-designer.md` from `.claude/agents/archive/cortex-eval-designer.md`
- Revert `docs/EVALS.md` annotation pass via `git checkout docs/EVALS.md`

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
