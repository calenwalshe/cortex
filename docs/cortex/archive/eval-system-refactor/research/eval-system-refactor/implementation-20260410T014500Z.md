# Research Dossier: eval-system-refactor — implementation

<!-- ART-02: Research Dossier Template — produced by /cortex-research -->

**Slug:** eval-system-refactor
**Phase:** implementation
**Timestamp:** 20260410T014500Z
**Depth:** deep

---

## Summary

Codex-as-independent-evaluator is feasible *and* most of the infrastructure already exists. `scripts/cortex/codex-exec-wrapper.sh` (615 lines, 19 integration tests) is a production-grade wrapper that spawns codex in an isolated git worktree, generates a context capsule, parses JSONL output, tracks tokens, writes a SQLite ledger, and handles timeout/crash/circuit-breaker/iteration-budget failure modes. Its isolation properties are exactly what anti-sycophancy requires: fresh subprocess, separate worktree, network-disabled sandbox, no access to parent Claude session state. Adapting it for eval execution is a **wrapper-and-schema problem, not a wrapper-rewrite problem** — reuse ~70% of the existing wrapper, add an eval-capsule template, an eval-result JSON schema, and a thin `codex-eval-executor.sh`. The biggest non-obvious risk is that codex and Claude share an ecosystem (both are frontier LLMs with similar training biases), so structural mitigations — objective rubrics only, explicit rejection rules in the capsule, immutable disk-backed results, and convergence detection — are load-bearing, not optional.

---

## Findings

- **Codex wrapper is real and production-grade**: `scripts/cortex/codex-exec-wrapper.sh` exists with full lifecycle management: worktree creation, capsule generation, circuit breaker (3 consecutive failures → stop), iteration budget (`file_count × 10`, min 20), JSONL parsing, token accounting, SQLite ledger writes, and 9 failure modes handled deterministically. The 723-line test suite (`test/codex-exec-wrapper.test.sh`) exercises success paths, timeout, crash, test failure, parse error, budget exhaustion, and cleanup.
- **Invocation interface is stdin-based and sandbox-isolated**: Pattern is `timeout "$TIMEOUT" codex exec --full-auto --json -C "$WORKTREE_PATH" - < "$CAPSULE_FILE"`. `--full-auto` sets `approval_policy=on-request` and `sandbox_mode=workspace-write`, network disabled, writes confined to workspace + `/tmp`. Model defaults to `o4-mini` (configurable via `CODEX_MODEL`).
- **Context isolation is load-bearing and enforced**: Codex runs in a fresh subprocess with a dedicated git worktree (`/tmp/gsd-codex-{phase}-{plan}-XXXXXX`) on a new branch (`codex/{phase}-{plan}-task{N}`). It receives only the capsule file via stdin — no `.cortex/state.json`, no contract, no prior eval results, no claude-session transcript. Files it reads are capped at 200 lines / 12KB per file. Cleanup trap on exit. This is exactly the isolation the anti-sycophancy requirement needs.
- **Output contract is structured JSON**: Wrapper returns a result JSON with `status`, `result.{files_changed, tests_passed, deviations, commit_hash}`, `tokens.{input, output, cached, reasoning}`, `cost_usd`, `elapsed_ms`, `fallback_reason`. Extracted from the last `turn.completed` event in the JSONL stream. This shape is a near-perfect match for what eval-result JSON would look like — we'd keep tokens/cost/elapsed and replace `result` with per-dimension verdicts.
- **Token ledger already exists**: SQLite `codex_tasks` table records `task_id`, `model`, four token types, cost, session_id, project_slug, phase, `task_type`, plan_file, exit_code, elapsed_ms. Adding `task_type = "eval"` gives free FP-rate instrumentation groundwork — we can query eval-pass events, later correlate with bug discoveries.
- **Event log infrastructure exists**: JSONL events written to `.cortex/events/{phase}-{plan}.jsonl` with `task_started`, `circuit_breaker`, `budget_exceeded`, `task_completed`, `task_failed`. Same path works for `eval_started`, `eval_completed`, `eval_failed`.
- **`cortex-review` skill already has a convergence detector**: The recent commit `0db8bdc feat(pattern-harvest): add repair budget to contract + convergence detector to review` added logic that detects 3+ repair contracts with >80% similar failures and generates a `convergence-stall.md`. This is reusable for eval verdict flapping — if the eval result flips across runs, convergence detector catches the loop.
- **Existing `cortex-validator-trigger` hook is a stub**: Current hook (`.claude/hooks/cortex-validator-trigger.sh` L26-32) only tracks dirty files during execute/repair mode. It's the obvious seam for eval execution triggering but currently does nothing beyond logging.
- **Codex is an OpenAI model, not Anthropic**: Wrapper uses `codex` CLI with `o4-mini` default. This is an OpenAI product. Claude and codex are NOT from the same vendor — independence across model families is real, not just subprocess isolation. This is a stronger anti-sycophancy guarantee than I initially assumed.
- **Cost per eval run is bounded and affordable**: `o4-mini` pricing (`$0.0000011/input token`, `$0.0000044/output token`). Estimated eval capsule size: 2000–4000 input tokens (eval-plan + deliverable snippets). Expected per-eval cost: `$0.004–$0.010` per dimension, `$0.015–$0.050` per multi-dimension slug. Below the "ceremony net-negative" threshold from owner-intent.
- **Determinism gap is real but manageable**: LLM output is non-deterministic. Same deliverable + same eval-plan can produce different verdicts across runs. Mitigations: (1) fixed fixtures (not randomized), (2) binary thresholds (pass/fail, not fuzzy scoring), (3) `--output-schema` constraint to force structured output, (4) convergence detector to flag flapping verdicts.
- **`eval-status.md` composite scoring becomes computable**: Once eval results are JSON with per-dimension verdicts, the composite score aggregation described in `templates/cortex/eval-status.md` becomes a simple script — no longer blocked on "how do we score this?"
- **No git merge on eval success**: Key difference from task execution. The existing wrapper merges the worktree back to the parent branch on success. For eval, we **never merge** — eval is read-only analysis. The worktree is always torn down. Result goes to disk as a markdown + JSON artifact, not as a commit.

---

## Question Coverage

| # | Question | Type | Status | Addressed by | Provider Used |
|---|----------|------|--------|--------------|---------------|
| 1 | Does a codex wrapper already exist? | codebase | answered | Finding 1 | Explore agent |
| 2 | What's the invocation interface? | codebase | answered | Finding 2 | Explore agent + wrapper read |
| 3 | Is context isolation real or cosmetic? | codebase | answered | Finding 3 | Explore agent |
| 4 | What's the output contract? | codebase | answered | Finding 4 | Explore agent |
| 5 | What needs to be added for eval use? | codebase | answered | Trade-off A, Recommendations | Explore agent |
| 6 | Cost per eval run? | factual | answered | Finding 10 | Wrapper pricing constants |
| 7 | Determinism risks? | mechanism | answered | Finding 11, Risk #3 | Explore agent |
| 8 | Does codex share Claude's biases? | codebase | answered | Finding 9 | Explore agent |
| 9 | How does repair loop integrate? | codebase | answered | Finding 7 | Explore agent + cortex-review read |

---

## Trade-offs

### Option A: Build `codex-eval-executor.sh` as a parallel wrapper (reuse existing patterns)
**Pros:**
- Reuses battle-tested infrastructure: worktree creation, JSONL parsing, token ledger, event logging, circuit breaker
- Clear separation: task execution and eval execution are different concerns
- Existing `codex-exec-wrapper.sh` stays unchanged (stable, tested)
- Estimated ~400 lines new code, ~70% conceptual reuse

**Cons:**
- Some code duplication between the two wrappers
- Drift risk over time if one is improved and the other isn't

**Verdict:** selected — duplication is manageable, and keeping the existing wrapper stable is worth more than DRY at this stage

### Option B: Parameterize the existing wrapper with a `--mode` flag (eval vs exec)
**Pros:**
- Single source of truth for codex invocation logic
- Shared improvements to wrapper apply to both modes
- Smaller total codebase

**Cons:**
- Expands an already-complex 615-line wrapper
- Mode branching makes the code harder to reason about
- Risk of mode-specific bugs leaking into execute path
- Test suite would need to double in size (19 → ~35 tests)

**Verdict:** rejected — the wrapper is already at its complexity ceiling; forking is safer than overloading

### Option C: Use codex for all 8 dimensions vs. only objective dimensions
**Pros of all-8:**
- Complete coverage; eval system handles everything uniformly
- Consistent interface for repair loop

**Cons of all-8:**
- Subjective dimensions (UX/taste, style judgment) are exactly where LLM sycophancy is worst
- "Is this code elegant?" is precisely the wrong question to ask a model

**Pros of objective-only:**
- Constrains codex to mechanically verifiable criteria (tests pass, files exist, schemas match, imports work)
- Sycophancy risk drops dramatically
- Remaining subjective dimensions fall back to human approval gate (already in place)

**Verdict:** selected (objective-only for Phase 2) — functional correctness, regression, integration, style (measurable aspects: docstrings exist, imports work), safety (secrets absent, permissions set). UX/taste and subjective safety judgments stay as markdown with approval gate.

### Option D: Batch all dimensions in one codex call vs. per-dimension invocations
**Pros of batch:**
- Cheaper (single input token overhead)
- Codex sees full eval context at once, can cross-reference between dimensions

**Cons of batch:**
- One timeout kills the whole eval run
- Single hallucination affects all verdicts
- Harder to debug per-dimension failures

**Pros of per-dimension:**
- Isolated failure modes
- Can re-run a single dimension without re-running everything
- Parallelism possible (though we'll start serial)

**Cons of per-dimension:**
- Higher cost (linear in dimension count, though still cheap: 3 dims × $0.01 = $0.03)
- More ledger rows per slug

**Verdict:** selected — **batch by default, per-dimension as escape hatch** when a specific dimension needs re-evaluation. Start with batch; add `--dimension <name>` flag to executor for targeted re-runs.

### Option E: Eval execution as a hook (auto) vs. explicit command (manual)
**Pros of hook:**
- Non-blocking, fire-and-forget after execute completes
- Consistent: every execute → eval flow
- Matches existing hook infrastructure (cortex-validator-trigger is the seam)

**Cons of hook:**
- Harder to debug failures (runs in background)
- Risk of eval running before execute is actually done
- Async failures require a separate retrieval mechanism

**Pros of explicit command:**
- Clear, debuggable, testable
- User controls when eval runs
- Matches cortex-research / cortex-spec pattern

**Cons of explicit command:**
- Easier to forget
- Adds a step to every slug

**Verdict:** selected — **explicit command first, hook after it's trusted.** Add `/cortex-eval-run` as an explicit skill; once it's stable over ~5 slugs, wire it into the validator-trigger hook as an optional auto-run.

---

## Recommendations

- **Phase 2a — Scaffolding (1-2 days):**
  1. Create `templates/cortex/eval-capsule.md` — parallel to `task-capsule.md`. Fields: slug, approved dimensions, fixtures per dimension, thresholds per dimension, deliverable file list (read-only), **explicit rejection rules** ("If X is true, verdict MUST be FAIL regardless of other signals"), expected output schema reference.
  2. Create `schemas/eval-result.schema.json` — constrains codex output. Shape: `overall_verdict`, `evaluated_dimensions: [{ dimension, verdict, finding, severity, fixtures_tested, failures: [{criterion, evidence}] }]`, `deviations`, `convergence_risk`.
  3. Create `scripts/cortex/generate-eval-capsule.py` — reads `eval-plan.md` + collects deliverable files into a capsule following the template.
  4. Create `scripts/cortex/codex-eval-executor.sh` — forked from `codex-exec-wrapper.sh`, stripped of merge-on-success logic, uses `--output-schema eval-result.schema.json`, writes result JSON to `/tmp/eval-result-{slug}-{timestamp}.json`.

- **Phase 2b — Results processing (0.5-1 day):**
  5. Create `scripts/cortex/format-eval-results.py` — transforms eval-result JSON into the existing `results-{timestamp}.md` markdown format for human readability (and backward compat with the 2 existing manually-written results files).
  6. Update `.cortex/state.json` to record `approvals.evals_executed = <timestamp>` and `eval_result_path`.

- **Phase 2c — Wiring (1 day):**
  7. Add `/cortex-eval-run` skill (explicit invocation). Reads active contract's `eval_plan` field, runs generate-capsule → executor → format-results chain, writes results artifact, logs to event stream, updates state.
  8. Update `cortex-task-completed.sh` to be non-blocking on missing eval results: if eval-plan exists but results don't, write `eval-status.md` with "evals pending" status and proceed (don't block). Existing FAIL detection stays.
  9. Update `cortex-review` skill to scan eval result files for FAIL dimensions and auto-generate repair recommendations (it already knows how to generate recommendations — this just adds the scan).

- **Phase 2d — Ledger and instrumentation (0.5-1 day):**
  10. Tag eval-executor ledger rows with `task_type = "eval"`. Adds a `codex-eval-cost` query and logs to `.cortex/events/`.
  11. Add a stub FP-ledger file `.cortex/eval-ledger.jsonl` — one row per eval pass. Later phases will correlate with bugs found post-ship. Zero-effort setup, pays off when FP instrumentation lands.

- **Phase 3 — Anti-sycophancy structural mitigations (design-time, not build-time):**
  12. **Eval capsule rule:** Every capsule must include an explicit `## Rejection Rules` section with at least 3 objective, binary, auto-verifiable rejection criteria per included dimension. Capsules without rejection rules fail capsule validation.
  13. **Fixture constraint:** Fixtures in eval-plans must be deterministic — no randomized data, no network-dependent inputs. Capsule generator rejects randomized fixtures.
  14. **Convergence wiring:** Feed eval results into the existing convergence detector in `cortex-review`. If the same eval flips verdict across runs, trigger a convergence-stall artifact and pause the repair loop.
  15. **Rubric scope limit:** Phase 2 codex-run is restricted to objective dimensions only: functional correctness, regression, integration, style (mechanical aspects only — docstrings present, imports work, naming consistent). Subjective dimensions (UX/taste, subjective safety judgment) stay as markdown with human approval.

- **Phase 4 — Cortex-eval-designer decision (cheap cleanup):**
  16. Decide agent fate: since Phase 2 introduces a clear producer (`codex-eval-executor.sh`) and the existing generator lives in the SKILL, archive `cortex-eval-designer.md` with a note linking to the refactor spec. Or: move proposal-writing logic out of cortex-research SKILL and delegate to the agent, so the agent owns proposals and the executor owns execution. **Recommend: archive.** Moving logic adds no value if the refactor is already splitting execution out cleanly.

- **Defer to later spec:**
  - Collapsing `eval-proposal.md` + `eval-plan.md` into a single artifact (Option A from concept dossier). The approval gate between them is NOT ceremonial — the user confirmed they do not auto-approve after research. Keep the split.
  - Backfilling the 8 unexecuted eval-plans. Track as separate work; do not expand this refactor's scope.
  - Full repair contract automation. Phase 2c's cortex-review scan is enough to trigger repairs manually; full automation can wait.

---

## Adjacent Findings

- **The existing convergence detector is a latent anti-sycophancy weapon.** It was built for pattern-harvest to catch repair loops stuck on similar failures, but the same mechanism catches eval verdict flapping, which is the most likely symptom of LLM-as-judge instability. Wiring it into eval-result scanning in Phase 2c costs almost nothing but buys a real safety net. Source: `skills/cortex-review/SKILL.md` lines 331–369 (convergence detector); recent commit `0db8bdc`.
- **The SQLite token ledger already supports a `task_type` column.** Tagging eval-executor rows with `task_type = "eval"` gives free, immediate cost observability AND is the exact schema shape needed for later false-positive-rate instrumentation. Once eval runs are in the ledger, adding a "link to bug-found-after-ship" column is a 1-line schema migration. The FP instrumentation task (Phase 3b from concept dossier) becomes trivially cheap if we tag from day one. Source: `codex-exec-wrapper.sh` lines 185–214 (ledger schema and write logic).

---

## Open Questions

- Should the codex model for eval be different from the execute-mode default? `o4-mini` is cheap; a larger model might be worth it for eval's "catch the bug" job. Decide: leave at `o4-mini` for Phase 2 cost baseline, reassess after FP rate instrumentation lands.
- What happens when eval-executor itself errors out (codex crash, timeout, parse error)? The wrapper returns `fallback_reason` — do we block the contract at `validate`, or write a "eval-executor-failed" artifact and let cortex-review handle it? **Leaning:** non-blocking; write eval-status.md with "eval executor failed — manual review required" and let human decide.
- Should the eval capsule include full deliverable file contents, or only a manifest + selective snippets? Full content is expensive but thorough; selective is cheap but may miss bugs hiding in code the capsule didn't include. **Leaning:** selective with a cap (match exec-wrapper's 200 lines / 12KB per file), include the full test file contents as they're the ground-truth verifier.
- Does the eval capsule need the contract, or just the eval-plan? Including the contract gives codex access to done criteria and spec intent, which helps verdict quality but increases sycophancy risk (codex can read "this is what the author intended" and agree). **Leaning:** eval-plan only for Phase 2. Revisit if verdict quality is poor.
- How do we prevent the eval-executor from writing to files it shouldn't? The existing wrapper's sandbox does this for the subprocess, but we need capsule-level enforcement too — eval must explicitly NOT modify code under review. **Leaning:** read-only worktree checkout flag, or a pre-check that asserts zero file modifications after codex run.
- Should `/cortex-eval-run` auto-trigger repair contracts on FAIL verdicts, or just log and let cortex-review handle it in a separate step? **Leaning:** log only; preserve the review step as a human-readable gate.

---

## Sources

- `/home/agent/projects/cortex/scripts/cortex/codex-exec-wrapper.sh` (615 lines; full lifecycle wrapper)
- `/home/agent/projects/cortex/test/codex-exec-wrapper.test.sh` (723 lines; 19 integration tests)
- `/home/agent/projects/cortex/schemas/execution-event.schema.json` (JSONL event schema)
- `/home/agent/projects/cortex/templates/cortex/task-capsule.md` (parallel template to copy for eval-capsule)
- `/home/agent/projects/cortex/skills/cortex-review/SKILL.md` (lines 331–369: convergence detector)
- `/home/agent/projects/cortex/.claude/hooks/cortex-validator-trigger.sh` (lines 26–32: current stub, target seam for eval auto-trigger)
- `/home/agent/projects/cortex/.claude/hooks/cortex-task-completed.sh` (lines 22–59: eval-status.md blocking behavior)
- `/home/agent/projects/cortex/docs/cortex/research/token-efficiency/concept-codex-handoff-20260402T225257Z.md` (wrapper design rationale)
- `/home/agent/projects/cortex/docs/cortex/research/token-efficiency/implementation-20260402T225932Z.md` (wrapper implementation blueprint; includes o4-mini pricing constants)
- `/home/agent/projects/cortex/docs/cortex/contracts/pattern-harvest/contract-001.md` (prior contract using codex wrapper)
- `.cortex/events/` (JSONL event stream; reusable for eval events)
- SQLite token ledger schema: `codex_tasks` table with `task_type` column (from wrapper L185–214)
- `/home/agent/projects/cortex/docs/cortex/research/eval-system-refactor/concept-20260410T010000Z.md` (concept dossier — this implementation dossier builds on it)
- Commit `0db8bdc`: "feat(pattern-harvest): add repair budget to contract + convergence detector to review"
- Commit `0558337`: "feat(pattern-harvest): add circuit breaker and iteration budget to codex wrapper"
