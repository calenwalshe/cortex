# Phase 3: New and Updated Skills - Research

**Researched:** 2026-03-28
**Domain:** Claude Code SKILL.md prompt engineering — command design, artifact writing, continuity state management
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CMD-01 | `/cortex-clarify` converts fuzzy idea into clarify brief at `docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md` | Template at `templates/cortex/clarify-brief.md` is complete; slug derivation and file path conventions fully defined in COMMANDS.md |
| CMD-02 | `/cortex-research` supports `--phase concept|implementation|evals` and `--depth quick|standard|deep` flags; writes to `docs/cortex/research/<slug>/<phase>-<timestamp>.md` | Existing SKILL.md uses legacy `--quick`/`--deep` flags and `~/research/` path; new interface is a targeted rewrite of arguments + output routing |
| CMD-03 | `/cortex-spec` compresses clarify + research into `spec.md`, `gsd-handoff.md`, `contract-001.md`, `eval-plan.md` at `docs/cortex/specs/<slug>/` and `docs/cortex/contracts/<slug>/` | Templates for all four outputs exist and are complete; command is a synthesis orchestrator |
| CMD-04 | `/cortex-investigate` writes investigation artifacts to `docs/cortex/investigations/<slug>/<timestamp>.md` + updates `current-state.md` | Existing SKILL.md has full investigative protocol but no artifact-writing behavior; needs output routing added |
| CMD-05 | `/cortex-review` writes to `docs/cortex/reviews/<slug>/<timestamp>.md`; adds contract compliance lens | Existing SKILL.md has multi-lens review but no artifact writing and no contract compliance section; both are additive |
| CMD-06 | `/cortex-audit` writes to `docs/cortex/audits/<slug>/<timestamp>.md` | Existing SKILL.md has full 7-lens audit protocol but writes nothing; needs output routing added |
| CMD-07 | `/cortex-status` reconstructs state from `docs/cortex/handoffs/current-state.md` + `.cortex/state.json`; outputs continuity summary + next-prompt refresh | Existing SKILL.md runs system health checks only; requires a complete behavioural replacement |
</phase_requirements>

---

## Summary

Phase 3 creates or rewrites 7 SKILL.md files. The substrate (templates, directory scaffolding, `.cortex/state.json`, all continuity handoff files) was fully built in Phase 2. Phase 3's job is to wire command behaviors on top of that substrate.

The SKILL.md format is a pure prompt/instruction file — no code, no imports. Each file has a consistent structure: User-invocable section (trigger phrase + aliases), Arguments section, Instructions section (numbered phases), Output format, and any integration notes. The 5 existing skills demonstrate this pattern clearly and must be preserved as reference for style consistency.

The key split is **new skills vs. updated skills**. `cortex-clarify` and `cortex-spec` are net-new (no existing SKILL.md). `cortex-status` requires a complete behavioral replacement — the current version checks API connectivity and upstream versions, the new version reads repo-local artifacts to reconstruct continuity state. The other four (`cortex-research`, `cortex-investigate`, `cortex-review`, `cortex-audit`) have strong existing behavioral content that must be preserved and extended, not replaced.

**Primary recommendation:** Treat each skill as a discrete atomic task. Preserve all existing behavioral content in the updated skills — add artifact-writing output sections rather than rewriting protocols. For `cortex-status`, treat it as a new skill authored from scratch that happens to reuse the same filename.

---

## Standard Stack

### SKILL.md Format (observed from all 5 existing skills)

| Element | Pattern | Example (from cortex-audit) |
|---------|---------|----------------------------|
| Header line | `# Cortex {Name} — {Tagline}` | `# Cortex Security Audit` |
| User-invocable block | Trigger phrase + alias triggers | `When the user types /cortex-audit` |
| Arguments section | `/command` variants with `--flag` syntax | `--comprehensive`, `--diff`, `--quick` |
| Instructions section | Numbered or phased protocol | Phase 0 through Phase 6 |
| Output format | Inline code block with template | `SECURITY POSTURE REPORT` block |
| Integration notes | Cross-skill references (optional) | `GSD /gsd:debug manages session state` |

### Artifact Writing Pattern (derived from templates)

Skills that write artifacts follow this pattern in their instructions:

1. Determine the slug (from argument or current active slug in `.cortex/state.json`)
2. Determine the timestamp (ISO 8601 UTC)
3. Construct the output path from the slug and timestamp
4. Create the directory if it does not exist
5. Copy the relevant template and populate all fields
6. Update `docs/cortex/handoffs/current-state.md` to record the new artifact in `recent_artifacts`
7. Update `.cortex/state.json` if a gate should be flipped (e.g., `clarify_complete: true`)

### Slug Derivation Convention

From COMMANDS.md: "The slug is derived from the idea text." The convention (inferred from all templates) is lowercase, hyphenated, no special characters. Example: `"add smart retry logic to the API client"` → `smart-retry-logic`.

---

## Architecture Patterns

### Skill Categories by Change Type

#### Category A: New Skills (no existing SKILL.md)

**cortex-clarify** — Fully new. Takes the idea argument, derives a slug, populates `templates/cortex/clarify-brief.md`, writes to `docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md`, flips `.cortex/state.json` → `clarify_complete: true`, updates `current-state.md`.

**cortex-spec** — Fully new. No arguments. Reads clarify brief and all research dossiers for the active slug. Populates four templates (`spec.md`, `gsd-handoff.md`, `contract-001.md`, `eval-plan.md`). Writes them to their respective paths. Sets mode to `spec` in `current-state.md`. Does NOT call GSD — explicitly documented in COMMANDS.md as a hard rule.

#### Category B: Behavioral Extension (existing protocol preserved, artifact writing added)

**cortex-investigate** — Preserve the 5-phase Iron Law protocol entirely. Add: (a) write DEBUG REPORT to `docs/cortex/investigations/<slug>/<timestamp>.md`, (b) optionally write repair contract to `docs/cortex/contracts/<slug>/contract-NNN.md`, (c) update `current-state.md` with new artifact path.

**cortex-review** — Preserve existing multi-lens review protocol. Add: (a) required contract compliance section that reads the active contract from `current-state.md` → `active_contract_path` and checks done criteria against findings, (b) write full review to `docs/cortex/reviews/<slug>/<timestamp>.md`.

**cortex-audit** — Preserve existing CSO audit protocol. The 7 required lenses in REQUIREMENTS.md (auth, data, secrets, unsafe tools, input validation, deps, misuse) align exactly with OWASP Top 10 scope already in the skill. Add: write Security Posture Report to `docs/cortex/audits/<slug>/<timestamp>.md`.

**cortex-research** — The most invasive update. Replace legacy `--quick`/`--deep` flags with `--phase concept|implementation|evals` and `--depth quick|standard|deep`. Replace output path `~/research/processed/briefs/` with `docs/cortex/research/<slug>/<phase>-<timestamp>.md`. Preserve all underlying tool invocations (Tavily, Jina, Perplexity, Gemini, gpt-researcher). Note: `--phase evals` produces an eval proposal, which maps to `templates/cortex/eval-proposal.md`, not the standard research dossier.

#### Category C: Behavioral Replacement

**cortex-status** — Current SKILL.md checks API keys, upstream git versions, and Python package installations. The new version must: (a) read `.cortex/state.json`, (b) read `docs/cortex/handoffs/current-state.md`, (c) scan `docs/cortex/` for all written artifacts to reconstruct history, (d) produce a continuity summary to terminal, (e) write updated `current-state.md` and `next-prompt.md`. The old system-health behavior is completely retired in this version (it belongs to the old Cortex architecture).

### Recommended File Structure for Phase 3 Output

```
skills/
├── cortex-clarify/
│   └── SKILL.md          (NEW)
├── cortex-research/
│   └── SKILL.md          (UPDATED — flag and path changes)
├── cortex-spec/
│   └── SKILL.md          (NEW)
├── cortex-investigate/
│   └── SKILL.md          (UPDATED — add artifact writing + current-state update)
├── cortex-review/
│   └── SKILL.md          (UPDATED — add artifact writing + contract compliance)
├── cortex-audit/
│   └── SKILL.md          (UPDATED — add artifact writing)
└── cortex-status/
    └── SKILL.md          (BEHAVIORAL REPLACEMENT)
```

### current-state.md Update Protocol

Every skill that produces an artifact MUST update `current-state.md`. The fields to touch:

| Field | When to update |
|-------|---------------|
| `slug` | Set by `cortex-clarify` from the idea argument |
| `mode` | Updated as phases progress (clarify → research → spec → ...) |
| `recent_artifacts` | Append every artifact path produced |
| `open_questions` | `cortex-clarify` writes initial list; cleared as resolved |
| `blockers` | Updated by any skill that surfaces a hard blocker |
| `next_action` | Updated by every skill to reflect the recommended next step |

### .cortex/state.json Gate Protocol

Skills flip gates when their primary artifact is written:

| Skill | Gate to flip |
|-------|-------------|
| `cortex-clarify` | `clarify_complete: true` |
| `cortex-research` | `research_complete: true` (when at least one dossier exists) |
| `cortex-spec` | `spec_complete: true` |
| Contract approval | `contract_approved: true` (human approval, not a skill — Phase 4) |

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Artifact output format | Custom per-skill template syntax | Templates at `templates/cortex/` | All templates are complete with field schemas — writing inline format in SKILL.md doubles the maintenance surface |
| Slug derivation logic | Bespoke per-skill rule | Consistent rule: lowercase, hyphen-separated, strip special chars | Already specified in COMMANDS.md; all skills must use the same convention |
| Phase progression logic | Conditional flow in SKILL.md | Read `.cortex/state.json` gates | Phase gates are already modeled in state.json; skills read them, not re-derive them |
| next-prompt construction | Free-text in each skill | `templates/cortex/next-prompt.md` | Template defines the exact fields; `cortex-status` populates it, not individual skills |

---

## Common Pitfalls

### Pitfall 1: Writing chat responses instead of artifact files

**What goes wrong:** A skill produces the correct content in the chat window but does not write a file to `docs/cortex/`. The artifact requirement is not satisfied, and `current-state.md` does not get updated.

**Why it happens:** Existing SKILL.md instructions (investigate, review, audit) produce terminal-style output blocks (DEBUG REPORT, CODE REVIEW, SECURITY POSTURE REPORT) without any file-writing step.

**How to avoid:** Every skill that produces an artifact must have an explicit "Write to file" step in its Instructions section — before the output format block, not after it. The step must include the full target path.

**Warning signs:** SKILL.md ends at the output format block with no subsequent write instruction.

### Pitfall 2: Losing existing behavioral content in updated skills

**What goes wrong:** The Iron Law protocol (cortex-investigate), multi-lens review (cortex-review), or CSO audit phases (cortex-audit) are trimmed or summarized when adding artifact writing — the skill becomes weaker.

**Why it happens:** Adding new sections to long SKILL.md files creates pressure to shorten existing content.

**How to avoid:** Add artifact-writing steps as a new terminal section ("Output to File" or "Store Results"), not by replacing or compressing existing instructions.

### Pitfall 3: cortex-status reading from wrong source

**What goes wrong:** The new cortex-status reads from `.planning/STATE.md` (GSD state) instead of `docs/cortex/handoffs/current-state.md` (Cortex continuity state).

**Why it happens:** The old cortex-status referenced `.planning/` for GSD status. REQUIREMENTS.md explicitly prohibits Cortex writing to `.planning/`.

**How to avoid:** cortex-status reads from exactly two sources: `docs/cortex/handoffs/current-state.md` and `.cortex/state.json`. It does not read `.planning/` at all.

### Pitfall 4: cortex-spec auto-invoking GSD

**What goes wrong:** cortex-spec runs GSD commands (e.g., `/gsd:plan-phase`) automatically after writing `gsd-handoff.md`.

**Why it happens:** The logical next step after `gsd-handoff.md` exists is to import into GSD. A skill that tries to be helpful might do this inline.

**How to avoid:** COMMANDS.md is explicit: "Does NOT auto-invoke GSD. The human must explicitly import `gsd-handoff.md` into GSD as a separate step." cortex-spec must stop at writing the file and surfacing its path.

### Pitfall 5: cortex-research writing evals output to the wrong template

**What goes wrong:** `--phase evals` produces a research dossier (using `templates/cortex/research-dossier.md`) instead of an eval proposal (using `templates/cortex/eval-proposal.md`).

**Why it happens:** All other `--phase` values produce dossiers; evals is the exception.

**How to avoid:** The Instructions section for `--phase evals` must branch explicitly to the eval-proposal template and write to `docs/cortex/evals/<slug>/eval-proposal.md`, not `docs/cortex/research/<slug>/`.

### Pitfall 6: Missing current-state.md update in artifact-writing skills

**What goes wrong:** A skill writes its artifact but does not update `current-state.md`. After `/clear`, `cortex-status` reports stale state and misses the recent artifact.

**Why it happens:** Artifact writing is added as a step, but `current-state.md` maintenance is not.

**How to avoid:** Every skill that writes an artifact must include a mandatory final step: "Update `docs/cortex/handoffs/current-state.md`" with specific fields to modify.

---

## Code Examples

Verified patterns from existing templates and SKILL.md files:

### Slug Derivation (from idea text)
```
# Pattern observed across templates and COMMANDS.md
Input:  "add smart retry logic to the API client"
Output: smart-retry-logic

Rules:
- lowercase everything
- replace spaces and non-alphanumeric chars with hyphens
- collapse consecutive hyphens to one
- strip leading/trailing hyphens
```

### Artifact Path Construction
```
# clarify-brief output path
docs/cortex/clarify/{slug}/{timestamp}-clarify-brief.md

# research dossier output path
docs/cortex/research/{slug}/{phase}-{timestamp}.md

# spec output paths
docs/cortex/specs/{slug}/spec.md
docs/cortex/specs/{slug}/gsd-handoff.md

# contract output path
docs/cortex/contracts/{slug}/contract-001.md

# investigation output path
docs/cortex/investigations/{slug}/{timestamp}.md

# review output path
docs/cortex/reviews/{slug}/{timestamp}.md

# audit output path
docs/cortex/audits/{slug}/{timestamp}.md

# evals output paths (--phase evals)
docs/cortex/evals/{slug}/eval-proposal.md
```

### current-state.md Update (example for cortex-clarify)
```markdown
# After writing the clarify brief, update current-state.md:
slug: {derived-slug}
mode: clarify
approval_status: pending
active_contract_path: (none)
recent_artifacts:
- docs/cortex/clarify/{slug}/{timestamp}-clarify-brief.md
open_questions:
- {questions from brief}
blockers: (none)
next_action: Run /cortex-research --phase concept to begin research
```

### .cortex/state.json Update (example for cortex-clarify)
```json
{
  "slug": "{derived-slug}",
  "mode": "clarify",
  "approval_status": "pending",
  "active_contract": null,
  "artifacts": [
    "docs/cortex/clarify/{slug}/{timestamp}-clarify-brief.md"
  ],
  "approvals": { "contract": false, "evals": false },
  "gates": {
    "clarify_complete": true,
    "research_complete": false,
    "spec_complete": false,
    "contract_approved": false
  }
}
```

### cortex-status Terminal Output Format (from COMMANDS.md)
```
Outputs:
- Updated docs/cortex/handoffs/current-state.md
- Updated docs/cortex/handoffs/next-prompt.md
- Terminal summary: current slug, mode, open questions, blockers, next recommended action
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `cortex-research --quick` / `--deep` flags | `--depth quick|standard|deep` + `--phase concept|implementation|evals` | Phase-scoped dossiers instead of monolithic briefs |
| Research output to `~/research/processed/briefs/` | Output to `docs/cortex/research/<slug>/<phase>-<timestamp>.md` | Project-local, versionable, slug-scoped |
| `cortex-status` = system health check | `cortex-status` = continuity reconstruction | Works after `/clear` with no chat history |
| No artifact writing in investigate/review/audit | All three write to `docs/cortex/` subdirectories | Artifacts survive session resets |
| No `cortex-clarify` command | New command as required gate before research | Explicit problem framing before any downstream work |
| No `cortex-spec` command | New command that synthesizes clarify + research into GSD-ready pack | Clean handoff boundary between Cortex intelligence and GSD execution |

---

## Open Questions

1. **Slug source for investigation/review/audit when no active slug exists**
   - What we know: These commands take an optional `<subject>` or `<target>` argument. The active slug comes from `.cortex/state.json`.
   - What's unclear: If state.json has `slug: null` (initial state), what slug should be used for the output path?
   - Recommendation: Skills should derive a slug from the subject/target argument when no active slug is set, using the same slugification rule. If no argument either, block and prompt the user to run `/cortex-clarify` first.

2. **cortex-research --phase evals relationship to cortex-spec**
   - What we know: `--phase evals` produces an eval proposal at `docs/cortex/evals/<slug>/eval-proposal.md`. cortex-spec writes `eval-plan.md` but the spec template references it.
   - What's unclear: Does cortex-spec also produce `eval-proposal.md`, or only `eval-plan.md`? REQUIREMENTS.md says cortex-spec produces "eval-plan.md" (ART-07). The eval proposal is listed as ART-06 from `cortex-research --phase evals`.
   - Recommendation: cortex-spec writes `eval-plan.md` only. The eval proposal comes from cortex-research. This matches the ART-06/ART-07 split in REQUIREMENTS.md.

3. **Timestamp format**
   - What we know: Templates use `{TIMESTAMP}` described as "ISO 8601 UTC". File paths use `<timestamp>` without specification.
   - What's unclear: Whether file path timestamps should be the full ISO string (`2026-03-28T14:32:00Z`) or a compact form (`20260328T143200Z`) for cross-platform path safety.
   - Recommendation: Use compact form `YYYYMMDDTHHMMSSZ` for file path components (no colons, filesystem-safe). Use full ISO 8601 in template metadata fields.

---

## Validation Architecture

### Test Framework

No test framework is installed in the cortex project (no jest.config, no pytest.ini, no test/ directory). Skills are SKILL.md prompt files — their correctness is validated by invocation and artifact inspection, not unit tests.

| Property | Value |
|----------|-------|
| Framework | None (prompt-only artifacts, no executable code) |
| Config file | none |
| Quick run command | `ls docs/cortex/clarify/ docs/cortex/research/ docs/cortex/specs/ docs/cortex/contracts/ docs/cortex/investigations/ docs/cortex/reviews/ docs/cortex/audits/` |
| Full validation | Manual invocation of each command and inspection of output artifacts |

### Phase Requirements to Validation Map

| Req ID | Behavior | Test Type | Validation Method | Infrastructure Exists? |
|--------|----------|-----------|-------------------|----------------------|
| CMD-01 | `/cortex-clarify` produces clarify brief at correct path with all sections | manual-smoke | Invoke command, verify file exists at `docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md`, spot-check sections | No SKILL.md yet |
| CMD-02 | `/cortex-research` accepts `--phase` and `--depth` flags, writes correct path | manual-smoke | Invoke with each `--phase` value, verify path contains `<phase>-<timestamp>.md` | SKILL.md exists (update) |
| CMD-03 | `/cortex-spec` produces 3 artifacts at correct paths without invoking GSD | manual-smoke | Invoke with clarify + research prereqs, verify spec.md / gsd-handoff.md / contract-001.md exist | No SKILL.md yet |
| CMD-04 | `/cortex-investigate` writes artifact to `docs/cortex/investigations/` + updates current-state.md | manual-smoke | Invoke, verify file written, verify `recent_artifacts` in current-state.md updated | SKILL.md exists (update) |
| CMD-05 | `/cortex-review` writes artifact to `docs/cortex/reviews/` with contract compliance section | manual-smoke | Invoke, verify file written with compliance section | SKILL.md exists (update) |
| CMD-06 | `/cortex-audit` writes artifact to `docs/cortex/audits/` covering all 7 lenses | manual-smoke | Invoke, verify file written, spot-check 7 lenses present | SKILL.md exists (update) |
| CMD-07 | `/cortex-status` reads current-state.md + state.json and outputs accurate summary | manual-smoke | Invoke after `/clear` simulation (with known artifact state), verify output matches repo state | SKILL.md exists (replace) |

### Sampling Rate

- **Per task:** Invoke the modified or new skill against a test scenario; verify artifact written to correct path with required sections
- **Per wave:** Run all 7 commands in sequence (clarify → research → spec, then investigate/review/audit, then status) against a single test slug; verify complete artifact trail in `docs/cortex/`
- **Phase gate:** All 7 commands produce expected artifacts before marking phase complete

### Wave 0 Gaps

None — there is no automated test infrastructure and none is required. Validation is manual artifact inspection. The project has no package dependencies that would provide a test runner, and skills are prompt files, not executable code.

---

## Sources

### Primary (HIGH confidence)

- `skills/cortex-research/SKILL.md` — existing command structure, tool invocations, output format
- `skills/cortex-investigate/SKILL.md` — existing Iron Law protocol (5 phases) to preserve
- `skills/cortex-review/SKILL.md` — existing multi-lens review protocol to preserve
- `skills/cortex-audit/SKILL.md` — existing CSO audit protocol (6 phases + confidence gate) to preserve
- `skills/cortex-status/SKILL.md` — existing (to be replaced) system health check behavior
- `docs/COMMANDS.md` — canonical interface spec for all 7 commands, flags, outputs, rules
- `templates/cortex/` — all 13 artifact templates with complete field schemas
- `.planning/REQUIREMENTS.md` — phase requirement IDs and acceptance criteria
- `docs/CONTINUITY.md` — current-state.md schema, resume protocol, .cortex/state.json gate model
- `.cortex/state.json` — actual runtime state structure (confirmed schema)
- `docs/cortex/handoffs/current-state.md` — live handoff file (confirmed seeded)

### Secondary (MEDIUM confidence)

- `.planning/ROADMAP.md` — phase goal and success criteria
- `templates/cortex/next-prompt.md` — field definitions for restart prompt

---

## Metadata

**Confidence breakdown:**
- SKILL.md format conventions: HIGH — 5 existing files provide unambiguous patterns
- Artifact paths: HIGH — all paths canonically defined in COMMANDS.md and templates
- Behavioral preservation rules: HIGH — existing skills are fully readable; additive vs. replacement split is clear
- cortex-status replacement scope: HIGH — old behavior is entirely system-health; new behavior is entirely continuity; no overlap
- Slug source for no-active-slug edge case: MEDIUM — inferred from conventions, not explicitly documented

**Research date:** 2026-03-28
**Valid until:** 2026-04-28 (stable domain — these are internal prompt files with no external dependencies)
