# Reup — Session Snapshot Manager

Manage the per-project session snapshot that auto-persists working context across `/clear`, `/compact`, and session resume. The snapshot lives at `~/.claude/reup/{project-slug}.md` and is re-injected automatically at every `SessionStart`.

## User-invocable

When the user types `/reup`, run this skill.

Also trigger when the user says:
- "show the reup snapshot"
- "rebuild the snapshot"
- "clear the reup"
- "what's in the session snapshot"

## Arguments

- `/reup show` — print the current snapshot for this project
- `/reup rebuild` — force Claude to rewrite the snapshot with current session state
- `/reup clear` — delete the snapshot file for this project

If called with no subcommand, default to `show`.

## Instructions

### Derive the snapshot path

The snapshot file is at `~/.claude/reup/{slug}.md` where `{slug}` is the basename of the current working directory, lowercased, with non-alphanumeric characters replaced by `-`.

For `/home/agent` → slug is `agent` → path is `~/.claude/reup/agent.md`.

---

### `/reup show`

Read `~/.claude/reup/{slug}.md` and print its contents to the terminal.

If the file does not exist, say: "No snapshot found for `{slug}`. Run `/reup rebuild` to create one."

---

### `/reup rebuild`

Rewrite the snapshot file with current session knowledge. The file must conform to this schema:

```markdown
# Reup Snapshot: {slug}

_Last updated: {ISO8601 timestamp}_
_Project: {cwd}_

---

## Identity

One paragraph: what this project/session is doing, the core goal, and where we are in the work.
Cap: 800 characters.

---

## Key Decisions

Bulleted list of the most important decisions made in this session and their rationale.
Cap: 1200 characters.

---

## Open Blockers

Bulleted list of unresolved blockers, questions, or risks. Empty section if none.
Cap: 800 characters.

---

## File Pointers

Bulleted list of the most important files touched or relevant in this session, with one-line purpose each.
Cap: 800 characters.

---

## Recent Work

Chronological log of work done. Each entry starts with `### {timestamp}`.
Cap: 4000 characters. Oldest entries evicted when cap is exceeded.

---
```

Write this file using the Write tool to `~/.claude/reup/{slug}.md`.

After writing, confirm: "Snapshot written to `~/.claude/reup/{slug}.md`."

---

### `/reup clear`

Delete `~/.claude/reup/{slug}.md`.

Use the Bash tool: `rm -f ~/.claude/reup/{slug}.md`

Confirm: "Snapshot cleared for `{slug}`."

---

## Snapshot Schema Reference

| Section       | Cap    | Purpose                                      |
|---------------|--------|----------------------------------------------|
| Identity      | 800 c  | What we're doing, current phase/goal         |
| Key Decisions | 1200 c | Decisions + rationale from this session      |
| Open Blockers | 800 c  | Unresolved blockers and open questions       |
| File Pointers | 800 c  | Key files touched/referenced this session   |
| Recent Work   | 4000 c | Chronological turn log (oldest evicted)      |

Total snapshot target: ≤12,000 characters (≈3k tokens).

The `Stop` hook (`reup-stop.sh`) appends the last assistant turn text to Recent Work automatically after every AI response. Use `/reup rebuild` to write substantive content to the other sections.
