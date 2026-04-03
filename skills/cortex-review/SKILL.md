# Cortex Code Review — Multi-Lens Review

Combines Superpowers code review standards (no sycophancy, verify before implementing) with GStack's engineering and security review lenses.

## User-invocable
When the user types `/cortex-review`, run this skill.
Also trigger when: "review this", "review my code", "code review", "PR review", "review against contract", "contract review", "compliance review".

## Arguments
- `/cortex-review [<target>]` — file, PR, or component to review; defaults to current active contract scope
- `/cortex-review --security` — security-focused review only
- `/cortex-review --pr N` — review a specific PR number
- `--autonomy <preset>` — override the autonomy preset for this invocation only. Valid values: `supervised`, `gates-only`, `full-auto`. Passed to the resolver as the invocation layer (highest precedence in the 4-layer resolution).
- `--gate <name>=<bool>` — override a specific gate for this invocation only. Example: `--gate compliance_verdict=false`. Repeatable. Passed to the resolver as invocation-layer gate overrides.
- `--dry-run` — print the resolved autonomy gate table without executing any command logic, writing files, or modifying state.

### --dry-run Mode

If `--dry-run` is passed:
1. Resolve autonomy config using `resolveAutonomyWithSources` from `scripts/cortex/resolve-autonomy.js`
2. Print the resolved gate table showing gate name, value, and source layer for all 13 gates
3. Print which gates this specific command checks (cortex-review checks `eval_validation`, `compliance_verdict`)
4. Do NOT execute any command logic, write any files, or modify any state
5. Exit after printing the table

## Anti-Sycophancy Rules (MANDATORY)

**NEVER say during review:**
- "You're absolutely right!"
- "Great point!" / "Excellent work!"
- "Thanks for catching that!"
- ANY gratitude or performative agreement

**INSTEAD:** State findings technically. Just fix things. Actions over words.

## Instructions

### Phase 0: Resolve Slug and Load Contract

Before beginning the review:

1. Read `.cortex/state.json` to get the active slug.
2. If `slug` is null AND `<target>` argument is provided: derive slug from `<target>` using the standard slugification rule (lowercase, replace spaces and non-alphanumeric characters with hyphens, collapse consecutive hyphens, strip leading/trailing hyphens).
3. If `slug` is null AND no argument was provided: proceed with slug as `"unknown"` (review can still run; artifact path will use `"unknown"` as slug).
4. Read `docs/cortex/handoffs/current-state.md` to get `active_contract_path`.
5. If `active_contract_path` is set: read the contract file and load `done_criteria` and `validators` for the compliance check in the Contract Compliance section below.

### 1. Identify What to Review

```bash
# Staged changes
git diff --cached --stat

# If nothing staged, unstaged changes
git diff --stat

# If reviewing a PR
gh pr diff <N> --stat
```

Read the full diff. Understand every change before commenting.

### 2. Engineering Lens

For each changed file, check:

**Correctness:**
- Does the code do what it claims?
- Are edge cases handled?
- Are error conditions covered?
- Are types correct? (if typed language)

**Quality:**
- Is there unnecessary complexity?
- YAGNI check: is everything here actually used?
- Are names clear and descriptive?
- Is the diff minimal for the intent?

**Testing:**
- Do new functions have tests?
- Were tests written first? (TDD check)
- Are tests testing behavior, not implementation?
- Do tests use real code, not excessive mocks?

**Architecture:**
- Does this fit the existing patterns?
- Does it introduce new dependencies?
- Is the abstraction level appropriate?
- Will this be easy to modify later?

### 3. Security Lens

For each changed file, check:
- SQL injection: string concatenation in queries?
- XSS: unescaped user input in HTML output?
- Command injection: user input in shell exec?
- Auth bypass: missing access checks on new routes?
- Secrets: hardcoded credentials, API keys?
- SSRF: user-controlled URLs in server-side requests?
- Path traversal: user input in file paths?

### 4. YAGNI Lens

For any "improvements" or "proper implementation" suggestions:
```bash
# Grep for actual usage before recommending additions
grep -r "functionName" --include="*.{ts,js,py,rb}" .
```
If unused → suggest removal, not improvement.

### 4b. Omission Lens

When an active contract is loaded, explicitly check for what SHOULD be present but ISN'T:

1. Read each done criterion from the contract.
2. For each criterion, verify that the diff or codebase contains code that satisfies it.
3. Report missing implementations as:
   ```
   [OMISSION] contract done_criteria #{N} — "{criterion text}" — no matching implementation found
   ```
4. Check deliverables list: is every listed deliverable present on disk?
5. Check write roots: were any files written OUTSIDE the allowed write roots?

Omissions are as important as errors — a review that only checks what's there misses half the picture.

### 5. Output Format

```
CODE REVIEW
════════════════════════════════════════════════
Files reviewed: N
Changes: +N / -N lines

ISSUES
────────────────────────────────────────────────

[BLOCK] file:line — Description
  Must fix before merge.

[WARN] file:line — Description
  Should fix, but not blocking.

[NOTE] file:line — Description
  Consider for future.

[SECURITY] file:line — Description
  Security concern. Severity: [HIGH/MEDIUM/LOW]

SUMMARY
────────────────────────────────────────────────
  Blocking:  N
  Warnings:  N
  Notes:     N
  Security:  N

Verdict: [APPROVE | REQUEST CHANGES | NEEDS DISCUSSION]
════════════════════════════════════════════════
```

### Contract Compliance

This section is required — it cannot be omitted. Append it to the CODE REVIEW output block before the closing delimiter.

**Autonomy config resolution:**
Before evaluating contract compliance gates, resolve the autonomy config:
1. Read `.cortex/autonomy.json` (project-level) and `~/.claude/cortex-autonomy.json` (global-level) if they exist.
2. Determine the active preset (default: `supervised` if no config found).
3. Resolve all gate values using 4-layer precedence. If `--autonomy` or `--gate` flags were provided, use them as the invocation layer (highest precedence in the 4-layer resolution). Resolution order: invocation flags > project config > global config > preset defaults. Mandatory gates (`ux_taste_eval`, `human_action`, `reclarify`) are always forced true regardless of config.

The following gates apply to this section:
- `eval_validation` — Controls the eval plan validation block. False in `full-auto` and `gates-only` presets.
- `compliance_verdict` — Controls the compliance verdict. False in `full-auto` and `gates-only` presets.

**If `active_contract_path` was loaded (from Phase 0):**

For each done criterion in the contract, evaluate against the review findings and produce a line:
```
[PASS|FAIL|PARTIAL] <criterion> — <specific finding note>
```

For each validator in the contract, note whether it would pass based on review findings:
```
[PASS|FAIL] <validator> — <finding note>
```

**Eval Plan Validation:**

**Gate: `eval_validation` (autonomy-conditional)**
If `gates.eval_validation` is `false` (per autonomy resolution above): skip the eval plan validation block — do not produce `[BLOCK]` issues for missing or pending eval plans. Instead, produce a `[NOTE]` level entry: `[NOTE] contract eval_plan — eval plan validation skipped (autonomy: {preset})`.
When auto-proceeding (gate is false/skipped), append a decision log entry to `docs/cortex/handoffs/decisions.md` under the `## Autonomy Decisions` section:
```
- {ISO8601 timestamp} | gate: eval_validation | value: false (auto-skipped) | preset: {active_preset} | command: /cortex-review
```
If `gates.eval_validation` is `true` (or no autonomy config exists): evaluate as follows:

Read `eval_plan:` field from the active contract.
- If value is `pending`, `TBD`, or empty → add to review issues:
  ```
  [BLOCK] contract eval_plan — eval_plan field is "pending". The eval proposal must be produced
  and approved (run /cortex-research --phase evals, then /cortex-research --write-plan) before
  this contract can advance to assure. This is a P1 gap.
  ```
- If value is a file path: check whether that file exists on disk.
  If file does not exist → add:
  ```
  [BLOCK] contract eval_plan — eval_plan path {path} does not exist on disk. P1 gap.
  ```
- If file exists → no issue; note `[PASS] eval_plan — {path} exists`.

**Gate: `compliance_verdict` (autonomy-conditional)**
If `gates.compliance_verdict` is `false` (per autonomy resolution above): auto-proceed — still produce the compliance verdict line in the output (for logging), but do NOT block the pipeline on a NON-COMPLIANT verdict.
When auto-proceeding (gate is false/skipped), append a decision log entry to `docs/cortex/handoffs/decisions.md` under the `## Autonomy Decisions` section:
```
- {ISO8601 timestamp} | gate: compliance_verdict | value: false (auto-skipped) | preset: {active_preset} | command: /cortex-review
```
The review artifact is written regardless.
If `gates.compliance_verdict` is `true` (or no autonomy config exists): compute the verdict and present a gate brief.

Count findings by type: PASS, FAIL, PARTIAL, BLOCK. Render:

```
════════════════════════════════════════
GATE: Compliance Verdict
════════════════════════════════════════

Would mark contract as {COMPLIANT|NON-COMPLIANT|PARTIALLY COMPLIANT}.
  - {pass_count} criteria passed
  - {fail_count} criteria failed
  - {partial_count} partially met
  - {block_count} blocking issues

Details: {review_artifact_path}
════════════════════════════════════════

CONTRACT COMPLIANCE: COMPLIANT | NON-COMPLIANT | PARTIALLY COMPLIANT
```

If NON-COMPLIANT, present an AskUserQuestion:
- **header:** "Compliance"
- **question:** "Contract is non-compliant. How to proceed?"
- **options:**
  - "Stop" — halt pipeline to fix issues
  - "Proceed anyway" — acknowledge and continue (verdict is logged)
  - "Show details" — print full finding list, then re-prompt

If COMPLIANT or PARTIALLY COMPLIANT: no blocking prompt, continue.

**If no active contract was found:**
```
Contract compliance: No active contract found — compliance check skipped
```

### 6. Handling Pushback

If the author disagrees with a finding:
- Verify against the codebase — you might be wrong
- If you were wrong: "Checked [X], you're correct. Withdrawing."
- If you're right: restate with technical evidence, reference tests/code
- Don't double down without evidence. Don't cave without evidence.

### Eval Failure Check

Run this check when an active contract is loaded and its `eval_plan` field points to an existing file.

1. Read `docs/cortex/evals/{slug}/eval-plan.md`
2. Scan the `## Results` section for failed checkboxes: lines matching `- [ ]` (unchecked) that appear after the results header indicate incomplete or failed items.
3. Also look for explicit failure markers: lines containing `FAIL`, `failed`, or `❌`.

**If failures found:**

  a. Generate timestamp: `YYYYMMDDTHHMMSSZ`
  b. Write repair recommendation to `docs/cortex/evals/{slug}/repair-rec-{timestamp}.md` with this structure:

     ```markdown
     # Eval Repair Recommendation: {slug}

     **Timestamp:** {timestamp}
     **Contract:** {active_contract_path}
     **Failing Dimensions:** {comma-separated list of failing dimensions}

     ## Failure Summary

     | Dimension | Failure Description | Severity |
     |-----------|---------------------|----------|
     | {dim}     | {what failed}       | P0/P1/P2 |

     ## Repair Recommendation

     {For each failing dimension: specific repair action and whether it can be resolved in-contract or requires a new contract}

     ## Repair Contract

     {If any P0 failure: path to repair contract written below, or "See contract-NNN.md"}
     {If all P1/P2: "In-contract repair — no new contract needed"}
     ```

  c. Update `docs/cortex/handoffs/current-state.md`:
     - `blockers`: append the repair recommendation path
     - `next_action`: `Eval failures found. Review repair recommendation at docs/cortex/evals/{slug}/repair-rec-{timestamp}.md`

  d. **P0 failures only:** If any failing dimension has severity P0 (safety/security or functional correctness with complete failure):
     - Scan `docs/cortex/contracts/{slug}/` for the highest existing contract number (pattern: `contract-NNN.md`)
     - Write a new repair contract to `docs/cortex/contracts/{slug}/contract-{NNN+1}.md` using the contract template
     - Set contract title to `Repair: {slug} — {failing dimension(s)}`
     - Set contract `type: repair`
     - Update `.cortex/state.json`: `mode` → `repair`

  e. Append to the review artifact (the CODE REVIEW block):
     ```
     EVAL FAILURE REPAIR
     ────────────────────────────────────────────────
     Failing dimensions: {list}
     Repair recommendation: docs/cortex/evals/{slug}/repair-rec-{timestamp}.md
     {If P0: Repair contract: docs/cortex/contracts/{slug}/contract-{NNN+1}.md}
     ```

**If no failures found (all checkboxes checked or Results section is empty):**

  Update `docs/cortex/handoffs/eval-status.md` (create if it does not exist):
  - Record passing dimensions and timestamp
  - No repair recommendation written

  Append to the review artifact:
  ```
  EVAL STATUS
  ────────────────────────────────────────────────
  All checked dimensions: PASS
  ```

### Convergence Detector

Run this check when an active contract is loaded and the contract is in `repair` mode (or when reviewing repair contracts).

1. Scan `docs/cortex/contracts/{slug}/` for all contract files matching `contract-*.md`.
2. For each repair contract (contract-002.md and above), extract:
   - The `## Failed Approaches` section (if present)
   - The `## Validators` section results
   - The failing done criteria
3. Compare the failure signatures of the 3 most recent repair contracts:
   - Extract the set of failing validators/criteria from each
   - Compute similarity: count of shared failing items / total unique failing items
4. **If 3+ consecutive repair contracts share >80% similar failure signatures:**
   - Generate `docs/cortex/reviews/{slug}/convergence-stall-{timestamp}.md`:
     ```markdown
     # Convergence Stall Detected: {slug}

     **Timestamp:** {timestamp}
     **Contracts analyzed:** {list of contract filenames}
     **Similarity score:** {N}% across {M} consecutive repairs

     ## Repeated Failure Pattern

     The following failures appear in {M}+ consecutive repair contracts:
     {list of shared failing validators/criteria}

     ## Recommendation

     The repair loop is not converging. Consider:
     1. Re-running /cortex-clarify to reframe the problem
     2. Changing the implementation approach entirely
     3. Reducing scope to the subset that IS passing
     4. Escalating to human review of the architectural approach
     ```
   - Append `[BLOCK] convergence-stall — 3+ repair cycles with >80% similar failures detected. See convergence-stall-{timestamp}.md` to the review output.
   - Set `reclarify_required: true` in `.cortex/state.json`.

5. **If fewer than 3 repair contracts exist, or similarity is <80%:** No convergence stall — skip silently.

## Store Results

Output is always written as a repo-local artifact. Chat-only review responses do not satisfy this command.

After the CODE REVIEW block (including contract compliance section) is produced:

1. **Generate timestamp:** `YYYYMMDDTHHMMSSZ` (compact ISO UTC, e.g. `20260328T143012Z`)
2. **Slug:** use the resolved slug from Phase 0
3. **Target path:** `docs/cortex/reviews/{slug}/{timestamp}.md`
4. **Create directory:** `mkdir -p docs/cortex/reviews/{slug}/`
5. **Write** the full CODE REVIEW block (including contract compliance section) to the file.

**Update `docs/cortex/handoffs/current-state.md`:**
- `recent_artifacts`: append `docs/cortex/reviews/{slug}/{timestamp}.md`
- `blockers`: set if review verdict is `REQUEST CHANGES` with blocking issues
- `next_action`: reflect review verdict and contract compliance outcome

**Update `.cortex/state.json`:**
- Append review artifact path to the `artifacts` array.

**Output confirmation line:**
```
Review artifact written: docs/cortex/reviews/{slug}/{timestamp}.md
```
