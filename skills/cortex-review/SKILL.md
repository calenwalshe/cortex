# Cortex Code Review — Multi-Lens Review

Combines Superpowers code review standards (no sycophancy, verify before implementing) with GStack's engineering and security review lenses.

## User-invocable
When the user types `/cortex-review`, run this skill.
Also trigger when: "review this", "review my code", "code review", "PR review".

## Arguments
- `/cortex-review` — full multi-lens review of staged/changed files
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

### 6. Handling Pushback

If the author disagrees with a finding:
- Verify against the codebase — you might be wrong
- If you were wrong: "Checked [X], you're correct. Withdrawing."
- If you're right: restate with technical evidence, reference tests/code
- Don't double down without evidence. Don't cave without evidence.
