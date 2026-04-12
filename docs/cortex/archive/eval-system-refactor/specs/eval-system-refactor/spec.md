# Spec: eval-system-refactor

<!-- ART-03: Spec Template — produced by /cortex-spec -->

**Slug:** eval-system-refactor
**Timestamp:** 20260410T020000Z
**Status:** draft

---

## 1. Problem

The Cortex eval system is architecturally complete on paper but operationally hollow. Of 10 slugs with eval artifacts, only 2 have executed results — both written in the same session as the implementation code, directly violating owner-intent's "no sycophantic evals" non-negotiable. The `cortex-eval-designer` agent is defined but never invoked (the research SKILL bypasses it). The proposal→plan transform is 68–73% mechanical duplication with no automation. The repair loop, `eval-status.md` composite scoring, and the `<10%` false-positive kill criterion described in `docs/EVALS.md` have zero backing code. For the owner's "honest quality signal" objective to be achievable, the eval system needs: an independent execution path (codex as cross-vendor evaluator), automated duplication elimination, and instrumentation foundations for the FP rate requirement.

---

## 2. Scope

### In Scope

- `scripts/cortex/generate-eval-plan.py` — automated proposal→plan transformer (eliminates 68–73% duplication)
- Overwrite guard in `.claude/skills/cortex-research/SKILL.md` Phase 3 (prevents silent clobber of approved proposals)
- `templates/cortex/eval-capsule.md` — input template for codex eval invocations
- `schemas/eval-result.schema.json` — JSON Schema constraining codex output
- `scripts/cortex/generate-eval-capsule.py` — assembles capsule from eval-plan + deliverable files
- `scripts/cortex/codex-eval-executor.sh` — fork of `codex-exec-wrapper.sh`, eval-specific (no git merge, read-only)
- `scripts/cortex/format-eval-results.py` — transforms eval-result JSON → `results-{timestamp}.md` + updates `eval-status.md`
- `.claude/skills/cortex-eval-run/SKILL.md` — explicit skill wiring the three-script eval pipeline
- `.claude/hooks/cortex-task-completed.sh` update — non-blocking on missing evals ("evals pending" status, no exit-1)
- `.claude/skills/cortex-review/SKILL.md` update — scan eval results → auto-generate repair recommendation per failed dimension
- `.cortex/eval-ledger.jsonl` stub — FP rate instrumentation foundation
- Ledger tagging: `task_type = "eval"` in codex-eval-executor.sh SQLite write
- Archive `cortex-eval-designer.md` to `.claude/agents/archive/` (dead code cleanup)
- Annotation pass on `docs/EVALS.md` marking aspirational vs implemented sections

### Out of Scope

- Backfilling the 8 unexecuted eval-plans (scheduled separately)
- Full repair contract automation (cortex-review scan is sufficient for now)
- Collapsing eval-proposal.md and eval-plan.md into one artifact (approval gate is load-bearing — owner confirmed not auto-approving post-research)
- UX/taste and subjective safety eval execution via codex (stays as markdown with human approval gate)
- Full FP rate computation, rolling window, and alerting (ledger stub only; computation is next slug)
- Hook-based auto-trigger of eval execution (explicit `/cortex-eval-run` first; auto-trigger after ≥5 successful slugs)
- Changing the 8-dimension candidate matrix
- Changing contract or spec format beyond eval-related fields

---

## 3. Architecture Decision

**Chosen approach:** Fork `codex-exec-wrapper.sh` into `codex-eval-executor.sh`, specialising it for read-only evaluation: strip git merge-on-success, add `--output-schema eval-result.schema.json`, remap JSONL events to eval-specific names. Drive it from a new `/cortex-eval-run` skill via an `eval-capsule.md` template generated from the eval-plan. Use codex (OpenAI `o4-mini`) as the independent evaluator — cross-vendor (OpenAI vs Anthropic), subprocess-isolated, with no access to the parent Claude session's context or code-writing history.

**Rationale:** `codex-exec-wrapper.sh` is battle-tested (615 lines, 19 integration tests, 9 failure modes handled). Reusing its infrastructure halves implementation risk. Cross-vendor independence provides a stronger anti-sycophancy guarantee than subprocess isolation alone — two different model families from different labs, not two sessions of the same model. Explicit skill over hook auto-trigger lets trust accumulate over a few runs before automation takes over.

### Alternatives Considered

- **Parameterised `--mode eval` flag in `codex-exec-wrapper.sh`:** Rejected — adds mode-branching to an already 615-line wrapper; eval-specific failure handling (no merge, different JSONL events, read-only assertion) differs enough to justify a separate file
- **Sub-agent with restricted Claude context (same vendor):** Rejected — Claude and code author share the same training distribution; cross-vendor independence via codex is a materially stronger guarantee
- **Full proposal/plan collapse (single artifact):** Deferred — owner confirmed the approval gate between proposal and plan is load-bearing; may reconsider after Phase 1 ships if the gate turns out ceremonial in practice
- **Hook-based auto-trigger from day one:** Deferred — async hook failures during initial deployment produce hard-to-debug failures; establish a trust baseline with explicit invocations first

---

## 4. Interfaces

**Reading:**
- `.cortex/state.json` — active slug, mode; owned by Cortex state machine; read-only from eval scripts
- `docs/cortex/contracts/{slug}/contract-001.md` — `## Eval Plan` field (path to eval-plan.md); owned by `/cortex-spec`; read by `/cortex-eval-run`
- `docs/cortex/evals/{slug}/eval-plan.md` — approved dimensions, fixtures, thresholds, run instructions; owned by `/cortex-research --phase evals` (and new generator); read by `generate-eval-capsule.py`
- `docs/cortex/evals/{slug}/eval-proposal.md` — source document for `generate-eval-plan.py`; owned by `/cortex-research --phase evals`; read by generator
- Deliverable source files in the target repo — collected by `generate-eval-capsule.py`; 200-line / 12KB cap per file

**Writing:**
- `docs/cortex/evals/{slug}/eval-plan.md` — written by `generate-eval-plan.py` (new automated path)
- `docs/cortex/evals/{slug}/results-{timestamp}.md` — written by `format-eval-results.py` via eval executor output
- `docs/cortex/handoffs/eval-status.md` — written by `format-eval-results.py` (composite scoring); read by `cortex-task-completed.sh`
- `.cortex/eval-ledger.jsonl` — appended by `codex-eval-executor.sh` on each eval completion
- `.cortex/events/{phase}-{plan}.jsonl` — appended by `codex-eval-executor.sh` (eval_started, eval_completed, eval_failed events)

**New file paths:**
- `templates/cortex/eval-capsule.md`
- `schemas/eval-result.schema.json`
- `scripts/cortex/generate-eval-plan.py`
- `scripts/cortex/generate-eval-capsule.py`
- `scripts/cortex/codex-eval-executor.sh`
- `scripts/cortex/format-eval-results.py`
- `.claude/skills/cortex-eval-run/SKILL.md`
- `.claude/agents/archive/cortex-eval-designer.md` (moved)

**Modified file paths:**
- `.claude/skills/cortex-research/SKILL.md` — Phase 3 overwrite guard
- `.claude/hooks/cortex-task-completed.sh` — non-blocking eval-pending behaviour
- `.claude/skills/cortex-review/SKILL.md` — eval results scan section

---

## 5. Dependencies

- `scripts/cortex/codex-exec-wrapper.sh` — forked basis for `codex-eval-executor.sh`; must not be modified by this refactor
- `codex` CLI (`o4-mini` default) — eval execution engine; requires `OPENAI_API_KEY` in environment
- `schemas/execution-event.schema.json` — event JSONL schema pattern; eval events follow same structure
- `templates/cortex/task-capsule.md` — structural model for `eval-capsule.md`
- `skills/cortex-review/SKILL.md` — extended with eval-results scan; existing convergence detector reused for eval verdict flapping
- `.claude/skills/cortex-research/SKILL.md` Phase 3 — receives overwrite guard; no other changes
- Python 3 stdlib (`json`, `yaml`, `pathlib`, `argparse`) — no new pip dependencies
- `jsonschema` pip package — used in eval-result schema validation test (already in repo if pytest is present; add to requirements if missing)

---

## 6. Risks

- **Eval executor diverges from exec-wrapper silently** — If `codex-eval-executor.sh` drifts, bug fixes in the original won't propagate. Mitigation: block-comment every eval-specific divergence with `# EVAL-SPECIFIC:` prefix; add a note in `codex-exec-wrapper.sh` header pointing to the eval fork.
- **Weak rubrics bypass anti-sycophancy intent** — Codex will pass permissive rubrics regardless of code quality. Mitigation: `generate-eval-capsule.py` validates that the eval-plan contains a `## Rejection Rules` section with ≥3 binary criteria before generating a capsule; raises `ValidationError` otherwise.
- **Non-deterministic codex verdicts** — Same deliverable + same capsule can produce different verdicts across runs. Mitigation: eval-plan fixtures must be deterministic (generator rejects randomised or network-dependent fixtures); convergence detector in `cortex-review` wired to flag flapping verdicts.
- **Overwrite guard blocks legitimate re-proposals** — Guard may prevent re-running `/cortex-research --phase evals` after a spec change invalidates the prior proposal. Mitigation: guard only blocks if `Approval Status: approved`; allows overwrite on `draft` or `rejected` status.
- **`eval-status.md` schema skew between writer and reader** — `format-eval-results.py` writes it; `cortex-task-completed.sh` reads it; if format diverges the hook fails silently. Mitigation: include a fixture `eval-status.md` in `test/test_format_eval_results.py` and assert the hook parses it without error.

---

## 7. Sequencing

1. **Phase 1 — Duplication elimination:** Write `generate-eval-plan.py` + test suite; add overwrite guard to cortex-research SKILL. Verifiable checkpoint: generator transforms all test fixture proposals correctly; overwrite guard blocks on `Approval Status: approved`.

2. **Phase 2a — Scaffolding:** Write `eval-capsule.md` template, `eval-result.schema.json`, `generate-eval-capsule.py` + tests. Verifiable checkpoint: capsule generator produces valid capsule from a real eval-plan fixture; rejects plans without `## Rejection Rules`.

3. **Phase 2b — Executor:** Write `codex-eval-executor.sh` + test suite. Verifiable checkpoint: test suite passes (≥10 cases); no git commit produced on success path; all 9 failure modes produce correct exit codes.

4. **Phase 2c — Results processor:** Write `format-eval-results.py` + tests. Verifiable checkpoint: output matches existing `kalshi-adaptive-loop` results format; `eval-status.md` updated correctly.

5. **Phase 2d — Wiring:** Write `/cortex-eval-run` SKILL; update `cortex-task-completed.sh`; update `cortex-review` SKILL; create `eval-ledger.jsonl` stub; add `task_type = "eval"` ledger tagging. Verifiable checkpoint: mock eval run produces results artifact at correct path; task-completed hook exits 0 when results absent; cortex-review outputs repair recommendation on FAIL dimension.

6. **Phase 4 — Cleanup:** Archive `cortex-eval-designer.md`; annotate `docs/EVALS.md`. Verifiable checkpoint: agent file exists at archive path; EVALS.md grep hits for `ASPIRATIONAL` and `IMPLEMENTED`.

---

## 8. Tasks

### Phase 1 — Duplication Elimination

- [ ] Write `scripts/cortex/generate-eval-plan.py`: reads `eval-proposal.md`, filters to approved (non-EXCLUDED) dimensions, copies fixtures and thresholds verbatim, preserves `## Run Instructions` section, removes rubrics and failure taxonomy, writes `eval-plan.md` with correct header fields (Approved By, Approved At)
- [ ] Write `test/test_generate_eval_plan.py`: ≥5 test cases covering correct dimension filtering, fixture verbatim copy, run-instructions preservation, rubric/taxonomy removal, and header field population; use `kalshi-adaptive-loop` eval-proposal as primary fixture
- [ ] Add overwrite guard to `.claude/skills/cortex-research/SKILL.md` Phase 3: before writing `eval-proposal.md`, check if file exists; if exists and `Approval Status: approved`, block with error message; if `draft` or `rejected`, allow overwrite with logged warning

### Phase 2a — Scaffolding

- [ ] Write `templates/cortex/eval-capsule.md`: sections — Slug, Approved Dimensions, Fixtures Per Dimension, Thresholds Per Dimension, Rejection Rules (≥3 binary criteria, mandatory), Deliverable Files (with size caps noted)
- [ ] Write `schemas/eval-result.schema.json`: `overall_verdict` (enum: pass/fail/partial), `evaluated_dimensions` array (each: `dimension` string, `verdict` enum, `finding` string, `severity` enum, `fixtures_tested` array, `failures` array of `{criterion, evidence}`), `deviations` array, `convergence_risk` string-or-null
- [ ] Write `scripts/cortex/generate-eval-capsule.py`: reads `eval-plan.md`, collects deliverable files (200-line / 12KB cap per file, full test files always included), validates `## Rejection Rules` section present with ≥3 items, renders capsule from template, writes to `/tmp/eval-capsule-{slug}-{timestamp}.md`; raises `ValidationError` on missing rejection rules
- [ ] Write `test/test_generate_eval_capsule.py`: ≥5 test cases covering capsule generation, file collection with cap enforcement, rejection-rules validation (passes with ≥3, fails with 0 or 2), test-file full inclusion

### Phase 2b — Executor

- [ ] Write `scripts/cortex/codex-eval-executor.sh`: fork of `codex-exec-wrapper.sh`; remove worktree-merge-on-success block; replace `task-capsule.md` with `eval-capsule.md` reference; add `--output-schema schemas/eval-result.schema.json` to codex invocation; rename JSONL events to `eval_started`, `eval_completed`, `eval_failed`; mark all eval-specific divergences with `# EVAL-SPECIFIC:` comments; write `task_type = "eval"` in SQLite ledger row
- [ ] Write `test/test_codex_eval_executor.sh`: ≥10 test cases — success path, timeout (exit 124), crash (non-zero), parse error, iteration budget exceeded, no git commit assertion (verify `git log` unchanged after success), ledger row written, eval_completed event in JSONL, exit codes match exec-wrapper conventions

### Phase 2c — Results Processor

- [ ] Write `scripts/cortex/format-eval-results.py`: transforms `eval-result.json` → `results-{timestamp}.md` matching existing format (validated against `kalshi-adaptive-loop/results-20260407T064500Z.md` as fixture); also updates `docs/cortex/handoffs/eval-status.md` composite scoring section with per-dimension rows; writes results file to `docs/cortex/evals/{slug}/results-{timestamp}.md`
- [ ] Write `test/test_format_eval_results.py`: ≥5 test cases — markdown output matches fixture format, eval-status.md updated correctly, timestamp in output filename, failed dimension appears in results with evidence field populated

### Phase 2d — Wiring

- [ ] Write `.claude/skills/cortex-eval-run/SKILL.md`: reads active slug from `.cortex/state.json`, reads contract `## Eval Plan` field, invokes `generate-eval-capsule.py` → `codex-eval-executor.sh` → `format-eval-results.py` in sequence, writes results artifact to `docs/cortex/evals/{slug}/results-{timestamp}.md`, logs `eval_run_started` and `eval_run_completed` events to `.cortex/events/`
- [ ] Update `.claude/hooks/cortex-task-completed.sh`: if contract references an eval-plan path but no `results-*.md` exists in `docs/cortex/evals/{slug}/`, write `docs/cortex/handoffs/eval-status.md` with status "evals pending — run /cortex-eval-run" and exit 0 (do not block); existing FAIL-detection logic on populated eval-status.md is unchanged
- [ ] Update `.claude/skills/cortex-review/SKILL.md`: add section "Eval Results Scan" — glob `docs/cortex/evals/{slug}/results-*.md`, for each FAIL or PARTIAL dimension output a repair recommendation paragraph with dimension name, evidence field from results, and suggested repair action; reference convergence detector if same dimension failed in a prior run
- [ ] Create `.cortex/eval-ledger.jsonl`: empty file with one-line comment header `# Cortex eval ledger — one JSON line per eval run. Fields: slug, timestamp, overall_verdict, dimensions_passed, dimensions_failed, cost_usd, codex_model`
- [ ] Add `task_type = "eval"` to SQLite ledger write in `codex-eval-executor.sh` (already included in Phase 2b task above — confirm it is present)

### Phase 4 — Cleanup

- [ ] Archive `.claude/agents/cortex-eval-designer.md` → `.claude/agents/archive/cortex-eval-designer.md`; add header comment: `# ARCHIVED — superseded by codex-eval-executor.sh (eval-system-refactor spec, 2026-04-10). Eval proposal writing stays in cortex-research SKILL Phase 3.`
- [ ] Annotate `docs/EVALS.md`: mark repair loop section as `> **STATUS: ASPIRATIONAL** — not yet implemented`, mark results section as `> **STATUS: IMPLEMENTED** — see scripts/cortex/format-eval-results.py`, mark proposal/plan lifecycle as `> **STATUS: IMPLEMENTED**`

---

## 9. Acceptance Criteria

- [ ] `generate-eval-plan.py` correctly transforms the `kalshi-adaptive-loop` eval-proposal fixture: output contains only non-EXCLUDED dimensions, fixtures section is verbatim copy, run instructions section is preserved, rubrics section is absent, failure taxonomy section is absent
- [ ] `test/test_generate_eval_plan.py` passes with ≥5 test cases and 0 failures
- [ ] Running `/cortex-research --phase evals` on a slug with an existing `eval-proposal.md` whose `Approval Status` is `approved` produces an error message and does not overwrite the file
- [ ] `templates/cortex/eval-capsule.md` contains all 6 required sections: Slug, Approved Dimensions, Fixtures Per Dimension, Thresholds Per Dimension, Rejection Rules, Deliverable Files
- [ ] `schemas/eval-result.schema.json` is valid JSON Schema (no syntax errors); validates a sample conforming object without error; rejects an object missing `overall_verdict`
- [ ] `generate-eval-capsule.py` raises `ValidationError` (or equivalent non-zero exit) when invoked on an eval-plan.md that has no `## Rejection Rules` section
- [ ] `generate-eval-capsule.py` enforces the 200-line / 12KB per-file cap on deliverable files (verified with an oversized fixture)
- [ ] `test/test_generate_eval_capsule.py` passes with ≥5 test cases and 0 failures
- [ ] A successful `codex-eval-executor.sh` run does not produce any new git commits (verified: `git log --oneline -1` is identical before and after the run)
- [ ] `codex-eval-executor.sh` handles timeout (exit 124), crash (non-zero codex exit), and parse error failure modes with correct `fallback_reason` in output JSON
- [ ] `test/test_codex_eval_executor.sh` passes with ≥10 test cases and 0 failures
- [ ] `format-eval-results.py` output for a passing eval matches the format of `docs/cortex/evals/kalshi-adaptive-loop/results-20260407T064500Z.md` (table structure, section headings, Overall verdict line)
- [ ] `format-eval-results.py` updates `docs/cortex/handoffs/eval-status.md` with at least one dimension score row
- [ ] `test/test_format_eval_results.py` passes with ≥5 test cases and 0 failures
- [ ] `/cortex-eval-run` skill reads the active contract's `## Eval Plan` field and invokes the three-script chain in order; produces a `results-{timestamp}.md` artifact at `docs/cortex/evals/{slug}/`
- [ ] `cortex-task-completed.sh`: when an eval-plan is referenced by the active contract but no `results-*.md` file exists, hook exits 0 and writes "evals pending" message to `eval-status.md`
- [ ] `cortex-review` SKILL: when any dimension in `results-*.md` has `FAIL` verdict, skill output includes a repair recommendation paragraph naming the dimension and quoting the `evidence` field
- [ ] `.cortex/eval-ledger.jsonl` exists as a file (may be empty except for header comment)
- [ ] `docs/cortex/evals/eval-system-refactor/eval-plan.md` does not exist yet — `/cortex-research --phase evals` must be run after this contract executes
- [ ] `.claude/agents/archive/cortex-eval-designer.md` exists and contains `# ARCHIVED` header comment
- [ ] `docs/EVALS.md` contains the string `ASPIRATIONAL` in at least the repair loop section and `IMPLEMENTED` in at least the results and proposal/plan lifecycle sections
