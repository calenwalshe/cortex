# Eval Plan: auto-doc-sync

<!-- ART-07: Eval Plan Template — written after human approval of the eval proposal -->

**Slug:** auto-doc-sync
**Timestamp:** 20260402T002500Z
**Approved By:** project lead
**Approved At:** 20260402T002500Z

---

## Approved Dimensions

- Functional correctness
- Regression
- Integration
- Safety/security
- Performance
- Resilience
- Style
- UX/taste

---

## Fixtures Per Dimension

### Fixtures: Functional correctness
- A test git repo with staged changes to `skills/cortex-clarify/SKILL.md` (add a new argument row)
- A test git repo with staged changes to `.claude/hooks/cortex-phase-guard.sh` (change trigger condition)
- A `.auto-doc-sync.json` with known mapping entries
- A mock `docs/COMMANDS.md` with a `## /cortex-clarify` section
- A mock `docs/HOOKS.md` with a `### cortex-phase-guard` section

### Fixtures: Regression
- Current passing state of `bash test/installer.test.sh`
- Current passing state of `bash scripts/verify-fast.sh`
- Current `bin/install.js` output from `--dry-run`

### Fixtures: Integration
- A real or mocked Anthropic API endpoint returning valid JSON
- A mocked Anthropic API endpoint returning HTTP 500
- A mocked Anthropic API endpoint returning invalid JSON
- A git repo with partially-staged files (both staged and unstaged changes)

### Fixtures: Safety/security
- API response containing markdown injection (`<!-- malicious -->`, `<script>` tags)
- API response containing path traversal attempts (`../../../etc/passwd`)
- Verify `ANTHROPIC_API_KEY` is never logged to stdout or written to any file

### Fixtures: Performance
- A commit touching 1 SKILL.md file (baseline latency)
- A commit touching 3 SKILL.md files simultaneously (batched call latency)
- A commit touching only comment lines in a SKILL.md (heuristic classifier should skip LLM)

### Fixtures: Resilience
- `ANTHROPIC_API_KEY` unset
- API call with `--max-time 1` to force timeout
- API returning `{"error": {"type": "overloaded_error"}}`
- API returning truncated/incomplete JSON

### Fixtures: Style
- `shellcheck hooks/auto-doc-sync.sh` output
- `jq empty .auto-doc-sync.json` output
- Verify prompt template contains all required placeholders

### Fixtures: UX/taste
- Captured stdout from a successful doc update (should show unified diff)
- Captured stdout from a skip-if-staged event (should explain why it skipped)
- Captured stdout from an API failure (should be informative, not cryptic)
- Sample generated doc content for a known SKILL.md change (human reviews quality)

---

## Thresholds Per Dimension

### Threshold: Functional correctness
**Pass:** All 16 contract done criteria pass.
**Fail:** Any done criterion fails.

### Threshold: Regression
**Pass:** `test/installer.test.sh` and `scripts/verify-fast.sh` produce zero new failures.
**Fail:** Any previously-passing test now fails.

### Threshold: Integration
**Pass:** End-to-end pipeline completes without unhandled errors for all fixture scenarios.
**Fail:** Any fixture scenario produces an unhandled error or incorrect data flow.

### Threshold: Performance
**Pass:** Single-file <5s, 3-file <10s, heuristic <100ms (median over 3 runs).
**Fail:** Any threshold exceeded on median of 3 runs.

### Threshold: Resilience
**Pass:** All 4 API failure fixtures result in exit 0 + warning.
**Fail:** Any fixture causes non-zero exit.

### Threshold: Safety/security
**Pass:** No key leakage, no writes outside write roots, no unhandled injection across all fixtures.
**Fail:** Any single occurrence of key leakage or out-of-scope write.

### Threshold: Style
**Pass:** `shellcheck` 0 errors, `jq empty` success, all template placeholders present.
**Fail:** Any `shellcheck` error, invalid JSON, or missing placeholder.

### Threshold: UX/taste
**Pass:** Human reviewer confirms: (a) stdout messages are clear and actionable, (b) generated doc content is factually accurate for 3+ test cases.
**Fail:** Human reviewer identifies factual inaccuracy in generated content or finds stdout output confusing.

---

## Run Instructions

1. Run `bash scripts/verify-fast.sh` to establish baseline (regression fixture).
2. Run `bash test/installer.test.sh` to establish baseline (regression fixture).
3. Run `node bin/install.js --dry-run` and save output (regression fixture).
4. Run `jq empty .auto-doc-sync.json` — must exit 0 (style).
5. Run `jq '. | length' .auto-doc-sync.json` — must return 22 (functional correctness).
6. Run `shellcheck hooks/auto-doc-sync.sh` — must report 0 errors (style).
7. Run `bash test/auto-doc-sync.test.sh` — all tests must pass (functional correctness, integration, resilience).
8. Run `bash scripts/verify-fast.sh` again — compare against step 1 baseline (regression).
9. Run `bash test/installer.test.sh` again — compare against step 2 baseline (regression).
10. Run `node bin/install.js --dry-run` — output must include auto-doc-sync hook (functional correctness).
11. Run `grep -rn 'ANTHROPIC_API_KEY' hooks/auto-doc-sync.sh` — verify key is only read from env, never echoed (safety/security).
12. Time a single-file commit with the hook active — must complete in <5s (performance).
13. Time a 3-file commit with the hook active — must complete in <10s and make exactly 1 API call (performance).
14. Set `SKIP_LLM_GITHOOK=1` and commit — hook must exit 0 immediately with no API call (functional correctness).
15. Unset `ANTHROPIC_API_KEY` and commit with a mapped file staged — hook must exit 0 with warning (resilience).
16. Human reviewer inspects stdout output from steps 12-13 for clarity and actionability (UX/taste).
17. Human reviewer inspects generated doc content from steps 12-13 for factual accuracy (UX/taste).
18. Verify `docs/HOOKS.md` contains `### auto-doc-sync` with all required subsections (functional correctness).

---

## Results

- [ ] Functional correctness — 
- [ ] Regression — 
- [ ] Integration — 
- [ ] Safety/security — 
- [ ] Performance — 
- [ ] Resilience — 
- [ ] Style — 
- [ ] UX/taste — 
