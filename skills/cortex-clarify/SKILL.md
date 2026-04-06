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

Slugify the `<idea>` argument:
1. Lowercase everything
2. Replace spaces and non-alphanumeric characters with hyphens
3. Collapse consecutive hyphens to one
4. Strip leading and trailing hyphens

**Example:**
- Input: `"add smart retry logic to the API client"`
- Output: `smart-retry-logic`

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
