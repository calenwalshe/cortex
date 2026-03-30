# Cortex Stash — Idea Capture

Zero-friction capture of tangential ideas during active Cortex work. Stores ideas as per-entry files in `.cortex/stash/` so they survive `/clear`, slug transitions, and project completions. Promotes into `/cortex-clarify` when the time is right.

## User-invocable

When the user types `/cortex-stash`, run this skill.

Also trigger when the user says:
- "stash this idea"
- "save that for later"
- "add to cortex stash"
- "what's in the stash"
- "review the stash"

## Arguments

- `/cortex-stash add "idea" --context "..."` — capture a new idea
- `/cortex-stash add "idea" --no-context` — capture without context (no prompt)
- `/cortex-stash list` — list all stash entries with age and staleness flags
- `/cortex-stash show <id>` — print a single entry in full
- `/cortex-stash review` — print all entries sorted oldest-first
- `/cortex-stash promote <id>` — emit as `/cortex-clarify` invocation, then delete entry
- `/cortex-stash discard <id>` — preview entry, confirm, delete

If called with no subcommand, default to `list`.

---

## Instructions

### Stash file location and naming

All entries live in `.cortex/stash/` relative to the project root (the directory containing `.cortex/`). Create the directory if it does not exist.

File name pattern: `{id}-{label}.md`
- `id` — compact UTC timestamp: `YYYYMMDDTHHMMSSz` (e.g. `20260330T143000Z`)
- `label` — short kebab-case slug derived from the first 5 words of the idea text (e.g. `verifier-harness-reuse`)

Use the template at `~/projects/cortex/templates/cortex/stash-entry.md` for the file structure.

### YAML front matter schema

```yaml
---
id: "20260330T143000Z"
captured: "2026-03-30T14:30:00Z"   # ISO 8601
context: "one sentence: what was happening when this idea surfaced"
disposition: explore                 # always 'explore' at capture; updated at triage
---
```

Body: the idea text, one or more sentences.

---

### `/cortex-stash add`

**With `--context "..."`:**
1. Generate `id` from current UTC time.
2. Derive `label` from first 5 words of idea text, kebab-cased.
3. Write `.cortex/stash/{id}-{label}.md` using the template.
4. Confirm: `Stashed as {id}-{label}.md — run /cortex-stash review to triage later.`

**Without `--context` and without `--no-context`:**
1. Before writing, ask: `Context (one sentence — what were you working on when this came up)?`
2. Wait for the user's answer.
3. Proceed as above with the provided context.

**With `--no-context`:**
1. Write the entry with `context: ""`.
2. No prompt. Proceed directly.

---

### `/cortex-stash list`

Scan `.cortex/stash/` for all `.md` files. For each entry:
1. Parse YAML front matter to get `id`, `captured`, `context`, `disposition`.
2. Compute age in days from `captured` to today.
3. Read first line of body as the idea summary.

Output format (one line per entry):
```
{id}  [{age}d{STALE flag}]  {first line of idea, truncated to 60 chars}
      context: {context, truncated to 80 chars}
```

`[STALE]` flag: append ` STALE` inside the brackets if age > 90 days, e.g. `[95d STALE]`.

If no entries: `Stash is empty.`

---

### `/cortex-stash show <id>`

Find the file matching `id` (prefix match on filename is fine — `2026033` matches `20260330T143000Z-...`).

Print the full file contents including YAML front matter and body.

If not found: `No stash entry matching '{id}'.`

---

### `/cortex-stash review`

Print all entries in full, sorted oldest-first (ascending by `captured`).

Separate each entry with `---`.

If no entries: `Stash is empty.`

---

### `/cortex-stash promote <id>`

1. Find the file matching `id`.
2. Read the idea body text.
3. Output:

```
/cortex-clarify "{idea body text}"

⚠️  Entry {id} has been removed from the stash.
    Run the command above before /clear — it will not be recoverable after this session ends.
```

4. Delete the entry file using the Bash tool: `rm .cortex/stash/{filename}`
5. Do NOT output a second confirmation after deletion — the warning above is sufficient.

If not found: `No stash entry matching '{id}'.`

---

### `/cortex-stash discard <id>`

1. Find the file matching `id`.
2. Print the full entry content as a preview.
3. Ask: `Discard this entry? (yes/no)`
4. If yes: delete the file with `rm .cortex/stash/{filename}`. Confirm: `Discarded {id}.`
5. If no: `Cancelled — entry kept.`

If not found: `No stash entry matching '{id}'.`

---

## Rules

- Stash operations **never** modify `.cortex/state.json` mode, slug, or approval fields.
- Stash operations **never** modify `docs/cortex/handoffs/current-state.md`.
- `add` is the only subcommand that creates files. All others are read-only except `promote` and `discard`, which delete files.
- `disposition` is set at triage (`review`), not at capture. At capture it is always `explore`.
- Never silently drop the `context` field — always prompt if omitted and `--no-context` not passed.
