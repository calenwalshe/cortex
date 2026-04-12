# Eval Proposal: clarify-research-loop

**Slug:** clarify-research-loop
**Timestamp:** 20260412T014421Z
**Status:** approved

> **Contract context:** clarify-research-loop-001 is a documentation + skill-prose pilot. Deliverables are markdown files (skill SKILL.md edits, new template, doc updates) plus a retroactive audit results file. No new code, no networked components, no auth, no performance thresholds. The eval dimensions reflect this: heavy on functional/regression/integration/style/UX, none on security/performance/resilience.

---

## Proposed Dimensions

### 1. Functional correctness — INCLUDED

**Applies because:** The contract has 14 done criteria and 16 validators. Each deliverable has a mechanically verifiable pass condition (file exists, grep matches, smoke test passes). The pre-pilot retroactive audit has a numeric pass criterion (≥60% of historical non-BUILD verdicts cleanly map to a finer terminal with confidence ≥0.7). All of these are functional correctness checks.
**approval_required:** false (mechanically verifiable)

### 2. Regression — INCLUDED

**Applies because:** The contract modifies four existing files: `templates/cortex/clarify-brief.md`, `~/.claude/skills/cortex-clarify/SKILL.md`, `~/.claude/skills/cortex-close/SKILL.md`, `docs/DISCOVERY_LOOP.md`, and `docs/cortex/handoffs/decisions.md`. Existing slugs that do not declare `initial_terminal_set:` in their brief frontmatter must continue to work. Existing `/cortex-close` invocations without the new flag must surface a clear validation error rather than silent failure or silent success. Existing `decisions.md` Archive Index entries (legacy entries lacking the `terminal:` field) must continue to parse and display correctly. The cortex-clarify skill must continue to write briefs as before for slugs that don't trigger Phase 4b (e.g., when current-understanding.md already exists).
**approval_required:** false (mechanically verifiable via grep/test on existing slugs)

### 3. Integration — INCLUDED

**Applies because:** Multiple components must compose end-to-end: (a) `cortex-clarify` writes a brief with frontmatter → reads frontmatter → writes `current-understanding.md`; (b) `cortex-close` reads the brief frontmatter to validate `--terminal {name}` against `ruled_out:` → writes the terminal value to `decisions.md`; (c) the dual SKILL.md locations (`~/.claude/skills/...` and `skills/...`) must remain in sync. The end-to-end pipeline (clarify → research → spec → close) must work with the new flow without regressing. The dogfood close of *this slug* via `/cortex-close --terminal commit-to-build` is itself the integration test.
**approval_required:** false (mechanically verifiable via end-to-end smoke test)

### 4. Safety/security — EXCLUDED

**Reason for exclusion:** The contract introduces no auth, no secrets handling, no input validation on user-controlled data flowing into a sensitive system, no privilege escalation paths, no network calls. All deliverables are markdown files and skill prose. The `--terminal {name}` flag accepts a value from a known closed set of seven strings — validation against the set is functional correctness, not security. There is no attack surface to evaluate.

### 5. Performance — EXCLUDED

**Reason for exclusion:** The contract specifies no latency, throughput, or resource thresholds. All file writes are O(small markdown). No hot path. No concurrency. The retroactive audit is a one-shot grep + manual classification — its runtime is minutes, not milliseconds.

### 6. Resilience — EXCLUDED

**Reason for exclusion:** No networked systems, no external dependencies, no retries, no failure recovery paths. The audit reads a local file and writes a local file. Skill changes are pure prose. There is no resilience surface.

### 7. Style — INCLUDED

**Applies because:** Every deliverable is a documentation or skill-prose artifact, and Cortex has established conventions for SKILL.md structure (Phase numbering, gate brief format, autonomy gate boilerplate), template structure (YAML frontmatter at top, mandatory sections, comment annotations), and Markdown well-formedness. The new artifacts must match these conventions or they will feel foreign in the codebase. Includes the retroactive audit results file having a consistent table schema.
**approval_required:** false (mechanically verifiable: markdownlint-style checks, grep for boilerplate sections, structural consistency with existing skill files)

### 8. UX/taste — INCLUDED

**Applies because:** The `current-understanding.md` template is a **user-facing surface** — the human reads it as their queryable answer to "what do I currently understand about this slug?" The DISCOVERY_LOOP.md §7 section is documentation that future contributors will read to learn the seven-terminal taxonomy. Both have UX implications: a confusing template will produce dormant docs (the failure mode this slug is reacting to), and a confusing taxonomy will produce wrong terminal classifications. The judgment-based done criteria in the contract ("readable and useful," "clear enough for a new contributor without prior context") explicitly map to UX/taste.
**approval_required:** **TRUE** (mandatory per skill rule: any UX/taste dimension forces document-level approval)

---

## Fixtures

### Fixtures: Functional correctness
- The current `.cortex/state.json` and `docs/cortex/handoffs/decisions.md` (for the retroactive audit input)
- A throwaway test slug (e.g., `eval-test-terminal-1`) used to smoke-test the new flow end-to-end without polluting real slug history
- The set of seven terminal slug strings as a fixture: `commit-to-build`, `kill-with-learning`, `decompose`, `experiment-required`, `already-exists`, `hold-on-dependency`, `reframe-and-continue`
- A mock brief with `ruled_out: [kill-with-learning]` for the negative validation test

### Fixtures: Regression
- At least 3 existing slug clarify briefs that lack `initial_terminal_set:` frontmatter (e.g., kalshi-adaptive-loop, eval-system-refactor archived briefs) — used to verify backward compatibility
- The current `decisions.md` Archive Index entries (legacy format without `terminal:` field) — used to verify they still parse
- The current `templates/cortex/clarify-brief.md` (pre-change snapshot) for diff comparison

### Fixtures: Integration
- A throwaway test slug walked through the full pipeline: `/cortex-clarify` → verify `current-understanding.md` is auto-written → `/cortex-close --terminal commit-to-build` → verify `decisions.md` line includes `terminal:` field
- Both copies of the modified SKILL.md files (`~/.claude/skills/...` and `skills/...`) for sync verification

### Fixtures: Style
- The pre-change versions of the modified SKILL.md files (for diff comparison against existing Phase numbering and boilerplate conventions)
- Existing Cortex templates (`templates/cortex/clarify-brief.md`, `templates/cortex/spec.md`, etc.) as reference for frontmatter style and section ordering

### Fixtures: UX/taste
- The populated `current-understanding.md` for *this slug* (`docs/cortex/research/clarify-research-loop/current-understanding.md`) as the canonical working example for human review
- The DISCOVERY_LOOP.md §7 Terminal States section text for human review
- The retroactive audit results file for human review of reasoning quality

---

## Rubrics

### Rubric: Functional correctness
**Pass:** All 16 contract validators return success. Specifically: all 5 `test -f` validators find the file; all 8 `grep -n` validators return at least one match; the dogfood close of this slug succeeds and writes a properly-formatted `decisions.md` line; the retroactive audit produces a results table with reasoning per row and meets the ≥60% threshold.
**Fail:** Any `test -f` returns missing-file; any `grep -n` returns zero matches for a required pattern; the dogfood close fails or produces a malformed line; the audit table is incomplete or fails the threshold.

### Rubric: Regression
**Pass:** Pre-existing clarify briefs without `initial_terminal_set:` frontmatter are still readable by the modified `cortex-clarify` skill (no error, no skipped phases). Pre-existing `decisions.md` entries without `terminal:` field are still parseable by any future tooling that reads decisions.md (e.g., `/cortex-close` does not crash on legacy lines). The dual SKILL.md locations are byte-identical after the change. Smoke-running `/cortex-clarify` on a fresh slug (no `initial_terminal_set` declared) defaults the Possible Terminals table to all six non-transitional terminals.
**Fail:** Any of the above breaks. Existing slugs cannot complete their lifecycle. Legacy entries throw parse errors. SKILL files drift between locations.

### Rubric: Integration
**Pass:** End-to-end pipeline on a fresh test slug succeeds: brief is written with default frontmatter → `current-understanding.md` is auto-written and contains a Possible Terminals table populated with all six terminals → `/cortex-close --terminal commit-to-build` succeeds → `decisions.md` line contains `terminal: commit-to-build`. Negative test: `/cortex-close --terminal kill-with-learning` is rejected on a brief with `ruled_out: [kill-with-learning]` with a clear error message.
**Fail:** Any step in the pipeline breaks; the negative test passes silently when it should reject; the rejection error message is unclear or missing.

### Rubric: Style
**Pass:** Modified SKILL.md files preserve existing Phase numbering and section structure (autonomy gate check, decision log entry boilerplate, gate brief format). New `current-understanding.md` template uses YAML frontmatter at top, mandatory sections in order, and comment annotations matching the style of `templates/cortex/clarify-brief.md` and `templates/cortex/spec.md`. New DISCOVERY_LOOP.md §7 matches the existing tone and depth of §1-§6. All Markdown is well-formed (no broken tables, no unclosed code blocks).
**Fail:** Phase numbering inconsistent or missing; new sections feel structurally foreign; YAML frontmatter malformed; broken Markdown.

### Rubric: UX/taste (REQUIRES HUMAN APPROVAL)
**Pass:** The populated `current-understanding.md` for this slug is read by the owner (or another developer who has not been part of the design conversations) and they can answer the questions "what do we currently understand about this slug?" and "which terminal are we heading toward?" without consulting any other artifact. The DISCOVERY_LOOP.md §7 Terminal States section is read by a new contributor with no prior context and they can correctly answer "what are the seven terminals and how do they relate to the necessity-gate verdicts?" The retroactive audit results file is read by the owner and they agree the reasoning per row is convincing rather than perfunctory.
**Fail:** The reader has to reconstruct context from other artifacts. Terminal definitions are confusing or overlap unclearly. The audit reasoning feels boilerplate or speculative. The owner does not feel the working example actually demonstrates the philosophy.

---

## Thresholds

### Threshold: Functional correctness
**Pass:** 16/16 contract validators pass. Retroactive audit ≥60% mapping rate. Dogfood close successful.
**Fail:** Any validator fails or audit threshold not met.

### Threshold: Regression
**Pass:** Zero regressions on the 3 fixture slugs (existing briefs still load, lifecycle completes). Dual SKILL.md locations byte-identical (`diff` returns empty). Default `current-understanding.md` populated correctly when brief lacks frontmatter.
**Fail:** Any fixture slug breaks; SKILL.md copies diverge; default population missing.

### Threshold: Integration
**Pass:** End-to-end smoke test passes on test slug. Negative test (ruled-out terminal rejection) passes with clear error.
**Fail:** End-to-end test fails at any step; negative test does not reject.

### Threshold: Style
**Pass:** All modified files maintain existing structural conventions (Phase numbering, frontmatter format, section ordering). All Markdown well-formed.
**Fail:** Structural drift; broken Markdown.

### Threshold: UX/taste
**Pass:** Owner explicitly approves all three fixtures (current-understanding.md for this slug, DISCOVERY_LOOP.md §7, audit results file) as readable and useful. The two judgment-based done criteria in the contract are checked by the owner.
**Fail:** Owner finds any of the three confusing, boilerplate, or unconvincing.

---

## Failure Taxonomy

| Failure Category | Severity | Description | Repair Path |
|-----------------|----------|-------------|-------------|
| Audit threshold not met (<60% mapping) | P0 | The 4→7 refinement does not hold against historical necessity verdicts; the model is empirically unsupported | Stop pilot. Re-clarify with the audit results as new informing context. The brief's iter-3 Goal sentence may need to be revised. |
| Validator missing-file or grep-no-match | P0 | A required deliverable was not produced | Repair contract: produce the missing deliverable; re-run validators |
| End-to-end integration test fails | P0 | The pipeline (clarify → close) does not work with the new flow | Repair contract: debug the integration; usually a sync issue between dual SKILL.md locations |
| Negative test fails (ruled-out terminal accepted) | P0 | Validation logic is missing or wrong | Repair contract: add or fix the validation in `/cortex-close` Phase 1 |
| Regression on existing slug brief | P1 | A backward-compat path was missed | Repair contract: add the missing default-handling branch |
| Dual SKILL.md drift | P1 | The `~/.claude/` and `skills/` copies diverged | Repair contract: re-sync the files; consider adding a pre-commit hook to enforce sync |
| UX/taste rejection by owner | P1 | The working example or §7 docs are confusing | Repair contract: rewrite the offending artifact; re-submit for owner review |
| Style inconsistency in SKILL.md | P2 | New Phase 4b or `--terminal` handling does not match existing Phase numbering or boilerplate | Repair contract: refactor to match conventions |
| Markdown well-formedness issues | P2 | Broken tables, unclosed code blocks, malformed YAML | Repair contract: fix in place |
| Audit reasoning feels boilerplate | P2 | The audit produces a table but the per-row reasoning is shallow | Repair contract: deepen reasoning with concrete evidence per row |
| Cosmetic naming inconsistency | P3 | Minor differences in field names, headers, or comments | Log and defer to next slug |

---

## Document-Level Approval Flag

**approval_required:** true

**Reviewer:** owner

**Approval Status:** approved

<!-- Required because UX/taste dimension is included; human approval is mandatory before /cortex-research --write-plan can produce the eval-plan.md -->
