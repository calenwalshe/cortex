# Eval Proposal: cortex-install-profiles

<!-- ART-06: Eval Proposal Template — produced by /cortex-research --phase evals -->

**Slug:** cortex-install-profiles
**Timestamp:** 20260330T235000Z
**Status:** draft

---

## Proposed Dimensions

### 1. Functional Correctness
**Applies because:** Always mandatory. Core deliverable is installer behavior: profile-gated skill filtering, marker file creation, and API key instruction gating. All outcomes are mechanically verifiable.
**approval_required:** false
**Decision:** INCLUDE

### 2. Regression
**Applies because:** Existing `bin/install.js` is modified, `runtime-manifest.json` schema is migrated from `string[]` to `Array<{name, profiles}>`, and `test/installer.test.sh` is extended. Existing users running `node bin/install.js` (no flag) must get `--profile=core` behavior without breakage. The `ensureSymlink()` behavior for existing tool skill directories must be preserved.
**approval_required:** false
**Decision:** INCLUDE

### 3. Integration
**Applies because:** Multiple components interact in sequence: `bin/install.js` reads `runtime-manifest.json`, applies profile filter, creates symlinks in `~/.claude/skills/`, and writes `~/.claude/.cortex-profile`. Re-run idempotency (full-after-core, core-after-full) spans all three components. `test/installer.test.sh` is the integration harness.
**approval_required:** false
**Decision:** INCLUDE

### 4. Safety / Security
**Applies because:** The contract's core profile constraint is a security/policy requirement: the core install must contain zero references to external API keys, tool SDKs, or network endpoints — safe to commit to a corporate repo. Verifiable by grepping installer output and core-profile SKILL.md files for known API key strings (`TAVILY_API_KEY`, `PPLX_API_KEY`, `FIRECRAWL_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`).
**approval_required:** false
**Decision:** INCLUDE

### 5. Performance
**Applies because:** No latency, throughput, or resource usage thresholds are specified in the contract. The installer is a one-time local CLI operation.
**Decision:** EXCLUDE

### 6. Resilience
**Applies because:** The installer has no network dependencies at runtime; it reads local files and creates local symlinks. No retry, timeout, or failure recovery paths are in scope.
**Decision:** EXCLUDE

### 7. Style
**Applies because:** New and modified deliverables include: `bin/install.js`, `runtime-manifest.json`, `skills/web/SKILL.md`, `skills/ai/SKILL.md`, `skills/google/SKILL.md`, `skills/cli/SKILL.md`, `test/installer.test.sh`, `DOWNSTREAM.md`. Code and documentation style are reviewable.
**approval_required:** false
**Decision:** INCLUDE

### 8. UX / Taste
**Applies because:** The installer produces terminal output that users read after running it. The profile-aware summary (API key instructions gated on `--profile=full`) is user-facing output. What the installer says — and does not say — for the core profile is a user experience decision.
**approval_required:** true
**Decision:** INCLUDE

---

## Fixtures

### Fixtures: Functional Correctness
- A clean `~/.claude/skills/` directory (or tmp dir) with no pre-existing tool skill symlinks
- `runtime-manifest.json` in migrated schema form with both framework and tool skill entries
- `skills/web/SKILL.md`, `skills/ai/SKILL.md`, `skills/google/SKILL.md`, `skills/cli/SKILL.md` present in repo

### Fixtures: Regression
- Existing `test/installer.test.sh` passing state before the change (baseline)
- A `~/.claude/skills/web/` directory that is a real directory (not a symlink) — simulates a user who installed tool skills manually before the profile system existed

### Fixtures: Integration
- Two successive install runs: first `--profile=core`, then `--profile=full` against the same `~/.claude/skills/` directory
- Verify state after each run independently

### Fixtures: Safety / Security
- Grep targets: `TAVILY_API_KEY`, `PPLX_API_KEY`, `FIRECRAWL_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`, `SLACK_TOKEN`, `GOOGLE_CREDENTIALS`
- Files to scan: captured stdout from `node bin/install.js --profile=core` and all `skills/{web,ai,google,cli}/SKILL.md` files

### Fixtures: Style
- Baseline code style: existing `bin/install.js` patterns (no semicolons or consistent with existing style)
- `DOWNSTREAM.md` checked against standard Markdown lint rules

### Fixtures: UX / Taste
- Captured stdout from `node bin/install.js --profile=core`
- Captured stdout from `node bin/install.js --profile=full`
- The two outputs reviewed side-by-side for clarity and completeness of guidance

---

## Rubrics

### Rubric: Functional Correctness
Pass: all 9 done criteria in `contract-001.md` are met by automated validator runs.
Fail: any done criterion is not met (e.g. `--profile=core` creates a tool skill symlink, marker file absent, API key instructions appear in core output).

### Rubric: Regression
Pass: `bash test/installer.test.sh` exits 0 with all pre-existing test cases passing; no previously-working install path produces an error.
Fail: any previously-passing test case fails, or `node bin/install.js` (no flag) produces an error that the pre-change version did not.

### Rubric: Integration
Pass: after `--profile=core` then `--profile=full`: all framework and tool skill symlinks exist, no framework symlinks were removed during the upgrade, `.cortex-profile` contains `full`. After `--profile=full` then `--profile=core`: tool skill symlinks are removed (or left untouched per spec — verify against chosen behavior), framework symlinks intact, `.cortex-profile` contains `core`.
Fail: any symlink transition produces an error, or the marker file reflects the wrong profile.

### Rubric: Safety / Security
Pass: `grep` of captured core-profile install output finds zero matches for any known API key env var name. All `skills/{web,ai,google,cli}/SKILL.md` files contain no embedded API key values (env var names are acceptable; embedded secrets are not).
Fail: any API key value or external endpoint credential appears in core-profile stdout or in committed SKILL.md files.

### Rubric: Style
Pass: `bin/install.js` additions follow existing patterns (indentation, naming, comment style). `DOWNSTREAM.md` renders cleanly in GitHub Markdown preview. No lint errors in modified shell scripts.
Fail: obvious inconsistencies in code style that would require cleanup before merge, or `DOWNSTREAM.md` has broken formatting.

### Rubric: UX / Taste
Pass (human judgment): core profile output is terse and actionable — tells the user what was installed and what to do next without mentioning irrelevant API keys. Full profile output includes clear API key setup guidance. A first-time user reading either output knows what to do next.
Fail: core profile output is confusing, mentions missing tool skills as errors, or leaves the user uncertain about next steps. Full profile output omits required API key setup information.

---

## Thresholds

### Threshold: Functional Correctness
**Pass:** All 9 done criteria pass when validators are run exactly as written in `contract-001.md`.
**Fail:** Any single done criterion fails.

### Threshold: Regression
**Pass:** `bash test/installer.test.sh` exits 0 with zero test failures.
**Fail:** Any test failure, or any error produced by `node bin/install.js` (no flags) that was not present before the change.

### Threshold: Integration
**Pass:** All inter-component state is consistent after each install run. No errors during profile upgrade/downgrade.
**Fail:** Any error during a multi-run sequence, or symlink/marker file state is inconsistent with the profile that was requested.

### Threshold: Safety / Security
**Pass:** Zero matches on any API key env var scan of core-profile output. Zero embedded credential values in any committed file.
**Fail:** Any match — even one.

### Threshold: Style
**Pass:** No style issues that would block a code review merge.
**Fail:** Style issues that require a fix before the PR can land.

### Threshold: UX / Taste
**Pass:** Human reviewer approves both output formats as clear and actionable.
**Fail:** Human reviewer finds either output format confusing, incomplete, or likely to cause a support question.

---

## Failure Taxonomy

| Failure Category | Severity | Description | Repair Path |
|-----------------|----------|-------------|-------------|
| Wrong skills installed for profile | P0 | Core profile creates tool skill symlinks, or full profile omits framework skills | Fix profile filter logic in `bin/install.js`; re-run validators |
| Marker file not written | P0 | `~/.claude/.cortex-profile` absent or contains wrong profile name | Fix profile marker write in `bin/install.js` |
| Manifest schema break | P0 | `bin/install.js` fails to parse migrated `runtime-manifest.json` | Fix manifest consumer in `bin/install.js`; atomic commit with manifest |
| API keys visible in core output | P0 | `TAVILY_API_KEY` or similar appears in `--profile=core` stdout | Remove from `printSummary()` gate logic |
| Regression in existing tests | P1 | Previously-passing `installer.test.sh` cases fail | Diagnose which behavioral change broke the test; fix or update test with justification |
| Re-run idempotency failure | P1 | Full-after-core or core-after-full sequence errors | Fix symlink transition logic in `bin/install.js` |
| Tool skill SKILL.md missing from repo | P1 | `ls skills/web/SKILL.md` fails | Copy file from `~/.claude/skills/web/SKILL.md` into repo |
| DOWNSTREAM.md missing or incomplete | P2 | File absent or lacks `.arcconfig` template | Write `DOWNSTREAM.md` per spec section 7 step 6 |
| Style inconsistencies | P2 | Code or doc style does not match existing patterns | Address in same PR before merge |
| UX output unclear | P2 | Human reviewer flags installer output as confusing | Revise `printSummary()` output; re-submit for UX review |

---

## Document-Level Approval Flag

**approval_required:** true

<!-- UX/taste dimension requires human approval -->

**Reviewer:** project lead (user)

**Approval Status:** approved
