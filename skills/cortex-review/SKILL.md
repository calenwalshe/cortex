# Cortex Code Review — Multi-Lens Review

Combines Superpowers code review standards (no sycophancy, verify before implementing) with GStack's engineering and security review lenses.

## User-invocable
When the user types `/cortex-review`, run this skill.
Also trigger when: "review this", "review my code", "code review", "PR review", "review against contract", "contract review", "compliance review".

## Arguments
- `/cortex-review [<target>]` — file, PR, or component to review; defaults to current active contract scope
- `/cortex-review --security` — security-focused review only
- `/cortex-review --pr N` — review a specific PR number

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

**If `active_contract_path` was loaded (from Phase 0):**

For each done criterion in the contract, evaluate against the review findings and produce a line:
```
[PASS|FAIL|PARTIAL] <criterion> — <specific finding note>
```

For each validator in the contract, note whether it would pass based on review findings:
```
[PASS|FAIL] <validator> — <finding note>
```

State an overall compliance verdict:
```
CONTRACT COMPLIANCE: COMPLIANT | NON-COMPLIANT | PARTIALLY COMPLIANT
```

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
