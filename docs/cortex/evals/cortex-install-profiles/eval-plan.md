# Eval Plan: cortex-install-profiles

<!-- ART-07: Eval Plan Template — written after human approval of the eval proposal -->

**Slug:** cortex-install-profiles
**Timestamp:** 20260330T235900Z
**Approved By:** project lead (user)
**Approved At:** 20260330T235900Z

---

## Approved Dimensions

- Functional Correctness
- Regression
- Integration
- Safety / Security
- Style
- UX / Taste

---

## Fixtures Per Dimension

### Fixtures: Functional Correctness
- Clean `~/.claude/skills/` directory with no pre-existing tool skill symlinks (or isolated tmp dir)
- `runtime-manifest.json` in migrated schema form with both framework and tool skill entries
- `skills/web/SKILL.md`, `skills/ai/SKILL.md`, `skills/google/SKILL.md`, `skills/cli/SKILL.md` present in repo

### Fixtures: Regression
- Baseline: `bash test/installer.test.sh` exits 0 before any changes
- A `~/.claude/skills/web/` real directory (not symlink) — simulates user who installed tool skills manually

### Fixtures: Integration
- Two sequential install runs against the same `~/.claude/skills/` dir:
  1. `node bin/install.js --profile=core`
  2. `node bin/install.js --profile=full`
- State captured and verified after each run independently

### Fixtures: Safety / Security
- Grep pattern list: `TAVILY_API_KEY`, `PPLX_API_KEY`, `FIRECRAWL_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`, `SLACK_TOKEN`, `GOOGLE_CREDENTIALS`
- Targets: captured stdout of `node bin/install.js --profile=core`; all `skills/{web,ai,google,cli}/SKILL.md` files

### Fixtures: Style
- Existing `bin/install.js` as style reference
- Standard Markdown lint for `DOWNSTREAM.md`

### Fixtures: UX / Taste
- Captured stdout of `node bin/install.js --profile=core`
- Captured stdout of `node bin/install.js --profile=full`

---

## Thresholds Per Dimension

### Threshold: Functional Correctness
**Pass:** All 9 done criteria in `contract-001.md` pass when validators are run exactly as written.
**Fail:** Any single done criterion is not met.

### Threshold: Regression
**Pass:** `bash test/installer.test.sh` exits 0 with zero failures; `node bin/install.js` (no flags) produces no error.
**Fail:** Any previously-passing test case fails, or running with no flags errors.

### Threshold: Integration
**Pass:** After core→full sequence: all framework and tool skill symlinks exist, `.cortex-profile` contains `full`, no errors during either run.
**Fail:** Any error during multi-run sequence, or symlink/marker state is inconsistent with the requested profile.

### Threshold: Safety / Security
**Pass:** Zero grep matches for any API key env var name in core-profile stdout. Zero embedded credential values in any committed SKILL.md file.
**Fail:** Any match — even one — is a blocking P0 failure.

### Threshold: Style
**Pass:** No style issues that would block a code review merge.
**Fail:** Style inconsistencies that require a fix before the PR can land.

### Threshold: UX / Taste
**Pass:** Human reviewer approves both output formats as clear and actionable — core output is terse with no API key noise; full output includes complete API key setup guidance.
**Fail:** Human reviewer finds either output confusing, incomplete, or likely to generate a support question.

---

## Run Instructions

1. **Pre-flight:** Confirm `bash test/installer.test.sh` exits 0 on the unmodified baseline.

2. **Functional Correctness — core profile:**
   ```bash
   node bin/install.js --dry-run --profile=core
   # Verify: output lists only cortex-* skills; no web/ai/google/cli
   node bin/install.js --profile=core
   # Verify: ~/.claude/.cortex-profile contains "core"
   # Verify: no tool skill symlinks in ~/.claude/skills/
   ```

3. **Functional Correctness — full profile:**
   ```bash
   node bin/install.js --dry-run --profile=full
   # Verify: output lists all skills including web/ai/google/cli
   node bin/install.js --profile=full
   # Verify: ~/.claude/.cortex-profile contains "full"
   # Verify: tool skill symlinks exist in ~/.claude/skills/
   ```

4. **Functional Correctness — no-flag default:**
   ```bash
   node bin/install.js
   # Verify: behaves identically to --profile=core
   ```

5. **Regression:**
   ```bash
   bash test/installer.test.sh
   # Must exit 0 with all tests passing
   ```

6. **Integration — upgrade sequence (core → full):**
   ```bash
   node bin/install.js --profile=core
   # Capture state: symlinks present, .cortex-profile = "core"
   node bin/install.js --profile=full
   # Verify: tool skill symlinks added, framework symlinks intact, .cortex-profile = "full", no errors
   ```

7. **Safety / Security:**
   ```bash
   node bin/install.js --profile=core 2>&1 | grep -E "TAVILY_API_KEY|PPLX_API_KEY|FIRECRAWL_API_KEY|GEMINI_API_KEY|OPENAI_API_KEY|SLACK_TOKEN|GOOGLE_CREDENTIALS"
   # Must produce zero output
   grep -rE "TAVILY_API_KEY|PPLX_API_KEY|FIRECRAWL_API_KEY|GEMINI_API_KEY|OPENAI_API_KEY" skills/web/SKILL.md skills/ai/SKILL.md skills/google/SKILL.md skills/cli/SKILL.md
   # Must produce zero embedded credential values (env var names are OK; actual key strings are not)
   ```

8. **Style:**
   - Read `bin/install.js` additions against existing patterns — indentation, naming, comment style
   - Run Markdown lint on `DOWNSTREAM.md`
   - Run shellcheck on `test/installer.test.sh`

9. **UX / Taste (human review):**
   ```bash
   node bin/install.js --profile=core
   # Capture and review: is output terse and actionable? No API key noise?
   node bin/install.js --profile=full
   # Capture and review: does output include complete API key setup guidance?
   ```
   Record human approval in Results below.

10. **Validators (from contract-001.md):**
    ```bash
    ls skills/web/SKILL.md skills/ai/SKILL.md skills/google/SKILL.md skills/cli/SKILL.md
    ls DOWNSTREAM.md
    node bin/install.js --profile=core && cat ~/.claude/.cortex-profile
    node bin/install.js --profile=full && cat ~/.claude/.cortex-profile
    ```

---

## Results

- [ ] Functional Correctness — pending
- [ ] Regression — pending
- [ ] Integration — pending
- [ ] Safety / Security — pending
- [ ] Style — pending
- [ ] UX / Taste — pending
