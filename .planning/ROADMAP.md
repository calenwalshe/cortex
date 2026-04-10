# Roadmap: eval-system-refactor

## Overview

Refactor the Cortex eval system to deliver an honest quality signal: eliminate the 68–73% mechanical duplication between eval-proposals and eval-plans via an automated generator; introduce `codex-eval-executor.sh` (a fork of the battle-tested `codex-exec-wrapper.sh`) that runs codex (OpenAI `o4-mini`) as a cross-vendor independent evaluator with no access to the code-writing session's context; wire the pipeline into an explicit `/cortex-eval-run` skill; and lay the foundation for false-positive rate instrumentation — so that every slug that ships has independent verification rather than self-reported results.

## Phases

### Phase 1: Duplication Elimination

**Goal**: Automate the proposal→plan transformation (currently 68–73% mechanical copy) and add an overwrite guard to cortex-research to prevent silent clobber of approved proposals
**Depends on**: Nothing
**Requirements**: N/A
**Success Criteria** (what must be TRUE):
  1. `generate-eval-plan.py` correctly transforms the `kalshi-adaptive-loop` eval-proposal: approved dimensions only, fixtures verbatim, run instructions preserved, rubrics absent, failure taxonomy absent
  2. `test/test_generate_eval_plan.py` passes with ≥5 test cases and 0 failures
  3. Running `/cortex-research --phase evals` on a slug with `Approval Status: approved` produces an error and does not overwrite
**Research**: Unlikely
**Plans**: 0 plans

### Phase 2a: Scaffolding

**Goal**: Build the three structural components that codex-eval-executor needs as inputs: eval-capsule template, eval-result JSON schema, and capsule assembler with rejection-rules validation
**Depends on**: Phase 1: Duplication Elimination
**Requirements**: N/A
**Success Criteria** (what must be TRUE):
  1. `eval-capsule.md` template has all 6 required sections: Slug, Approved Dimensions, Fixtures Per Dimension, Thresholds Per Dimension, Rejection Rules, Deliverable Files
  2. `eval-result.schema.json` is valid JSON Schema; validates a conforming sample object; rejects an object missing `overall_verdict`
  3. `generate-eval-capsule.py` raises non-zero exit when eval-plan has no `## Rejection Rules` section
  4. `generate-eval-capsule.py` enforces 200-line / 12KB per-file cap on deliverables
  5. `test/test_generate_eval_capsule.py` passes with ≥5 test cases and 0 failures
**Research**: Unlikely
**Plans**: 0 plans

### Phase 2b: Executor

**Goal**: Build codex-eval-executor.sh — a fork of codex-exec-wrapper.sh specialised for read-only eval runs: no git merge on success, eval-specific JSONL events, task_type="eval" ledger tagging
**Depends on**: Phase 2a: Scaffolding
**Requirements**: N/A
**Success Criteria** (what must be TRUE):
  1. A successful `codex-eval-executor.sh` run does not produce any new git commits (git log unchanged)
  2. `codex-eval-executor.sh` exits with correct `fallback_reason` on timeout, crash, and parse error
  3. `test/test_codex_eval_executor.sh` passes with ≥10 test cases and 0 failures
**Research**: Unlikely
**Plans**: 0 plans

### Phase 2c: Results Processor

**Goal**: Build format-eval-results.py to transform the eval-result JSON from codex into the existing results-{timestamp}.md format and update eval-status.md composite scoring
**Depends on**: Phase 2b: Executor
**Requirements**: N/A
**Success Criteria** (what must be TRUE):
  1. `format-eval-results.py` output matches `kalshi-adaptive-loop/results-20260407T064500Z.md` format (table structure, section headings, Overall verdict line)
  2. `format-eval-results.py` writes at least one dimension score row to `eval-status.md`
  3. `test/test_format_eval_results.py` passes with ≥5 test cases and 0 failures
**Research**: Unlikely
**Plans**: 0 plans

### Phase 2d: Wiring

**Goal**: Wire the full pipeline into /cortex-eval-run skill, update cortex-task-completed.sh to be non-blocking on missing evals, update cortex-review to scan eval results and emit repair recommendations, and create the eval-ledger stub
**Depends on**: Phase 2c: Results Processor
**Requirements**: N/A
**Success Criteria** (what must be TRUE):
  1. `/cortex-eval-run` SKILL reads active contract eval_plan field, invokes generate-capsule → executor → format-results in sequence, produces `results-{timestamp}.md` at `docs/cortex/evals/{slug}/`
  2. `cortex-task-completed.sh` exits 0 and writes "evals pending" to eval-status.md when eval-plan is referenced but results absent (not blocking)
  3. `cortex-review` SKILL outputs a repair recommendation paragraph naming the dimension and quoting evidence for any FAIL verdict in results
  4. `.cortex/eval-ledger.jsonl` exists with header comment
**Research**: Unlikely
**Plans**: 0 plans

### Phase 4: Cleanup

**Goal**: Archive the dead cortex-eval-designer agent and annotate docs/EVALS.md with ASPIRATIONAL/IMPLEMENTED markers to close the gap between documentation and implementation reality
**Depends on**: Phase 2d: Wiring
**Requirements**: N/A
**Success Criteria** (what must be TRUE):
  1. `.claude/agents/archive/cortex-eval-designer.md` exists with `# ARCHIVED` header comment referencing this spec
  2. `docs/EVALS.md` contains `ASPIRATIONAL` in the repair loop section and `IMPLEMENTED` in the results and proposal/plan lifecycle sections
**Research**: Unlikely
**Plans**: 0 plans

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| Phase 1: Duplication Elimination | 0/0 | Not started | - |
| Phase 2a: Scaffolding | 0/0 | Not started | - |
| Phase 2b: Executor | 0/0 | Not started | - |
| Phase 2c: Results Processor | 0/0 | Not started | - |
| Phase 2d: Wiring | 0/0 | Not started | - |
| Phase 4: Cleanup | 0/0 | Not started | - |
