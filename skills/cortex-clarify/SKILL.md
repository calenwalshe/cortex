# Cortex Clarify — Problem Framing

Converts a fuzzy idea into a written problem frame (clarify brief). Required first step before any research or spec work begins. Produces a structured artifact and updates continuity state.

## User-invocable
When the user types `/cortex-clarify`, run this skill.
Also trigger when: "clarify this idea", "help me frame this", "what problem are we solving", "turn this into a brief", "write a clarify brief for".

## Arguments
- `/cortex-clarify <idea>` — the idea, problem, or feature as a quoted string or inline text (required)

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

- If `slug` field is already set to a **different** active slug, warn the user and ask to confirm before overwriting the active context.
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
| `{CONSTRAINTS}` | Hard limits that must be respected (technical, business, timeline, regulatory). Each starts with `- ` |
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
