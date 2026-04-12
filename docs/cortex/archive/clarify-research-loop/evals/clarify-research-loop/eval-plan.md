# Eval Plan: clarify-research-loop

**Slug:** clarify-research-loop
**Timestamp:** 2026-04-12T02:46:00Z
**Approved By:** owner
**Approved At:** 2026-04-12T02:46:00Z

> **Source proposal:** `docs/cortex/evals/clarify-research-loop/eval-proposal.md` (approved 2026-04-12)
> **Contract:** `docs/cortex/contracts/clarify-research-loop/contract-001.md` (clarify-research-loop-001, approved)

---

## Approved Dimensions

- **Functional correctness** — mechanically verifiable; 16 contract validators + retroactive audit threshold
- **Regression** — backward compatibility for existing slugs without `initial_terminal_set:` frontmatter and legacy `decisions.md` lines
- **Integration** — end-to-end clarify→close pipeline + dual SKILL.md sync + brief↔close coordination
- **Style** — structural correctness of skill files (Phase numbering, frontmatter, well-formed Markdown)
- **UX/taste** — `current-understanding.md` is owner-facing; DISCOVERY_LOOP.md §7 is contributor-facing (owner-approval required)

(Dimensions excluded: Safety/security, Performance, Resilience — see proposal for rationale.)

---

## Fixtures Per Dimension

### Fixtures: Functional correctness
- `.cortex/state.json` and `docs/cortex/handoffs/decisions.md` — input data for the retroactive audit
- Throwaway test slug `eval-test-terminal-1` — used to smoke-test the new flow end-to-end without polluting real slug history
- Closed terminal vocabulary (string fixture): `commit-to-build`, `kill-with-learning`, `decompose`, `experiment-required`, `already-exists`, `hold-on-dependency`, `reframe-and-continue`
- Mock test brief with `ruled_out: [kill-with-learning]` for negative validation test

### Fixtures: Regression
- 3 existing pre-change clarify briefs from closed slugs (e.g., `kalshi-adaptive-loop`, `eval-system-refactor`, `system-decomposition-map` from `docs/cortex/archive/`) — verifies backward compatibility for briefs lacking `initial_terminal_set:`
- Pre-change snapshot of `docs/cortex/handoffs/decisions.md` Archive Index entries (legacy lines lacking `terminal:` field)
- Pre-change snapshot of `templates/cortex/clarify-brief.md` for diff comparison
- Pre-change snapshots of both `cortex-clarify` and `cortex-close` SKILL.md copies for diff comparison

### Fixtures: Integration
- Throwaway test slug walked through full pipeline: `/cortex-clarify` → verify `current-understanding.md` is auto-written → `/cortex-close --terminal commit-to-build` → verify `decisions.md` line includes `terminal:` field
- Both copies of modified SKILL.md (`~/.claude/skills/cortex-{clarify,close}/SKILL.md` and `skills/cortex-{clarify,close}/SKILL.md`) for sync verification via `diff`
- This slug itself (`clarify-research-loop`) as the dogfood integration test — close via `/cortex-close --terminal commit-to-build` after all other deliverables complete

### Fixtures: Style
- Pre-change versions of modified SKILL.md files (for Phase numbering and boilerplate diff)
- `templates/cortex/clarify-brief.md`, `templates/cortex/spec.md`, `templates/cortex/contract.md` — reference for frontmatter style and section ordering conventions
- `docs/DISCOVERY_LOOP.md` §1-§6 — reference for tone and depth of new §7 section

### Fixtures: UX/taste
- `docs/cortex/research/clarify-research-loop/current-understanding.md` (the working example for *this* slug, populated from briefs and dossiers) — submitted for owner review
- `docs/DISCOVERY_LOOP.md` §7 Terminal States section text — submitted for owner review (and ideally a second-set-of-eyes from someone not in the design conversations)
- `docs/cortex/research/clarify-research-loop/audit-results-{timestamp}.md` — submitted for owner review of reasoning quality

---

## Thresholds Per Dimension

### Threshold: Functional correctness
**Pass:** All 16 contract validators return success. Specifically: 5 `test -f` checks find their files; 8 `grep -n` checks each return ≥1 match; the dogfood close of this slug succeeds and writes a properly-formatted `decisions.md` line; the retroactive audit produces a results table with reasoning per row and meets the **≥60% mapping rate at confidence ≥0.7** threshold.
**Fail:** Any validator returns failure; audit threshold not met; dogfood close malformed or absent.

### Threshold: Regression
**Pass:** All 3 fixture slug briefs load through the modified `/cortex-clarify` skill without error. `diff ~/.claude/skills/cortex-clarify/SKILL.md skills/cortex-clarify/SKILL.md` returns empty (byte-identical). Same for `cortex-close`. A fresh slug invocation of `/cortex-clarify` without `initial_terminal_set:` in the brief produces a `current-understanding.md` defaulted to all six non-transitional terminals. Legacy `decisions.md` lines (without `terminal:` field) are still parseable by `/cortex-close` (no crash, no error).
**Fail:** Any fixture slug breaks; SKILL.md copies diverge; default population missing or malformed; legacy line parsing crashes.

### Threshold: Integration
**Pass:** End-to-end smoke test on `eval-test-terminal-1` succeeds: brief written with default frontmatter → `current-understanding.md` auto-written with Possible Terminals table populated with all six non-transitional terminals → `/cortex-close --terminal commit-to-build` succeeds → `decisions.md` line contains `terminal: commit-to-build`. Negative test: `/cortex-close --terminal kill-with-learning` on the mock brief with `ruled_out: [kill-with-learning]` is rejected with a clear error message naming the field. Dogfood: this slug closes via `/cortex-close --terminal commit-to-build` and the resulting `decisions.md` line is correctly formatted.
**Fail:** Any pipeline step breaks; negative test does not reject (or rejects with unclear error); dogfood close fails or produces malformed line.

### Threshold: Style
**Pass:** Modified SKILL.md files preserve existing Phase numbering scheme (no skipped numbers, no out-of-order phases); the new Phase 4b in `cortex-clarify` follows the same prose structure as Phase 4 (numbered substeps, autonomy gate boilerplate where applicable); the new `--terminal` handling in `cortex-close` matches the existing argument-validation pattern used elsewhere in the skill set. New `templates/cortex/current-understanding.md` uses YAML frontmatter at top, mandatory sections in declared order, comment annotations matching style of `templates/cortex/clarify-brief.md`. New DISCOVERY_LOOP.md §7 matches existing tone and depth of §1-§6. All Markdown is well-formed (`mdformat --check` or equivalent — no broken tables, no unclosed code blocks, no malformed YAML).
**Fail:** Phase numbering skipped or out-of-order; structurally foreign sections; malformed Markdown; YAML frontmatter parse errors.

### Threshold: UX/taste (REQUIRES HUMAN APPROVAL)
**Pass:** Owner reads the populated `current-understanding.md` for this slug and explicitly confirms (a) they can answer "what do I currently understand about this slug?" and (b) they can answer "which terminal are we heading toward?" without consulting any other artifact. Owner reads DISCOVERY_LOOP.md §7 Terminal States and explicitly confirms a hypothetical new contributor with no prior context could understand the seven terminals and their mapping to necessity-gate verdicts. Owner reads the audit results file and explicitly confirms the per-row reasoning is convincing rather than perfunctory.
**Fail:** Any of the three fails owner review. Owner is asked to be specific about what failed (not "feels off") so the repair contract has actionable input.

---

## Run Instructions

1. **Pre-pilot (hard gate, no code changes yet):**
   - Read `docs/cortex/handoffs/decisions.md` and grep for all entries matching `gate: necessity | verdict:`
   - For each non-BUILD verdict, classify which of the seven terminals it should have mapped to in retrospect, with a confidence score (0.0–1.0) and 1-2 sentence reasoning
   - Write results to `docs/cortex/research/clarify-research-loop/audit-results-{ISO8601-timestamp}.md` as a Markdown table
   - **Compute the mapping rate:** count of rows where `confidence >= 0.7` and a clean terminal was assigned, divided by total non-BUILD verdicts
   - **Pass criterion:** mapping rate ≥ 60%
   - If pass: proceed to step 2. If fail: stop the pilot, capture the audit as evidence in a new clarify iteration, return to clarify mode

2. **Implementation phase (only after step 1 passes):**
   - Implement contract deliverables in the order specified by spec.md §7 Sequencing
   - After each deliverable, run its associated [external] validators from contract.md
   - Maintain dual SKILL.md sync (`~/.claude/skills/` and `skills/` copies must be byte-identical)

3. **Functional correctness checks:**
   - Run all 13 [external] validators from contract.md (`test -f` checks, `grep -n` checks)
   - All must return success
   - Confirm the audit results file contains the threshold-meeting mapping rate

4. **Regression checks:**
   - For each of 3 fixture slugs (`kalshi-adaptive-loop`, `eval-system-refactor`, `system-decomposition-map` from `docs/cortex/archive/`):
     - Verify the archived brief is still parseable by the modified `/cortex-clarify` skill (read-only check, do not write)
   - Run `diff ~/.claude/skills/cortex-clarify/SKILL.md skills/cortex-clarify/SKILL.md` — must be empty
   - Run `diff ~/.claude/skills/cortex-close/SKILL.md skills/cortex-close/SKILL.md` — must be empty
   - Spot-check that legacy `decisions.md` Archive Index lines (those missing `terminal:` field) still display correctly when listed

5. **Integration smoke test:**
   - Create a throwaway test slug `eval-test-terminal-1` via `/cortex-clarify`
   - Verify `docs/cortex/research/eval-test-terminal-1/current-understanding.md` was auto-written with the Possible Terminals table
   - Verify the table contains all six non-transitional terminals as live (none ruled out)
   - Run `/cortex-close --terminal commit-to-build` for the test slug
   - Verify `decisions.md` line for that close includes `terminal: commit-to-build`
   - **Negative test:** create a second test slug with a brief manually edited to include `ruled_out: [kill-with-learning]` in YAML frontmatter; attempt `/cortex-close --terminal kill-with-learning` and verify rejection with a clear error message
   - Clean up: archive both test slugs

6. **Style checks:**
   - Diff modified SKILL.md files against pre-change snapshots; visually verify Phase numbering preserved
   - Run a Markdown well-formedness check on all new and modified files (e.g., `mdformat --check` if available, or manual visual inspection of tables, code blocks, frontmatter)

7. **UX/taste review (REQUIRES OWNER):**
   - Submit the three UX fixtures (`current-understanding.md` for this slug, DISCOVERY_LOOP.md §7, audit results file) to the owner for explicit review
   - Owner answers each pass-criterion question with yes/no plus specific feedback if "no"
   - If any "no" responses: open repair contract with the specific feedback as the failure mode

8. **Dogfood close (final integration test):**
   - After all 7 above pass, run `/cortex-close --terminal commit-to-build` on this slug (`clarify-research-loop`)
   - Verify the resulting `decisions.md` line includes `terminal: commit-to-build`
   - This close is itself the most important integration test — the slug must use its own new mechanism

---

## Results

<!-- Results are written to docs/cortex/evals/clarify-research-loop/results-{timestamp}.md by the eval execution pipeline (cortex-eval-run) -->
<!-- All five approved dimensions must show "passed" before the contract advances to assure state -->
<!-- The retroactive audit results file is a separate artifact at docs/cortex/research/clarify-research-loop/audit-results-{timestamp}.md and is referenced by the functional correctness dimension -->
