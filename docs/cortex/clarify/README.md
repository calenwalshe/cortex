# docs/cortex/clarify/

**Artifact type:** Clarify brief — the problem frame written by `/cortex-clarify`

---

## Naming Pattern

```
docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md
```

- `<slug>` is derived from the idea text: lowercase, spaces replaced with hyphens, special characters removed (e.g., `add-smart-retry-logic-to-api-client`)
- `<timestamp>` is ISO 8601 compact format: `YYYYMMDDTHHMMSS` (e.g., `20260329T142210`)

**Example:**
```
docs/cortex/clarify/smart-retry-logic/20260329T142210-clarify-brief.md
```

---

## Required Fields

Every clarify brief must contain all of the following sections:

| Field | Description |
|-------|-------------|
| `goal` | The single desired outcome — what success looks like in one sentence |
| `non-goals` | What is explicitly out of scope for this effort |
| `constraints` | Hard limits: technical, time, resource, or organizational |
| `assumptions` | Beliefs being treated as true without verification |
| `open questions` | Questions that must be answered before research can proceed |
| `next research steps` | Specific directions for `/cortex-research` |

---

## Creating Command

```bash
/cortex-clarify <idea>
```

- Accepts a quoted string or inline text as the idea
- Derives the slug from the idea text automatically
- Writes the clarify brief to the path above
- Does not start research or spec — the clarify brief is a prerequisite artifact only
- The clarify brief is the required gate to `/cortex-research`; research cannot begin without one
- Does not modify any GSD planning state

**Example:**
```
/cortex-clarify "add smart retry logic to the API client"
```

---

## Notes

- One slug per feature/effort. Subsequent clarify passes for the same idea should update the existing slug directory, not create a new one.
- The timestamp in the filename reflects the time the brief was written, not the time the idea was first raised.
- See `docs/COMMANDS.md` for the full `/cortex-clarify` reference.
