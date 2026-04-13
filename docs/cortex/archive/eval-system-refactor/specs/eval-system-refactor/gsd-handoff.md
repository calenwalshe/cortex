# GSD Handoff: eval-system-refactor

<!-- ART-04: GSD Handoff Template — produced by /cortex-spec -->

**Slug:** eval-system-refactor
**Timestamp:** 20260410T020000Z
**Status:** draft

---

## Objective

Refactor the Cortex eval system to deliver an honest quality signal: eliminate the 68–73% mechanical duplication between eval-proposals and eval-plans via an automated generator; introduce `codex-eval-executor.sh` (a fork of the battle-tested `codex-exec-wrapper.sh`) that runs codex (OpenAI `o4-mini`) as a cross-vendor independent evaluator with no access to the code-writing session's context; wire the pipeline into an explicit `/cortex-eval-run` skill; and lay the foundation for false-positive rate instrumentation — so that every slug that ships has independent verification rather than self-reported results.

---

## Deliverables

- Script: `scripts/cortex/generate-eval-plan.py` — automated proposal→plan transformer
- Test: `test/test_generate_eval_plan.py`
- Template: `templates/cortex/eval-capsule.md` — input spec for codex eval invocations
- Schema: `schemas/eval-result.schema.json` — constrains codex output structure
- Script: `scripts/cortex/generate-eval-capsule.py` — assembles capsule from eval-plan + deliverables
- Test: `test/test_generate_eval_capsule.py`
- Script: `scripts/cortex/codex-eval-executor.sh` — eval-specific codex wrapper (no git merge, read-only)
- Test: `test/test_codex_eval_executor.sh`
- Script: `scripts/cortex/format-eval-results.py` — transforms eval-result JSON → results markdown + eval-status.md
- Test: `test/test_format_eval_results.py`
- Skill: `.claude/skills/cortex-eval-run/SKILL.md` — explicit eval pipeline invocation
- Modified hook: `.claude/hooks/cortex-task-completed.sh` — non-blocking on missing evals
- Modified skill: `.claude/skills/cortex-review/SKILL.md` — eval results scan + repair recommendation
- Modified skill: `.claude/skills/cortex-research/SKILL.md` — Phase 3 overwrite guard
- Stub: `.cortex/eval-ledger.jsonl` — FP rate instrumentation foundation
- Archive: `.claude/agents/archive/cortex-eval-designer.md` — dead code with referencing comment
- Updated: `docs/EVALS.md` — ASPIRATIONAL / IMPLEMENTED annotations

---

## Requirements

- None formalized

---

## Tasks

- [ ] **Phase 1 — Duplication elimination**
- [ ] Write `scripts/cortex/generate-eval-plan.py`: reads eval-proposal.md, filters to approved (non-EXCLUDED) dimensions, copies fixtures/thresholds verbatim, preserves `## Run Instructions`, removes rubrics and failure taxonomy, writes eval-plan.md with correct header fields
- [ ] Write `test/test_generate_eval_plan.py`: ≥5 tests using `kalshi-adaptive-loop` eval-proposal as primary fixture
- [ ] Add overwrite guard to `.claude/skills/cortex-research/SKILL.md` Phase 3: block write if existing proposal has `Approval Status: approved`; allow overwrite on `draft`/`rejected` with logged warning
- [ ] **Phase 2a — Scaffolding**
- [ ] Write `templates/cortex/eval-capsule.md` with 6 required sections: Slug, Approved Dimensions, Fixtures Per Dimension, Thresholds Per Dimension, Rejection Rules (mandatory, ≥3 binary criteria), Deliverable Files
- [ ] Write `schemas/eval-result.schema.json`: `overall_verdict`, `evaluated_dimensions[]` (dimension, verdict, finding, severity, fixtures_tested, failures[{criterion, evidence}]), `deviations[]`, `convergence_risk`
- [ ] Write `scripts/cortex/generate-eval-capsule.py`: reads eval-plan, collects deliverable files (200-line/12KB cap, full test files always included), validates rejection_rules, renders capsule to /tmp
- [ ] Write `test/test_generate_eval_capsule.py`: ≥5 tests covering capsule generation, file cap, rejection-rules validation
- [ ] **Phase 2b — Executor**
- [ ] Write `scripts/cortex/codex-eval-executor.sh`: fork of codex-exec-wrapper.sh; remove merge-on-success; add `--output-schema`; rename events to eval_started/eval_completed/eval_failed; mark divergences with `# EVAL-SPECIFIC:`; write `task_type = "eval"` in ledger
- [ ] Write `test/test_codex_eval_executor.sh`: ≥10 tests — success path, timeout, crash, parse error, budget, no-git-commit assertion, ledger row, JSONL events
- [ ] **Phase 2c — Results processor**
- [ ] Write `scripts/cortex/format-eval-results.py`: transforms eval-result JSON → results-{timestamp}.md matching existing format; updates docs/cortex/handoffs/eval-status.md
- [ ] Write `test/test_format_eval_results.py`: ≥5 tests — markdown format match, eval-status.md update, failed dimension evidence field present
- [ ] **Phase 2d — Wiring**
- [ ] Write `.claude/skills/cortex-eval-run/SKILL.md`: reads contract eval_plan field; invokes generate-capsule → executor → format-results; writes results artifact; logs events
- [ ] Update `.claude/hooks/cortex-task-completed.sh`: if eval-plan referenced but results missing, write "evals pending" to eval-status.md and exit 0
- [ ] Update `.claude/skills/cortex-review/SKILL.md`: add Eval Results Scan section — on FAIL dimension, output repair recommendation with dimension name and evidence
- [ ] Create `.cortex/eval-ledger.jsonl` stub with header comment
- [ ] **Phase 4 — Cleanup**
- [ ] Archive `.claude/agents/cortex-eval-designer.md` → `.claude/agents/archive/cortex-eval-designer.md` with `# ARCHIVED` header comment
- [ ] Annotate `docs/EVALS.md` with `ASPIRATIONAL` / `IMPLEMENTED` markers on repair loop, results, and proposal/plan lifecycle sections

---

## Acceptance Criteria

- [ ] `generate-eval-plan.py` correctly transforms the `kalshi-adaptive-loop` eval-proposal: approved dimensions only, fixtures verbatim, run instructions preserved, rubrics absent, taxonomy absent
- [ ] `test/test_generate_eval_plan.py` passes with ≥5 test cases and 0 failures
- [ ] Running `/cortex-research --phase evals` on a slug with an approved proposal produces an error and does not overwrite the file
- [ ] `eval-capsule.md` template has all 6 required sections
- [ ] `eval-result.schema.json` is valid JSON Schema; validates a conforming object; rejects an object missing `overall_verdict`
- [ ] `generate-eval-capsule.py` raises ValidationError when eval-plan has no `## Rejection Rules`
- [ ] `generate-eval-capsule.py` enforces 200-line / 12KB per-file cap on deliverables
- [ ] `test/test_generate_eval_capsule.py` passes with ≥5 test cases and 0 failures
- [ ] A successful `codex-eval-executor.sh` run does not produce any new git commits
- [ ] `codex-eval-executor.sh` handles timeout, crash, and parse error with correct `fallback_reason`
- [ ] `test/test_codex_eval_executor.sh` passes with ≥10 test cases and 0 failures
- [ ] `format-eval-results.py` output matches `kalshi-adaptive-loop/results-20260407T064500Z.md` format
- [ ] `format-eval-results.py` updates `eval-status.md` with at least one dimension score row
- [ ] `test/test_format_eval_results.py` passes with ≥5 test cases and 0 failures
- [ ] `/cortex-eval-run` reads active contract eval_plan field, invokes the three-script chain, produces `results-{timestamp}.md`
- [ ] `cortex-task-completed.sh` exits 0 and writes "evals pending" when eval-plan referenced but results absent
- [ ] `cortex-review` SKILL outputs repair recommendation paragraph for any FAIL dimension
- [ ] `.cortex/eval-ledger.jsonl` exists
- [ ] `.claude/agents/archive/cortex-eval-designer.md` exists with `# ARCHIVED` header
- [ ] `docs/EVALS.md` contains `ASPIRATIONAL` in repair loop section and `IMPLEMENTED` in results and proposal/plan sections

---

## Contract Link

docs/cortex/contracts/eval-system-refactor/contract-001.md
