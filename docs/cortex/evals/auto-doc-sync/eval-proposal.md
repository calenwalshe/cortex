# Eval Proposal: auto-doc-sync

<!-- ART-06: Eval Proposal Template — produced by /cortex-research --phase evals -->

**Slug:** auto-doc-sync
**Timestamp:** 20260402T002000Z
**Status:** approved

---

## Proposed Dimensions

### 1. Functional correctness — INCLUDE
**Applies because:** The hook has a multi-stage pipeline (filter → classify → detect conflicts → LLM call → parse → write) with branching logic at each stage. Each branch must produce the correct output: skip, warn, or write the correct target file with correct content.
**approval_required:** false

### 2. Regression — INCLUDE
**Applies because:** The contract modifies `bin/install.js` (existing installer), `runtime-manifest.json` (existing manifest), and `docs/HOOKS.md` (existing documentation). Existing installer tests and `verify-fast.sh` must continue to pass.
**approval_required:** false

### 3. Integration — INCLUDE
**Applies because:** The hook integrates: git staging area (read), Anthropic Messages API (external HTTP), filesystem (read config + read/write docs), and the installer pipeline (settings.json wiring). Each integration boundary is a failure surface.
**approval_required:** false

### 4. Safety/security — INCLUDE
**Applies because:** The hook reads `ANTHROPIC_API_KEY` from the environment and sends it in HTTP headers. It parses untrusted JSON from an external API and writes the parsed content to local files. A malformed API response could inject unexpected content into documentation files.
**approval_required:** false

### 5. Performance — INCLUDE
**Applies because:** The contract specifies latency constraints: single batched call (not sequential), 5-second developer bypass threshold, `--max-time 30` curl timeout. The heuristic classifier must add negligible overhead. Performance failure = developers bypass the hook.
**approval_required:** false

### 6. Resilience — INCLUDE
**Applies because:** The hook depends on an external API (Anthropic) that can timeout, return errors, return malformed JSON, or be unreachable. Every failure path must soft-fail (exit 0, warning to stdout). The hook must never block a commit due to API issues.
**approval_required:** false

### 7. Style — INCLUDE
**Applies because:** Deliverables include shell script (`hooks/auto-doc-sync.sh`), JSON config (`.auto-doc-sync.json`), Markdown template (`hooks/auto-doc-sync-prompt.md`), shell tests, and documentation. Shell script must pass `shellcheck`. JSON must pass `jq empty`.
**approval_required:** false

### 8. UX/taste — INCLUDE
**Applies because:** The hook produces user-facing terminal output: unified diffs of proposed doc changes, skip notices, architectural change warnings, and soft-fail messages. The quality of these messages directly affects whether developers trust and use the hook or bypass it. The generated documentation content is human-readable prose that will appear in committed docs.
**approval_required:** true

---

## Fixtures

### Fixtures: Functional correctness
- A test git repo with staged changes to a `skills/cortex-clarify/SKILL.md` file (add a new argument row)
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

## Rubrics

### Rubric: Functional correctness
Pass: every pipeline branch (skip, warn, write) produces the documented output for the documented input. All 16 done criteria from the contract pass. Fail: any done criterion fails, or any branch produces incorrect output.

### Rubric: Regression
Pass: `bash test/installer.test.sh` and `bash scripts/verify-fast.sh` produce identical pass/fail results before and after the change. `node bin/install.js --dry-run` produces valid output including the new hook. Fail: any existing test fails or installer output is malformed.

### Rubric: Integration
Pass: hook successfully reads git staging area, calls API, parses response, and writes to the correct file — end-to-end with a real or realistically mocked API. Each integration boundary handles errors without crashing. Fail: any integration boundary produces an unhandled error or incorrect data flow.

### Rubric: Safety/security
Pass: API key never appears in stdout, log files, or written artifacts. Malicious API response content is either sanitized or written verbatim to the target doc (stage-for-review means the human reviews before committing — the hook is not responsible for sanitizing doc content, but it must not write outside designated paths). Path traversal in API response does not cause writes outside write roots. Fail: key leakage, writes outside designated paths, or unhandled injection.

### Rubric: Performance
Pass: single-file commit completes hook execution in <5 seconds. 3-file commit uses exactly 1 API call and completes in <10 seconds. Heuristic classifier adds <100ms overhead. Fail: exceeds these thresholds consistently (3+ runs).

### Rubric: Resilience
Pass: every API failure scenario (unset key, timeout, HTTP error, malformed JSON) results in exit 0 with a human-readable warning. No commit is ever blocked by an API issue. Fail: any API failure scenario causes a non-zero exit or blocks the commit.

### Rubric: Style
Pass: `shellcheck` reports 0 errors (warnings acceptable if documented). JSON passes `jq empty`. Prompt template is valid Markdown with all required placeholders. Fail: `shellcheck` errors, invalid JSON, or missing placeholders.

### Rubric: UX/taste
Pass: stdout output is informative, concise, and actionable. Diff output uses standard unified diff format. Skip notices explain *why* the target was skipped. Generated doc content accurately reflects the source file change and reads naturally. Fail: output is confusing, verbose, or misleading; generated doc content is factually wrong or reads like LLM slop.

---

## Thresholds

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

## Failure Taxonomy

| Failure Category | Severity | Description | Repair Path |
|-----------------|----------|-------------|-------------|
| Wrong target file written | P0 | Hook writes doc content to a file not in the mapping config | Fix target resolution logic in `auto-doc-sync.sh`; add integration test for path mapping |
| API key leaked to stdout | P0 | `ANTHROPIC_API_KEY` appears in hook's terminal output | Fix curl invocation to suppress verbose/trace output; add grep-based test |
| Commit blocked by API failure | P0 | Hook exits non-zero when API is unavailable | Fix soft-fail logic; ensure all error paths exit 0 |
| Incorrect doc content committed | P1 | Generated doc update contradicts the source file | Stage-for-review mode is the mitigation; if the hook itself stages the file, fix to remove `git add` |
| Batched call produces partial results | P1 | JSON response has valid update for file A but garbage for file B; file B's doc is corrupted | Fix response parser to validate per-target before writing; skip invalid targets |
| Heuristic false positive (skips when it shouldn't) | P2 | Comment-only heuristic incorrectly classifies a meaningful change as trivial | Tighten heuristic regex; add test cases for edge-case diffs |
| Heuristic false negative (calls LLM unnecessarily) | P3 | Heuristic misses a trivial change and makes an unnecessary API call | Wasted ~$0.0006; no functional impact; refine heuristic in next iteration |
| Slow hook execution | P2 | Hook takes >5s for single-file commit, causing developer bypass | Profile curl timing; check for unnecessary jq passes; consider model downgrade |
| Skip notice unclear | P3 | Developer doesn't understand why the hook skipped a target | Improve message text; no functional impact |

---

## Document-Level Approval Flag

**approval_required:** true

**Reviewer:** project lead

**Approval Status:** approved
