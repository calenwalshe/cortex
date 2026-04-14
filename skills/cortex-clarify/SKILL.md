# Cortex Clarify — Problem Framing

Converts a fuzzy idea into a written problem frame (clarify brief). Required first step before any research or spec work begins. Produces a structured artifact and updates continuity state.

## User-invocable
When the user types `/cortex-clarify`, run this skill.
Also trigger when: "clarify this idea", "help me frame this", "what problem are we solving", "turn this into a brief", "write a clarify brief for".

## Arguments
- `/cortex-clarify <idea>` — the idea, problem, or feature as a quoted string or inline text (required)
- `--autonomy <preset>` — override the autonomy preset for this invocation only. Valid values: `supervised`, `gates-only`, `full-auto`. Passed to the resolver as the invocation layer (highest precedence in the 4-layer resolution).
- `--gate <name>=<bool>` — override a specific gate for this invocation only. Example: `--gate slug_conflict=false`. Can be repeated for multiple gates. Passed to the resolver as invocation-layer gate overrides.
- `--dry-run` — print the resolved autonomy gate table without executing any command logic, writing files, or modifying state.

### --dry-run Mode

If `--dry-run` is passed:
1. Resolve autonomy config using `resolveAutonomyWithSources` from `scripts/cortex/resolve-autonomy.js`
2. Print the resolved gate table showing gate name, value, and source layer for all 13 gates
3. Print which gates this specific command checks (cortex-clarify checks `slug_conflict`)
4. Do NOT execute any command logic, write any files, or modify any state
5. Exit after printing the table

## Instructions

### Phase 1: Derive slug

**Distill the idea into a short, memorable identifier** — not a kebab-cased sentence. The slug appears in file paths, state files, commit messages, and every future conversation that references this work. Aim for 2-4 words that name the essence of the change.

**How to distill:**
1. Read the idea and identify the core noun phrase or verb+object that names what's being done (e.g., "rate limiter", "hook loader", "auth middleware")
2. If context is ambiguous, add ONE scope qualifier (e.g., `tavily-rate-limiter`, `sessionstart-hook-loader`)
3. Lowercase, hyphen-separate words, strip non-alphanumeric

**Slug shape test (critical):**
- **Rule of thumb:** If the slug exceeds ~40 characters, you have kebab-cased the sentence instead of distilling it — re-distill.
- ✓ Good: `smart-retry-logic`, `tavily-rate-limiter`, `sessionstart-token-budget`, `auth-middleware-rewrite`
- ✗ Bad (kebab-cased prose): `add-a-rate-limiter-to-the-tavily-provider-in-power-search`
- ✗ Bad (too generic, loses context): `rate-limiter`, `hook`, `retry`

**Examples (input → output):**
- `"add smart retry logic to the API client"` → `smart-retry-logic`
- `"rewrite the auth middleware to use JWT instead of sessions"` → `jwt-auth-middleware`
- `"improve the onboarding flow so new users reach the first value moment within 90 seconds"` → `onboarding-flow`
- `"migrate the analytics pipeline from Airflow to Prefect because the DAG authoring experience is hostile"` → `airflow-to-prefect-migration`

The idea text's length has no bearing on the slug's length. Distill aggressively. If you cannot distill without losing essential disambiguation, add one scope qualifier and stop — do not include the full prose.

Record the slug — it is used in all subsequent steps.

### Phase 2: Check prerequisite state

Read `.cortex/state.json`.

**Autonomy gate check (`slug_conflict`):**
Before evaluating slug conflict, resolve the autonomy config:
1. Read `.cortex/autonomy.json` (project-level) and `~/.claude/cortex-autonomy.json` (global-level) if they exist.
2. Determine the active preset (default: `supervised` if no config found).
3. Look up `gates.slug_conflict` in the resolved config. If `--autonomy` or `--gate` flags were provided, use them as the invocation layer (highest precedence in the 4-layer resolution). Resolution order: invocation flags > project config > global config > preset defaults. Mandatory gates (`ux_taste_eval`, `human_action`, `reclarify`) are always forced true regardless of config.
4. If `gates.slug_conflict` is `false`: **skip the slug conflict check entirely** — auto-proceed without warning or asking confirmation.
   When auto-proceeding (gate is false/skipped), append a decision log entry to `docs/cortex/handoffs/decisions.md` under the `## Autonomy Decisions` section:
   ```
   - {ISO8601 timestamp} | gate: slug_conflict | value: false (auto-skipped) | preset: {active_preset} | command: /cortex-clarify
   ```
5. If `gates.slug_conflict` is `true` (or no autonomy config exists): evaluate the slug conflict check as described below (existing behavior preserved).

- If `slug` field is already set to a **different** active slug AND the `slug_conflict` gate is active (per autonomy check above): render a gate brief and ask to confirm.

  Read `.cortex/state.json` to get the current slug, mode, and approval_status. Render:

  ```
  ════════════════════════════════════════
  GATE: Slug Conflict
  ════════════════════════════════════════

  Would switch active slug from "{current_slug}" ({current_mode}) to "{new_slug}".
    - Current: {current_slug} (mode: {current_mode}, status: {current_approval_status})
    - New: {new_slug} (will start in clarify mode)
    - Existing artifacts for {current_slug} remain on disk

  Details: .cortex/state.json
  ════════════════════════════════════════
  ```

  Then present an AskUserQuestion:
  - **header:** "Slug"
  - **question:** "Switch to new slug? Current work context will be overwritten."
  - **options:**
    - "Confirm" — proceed with the new slug
    - "Cancel" — keep current slug, abort clarify
    - "Show details" — print current state.json, then re-prompt
- If the file does not exist, proceed without warning.
- If `slug` matches the derived slug, proceed without warning.

### Phase 2b: Read system-map.md (if available)

If `docs/cortex/system-map.md` exists, read the **Crosscutting Conventions** and **Key Decisions** sections before populating the clarify brief. Use the conventions to pre-populate constraints (architectural invariants belong in the brief's `## Constraints` section) and use key decisions to avoid re-litigating settled choices in open questions.

If `docs/cortex/system-map.md` does not exist, skip this step and proceed without error.

### Phase 2c: Read structural graph (if available)

If `.cortex/structural/` exists and contains JSON files, read all entries and inject a compact structural excerpt before populating the clarify brief. The excerpt surfaces actual function definitions and import patterns from the Cortex Python codebase, so constraints and open questions can reference real symbols rather than guessing.

**Steps:**
1. Run reconciliation: for each `.cortex/structural/*.json` entry, verify `source_path` still exists on disk; skip stale entries (do not error on them).
2. For each valid entry, produce one compact line: `{basename} ({lines}L): imports=[top-3], fns=[top-5]`
3. Prefix the excerpt with `### Structural Context (auto-indexed):` and include it in your working context before writing the brief.

Soft-fail: if `.cortex/structural/` does not exist or contains no valid entries, log a note ("no structural context available") and proceed without error. The distilled layer (system-map.md) remains sufficient.

### Phase 2d: Read operational context (if available)

Run the operational indexer to get hotspot and co-change context from the edit ledger:

```bash
python3 "$CLAUDE_PROJECT_DIR/scripts/cortex/operational-indexer.py" --summary 2>/dev/null \
  || echo '{"hotspots":[],"co_change_pairs":[],"caveat":"ledger absent"}'
```

Parse the JSON output. If `hotspots` is non-empty, inject a compact section into your working context before writing the clarify brief:

```
### Operational Context (auto-indexed):
Hotspots (most-edited): {top-3 file_path entries with edit_count}
Co-change pairs (edited together): {top-3 pairs with session_count}
Caveat: {caveat field from JSON}
```

Use hotspot files to inform the **Write Roots** section of the clarify brief — files edited frequently are likely write roots. Use co-change pairs to flag potential coupling risks in **Open Questions**.

Soft-fail: if the command fails, outputs invalid JSON, or `hotspots` is empty, log "no operational context available" and proceed without error. Never block the pipeline on ledger absence.

### Phase 3: Populate clarify brief

Read the template at `templates/cortex/clarify-brief.md`.

Fill all fields:

| Field | What to write |
|-------|---------------|
| `{SLUG}` | Derived slug from Phase 1 |
| `{TIMESTAMP}` | Current UTC time as `YYYYMMDDTHHMMSSZ` (compact, filesystem-safe) |
| `{STATUS}` | `draft` |
| `{IDEA}` | Verbatim user input — do not paraphrase |
| `{GOAL}` | One sentence outcome: what success looks like when this idea is fully realized |
| `{NON_GOALS}` | Explicit list of things this work will NOT cover. Each item starts with `- ` |
| `{CONSTRAINTS}` | Hard limits that must be respected (technical, business, timeline, regulatory). Each starts with `- `. **Auto-inject:** If `docs/cortex/intent/owner-intent.md` exists, read its Non-Negotiables section and prepend each as a standing constraint (prefixed with `[owner-intent]`). These appear in every clarify brief automatically. |
| `{ASSUMPTIONS}` | Things assumed true without verification. Each starts with `- ` |
| `{OPEN_QUESTIONS}` | Actionable questions that must be answered before research begins. Each starts with `- ` |
| `{NEXT_RESEARCH_STEPS}` | Ordered numbered agenda for `/cortex-research --phase concept` |

**If the idea is too sparse to derive non-goals, constraints, or open questions:** ask the user clarifying questions before writing. Do not silently leave fields empty.

**Classify open questions for research routing.** Populate the YAML frontmatter `questions:` array at the top of the clarify brief. For each item in `## Open Questions`, create an entry with `id` (sequential: q1, q2, ...), `text` (the question verbatim), and `type` (one of the 5-type taxonomy below).

**5-type question taxonomy** (used by `/cortex-research` for provider routing):

| Type | When to use | Example |
|------|-------------|---------|
| `factual` | Specific answer with citations needed | "What LoCoMo score does Letta achieve?" |
| `landscape` | Broad survey of what exists in a space | "What AI memory systems exist?" |
| `mechanism` | How a specific system or pattern works | "How does MemGPT's tiered hierarchy work?" |
| `comparison` | Trade-offs between alternatives | "MemGPT vs Mem0 vs Zep for file-based storage?" |
| `codebase` | Internal project analysis (not web research) | "Where does Cortex lose context between sessions?" |

Classification rules:
1. Multi-intent questions are **decomposed into separate typed sub-questions** (Anthropic multi-agent decomposition pattern). Example: "How does X work and what are the alternatives?" becomes two entries: one `mechanism`, one `comparison`.
2. If a question's type is genuinely ambiguous, default to `factual` (the cheapest routing path). A misclassification to `factual` is cheap; misclassification to `mechanism` is expensive.
3. Populate the same classifications into the `## Next Research Steps` section if the research step corresponds directly to an open question.

### Phase 4: Write artifact

Construct the output path:
```
docs/cortex/clarify/{slug}/{timestamp}-clarify-brief.md
```

Steps:
1. Create the directory if it does not exist:
   ```bash
   mkdir -p docs/cortex/clarify/{slug}/
   ```
2. Write the populated template to the target path.

Output is always a repo-local artifact. Chat-only responses do not satisfy this command.

### Phase 4b: Auto-write current-understanding.md

After writing the clarify brief, check for and conditionally write `current-understanding.md`:

1. Check if `docs/cortex/research/{slug}/current-understanding.md` already exists.
2. **If it does NOT exist:**
   a. Read `templates/cortex/current-understanding.md`.
   b. Read brief YAML frontmatter `initial_terminal_set:` — if absent, default to all six non-transitional terminals: `commit-to-build`, `kill-with-learning`, `decompose`, `experiment-required`, `already-exists`, `hold-on-dependency`.
   c. Read brief YAML frontmatter `ruled_out:` — if absent, default to `[]`.
   d. Populate the Possible Terminals table: status = `live` for terminals in `initial_terminal_set`, status = `ruled-out` for terminals in `ruled_out`. Ruled-Out Reason and Evidence blank for live rows.
   e. Fill YAML frontmatter: `slug: {slug}`, `brief_iteration: 1`, `last_updated: {today}`.
   f. Populate Iteration History with the current brief as iteration 1 (dossier = TBD, reframe reason = "(initial)").
   g. Create directory if needed: `mkdir -p docs/cortex/research/{slug}/`
   h. Write to `docs/cortex/research/{slug}/current-understanding.md`.
   i. Append path to `recent_artifacts` in continuity state (Step 5 below).
3. **If it already exists:** No-op. Updates to existing `current-understanding.md` are out of scope for this pilot (deferred to a follow-up slug).

### Phase 4c: Extract vault facts from clarify brief

After writing the clarify brief (Phase 4) and current-understanding.md (Phase 4b), call the vault extractor to persist typed facts before updating continuity state:

```bash
python3 scripts/cortex/cortex-vault-extractor.py \
  --artifact docs/cortex/clarify/{slug}/{timestamp}-clarify-brief.md \
  --slug {slug}
```

Soft-fail: if the extractor exits non-zero or is not found, log a warning and continue. Do not block Phase 4d or Phase 5.

### Phase 4d: Invoke cortex-critique

After writing the clarify brief (Phase 4), current-understanding.md (Phase 4b), and extracting vault facts (Phase 4c), invoke cortex-critique on the clarify brief before updating continuity state:

```
/cortex-critique --artifact docs/cortex/clarify/{slug}/{timestamp}-clarify-brief.md --gate clarify --slug {slug}
```

This runs adversarial AI review of the brief, persists findings to `docs/cortex/reviews/{slug}/critique-clarify.md`, and writes a gate receipt to `.cortex/state.json`.

**Failure handling:** If cortex-critique is not available or returns a non-zero exit, record `CRITIQUE_FAILED` in the gate receipt and proceed. Critique failure must not block the pipeline.

### Phase 5: Update continuity state

**Update `docs/cortex/handoffs/current-state.md`:**

| Field | Value |
|-------|-------|
| `slug` | Derived slug |
| `mode` | `clarify` |
| `approval_status` | `pending` |
| `active_contract_path` | (none) |
| `recent_artifacts` | Append `docs/cortex/clarify/{slug}/{timestamp}-clarify-brief.md` |
| `open_questions` | List from brief |
| `blockers` | (none unless discovered) |
| `next_action` | `Run /cortex-research --phase concept to begin concept research` |

**Update `.cortex/state.json`:**

| Field | Value |
|-------|-------|
| `slug` | Derived slug |
| `mode` | `clarify` |
| `approval_status` | `pending` |
| `active_contract` | `null` |
| `artifacts` | Append `docs/cortex/clarify/{slug}/{timestamp}-clarify-brief.md` |
| `gates.clarify_complete` | `true` |
| `gates.research_complete` | `false` (unchanged) |
| `gates.spec_complete` | `false` (unchanged) |
| `gates.pr_opened` | `false` |
| `gates.pr_merged` | `false` |
| `github` | `{ "pr_number": null, "pr_url": null, "issue_number": null, "branch": null }` |

## Rules

- Does not start research or spec — the clarify brief is a prerequisite artifact only.
- Does not modify GSD planning state (`.planning/`, `STATE.md`).
- The clarify brief is the required gate to `/cortex-research`. Research cannot begin without one.
- Output is always written as a repo-local artifact — chat-only responses do not satisfy this command.

## Output Format

After completing all phases, output a terminal summary:

```
CLARIFY BRIEF WRITTEN
════════════════════════════════════════
Slug:    {slug}
Path:    docs/cortex/clarify/{slug}/{timestamp}-clarify-brief.md
Status:  draft

Open questions ({N}):
  - {question 1}
  - {question 2}

Next: /cortex-research --phase concept
════════════════════════════════════════
```
