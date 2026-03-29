# docs/cortex/reviews/

**Artifact type:** Review artifact — contract compliance review written by `/cortex-review`

---

## Naming Pattern

```
docs/cortex/reviews/<slug>/<timestamp>-review.md
```

- `<slug>` matches the slug from the corresponding active contract
- `<timestamp>` is ISO 8601 compact format: `YYYYMMDDTHHMMSS`
- Multiple reviews for the same slug are allowed; the timestamp disambiguates them

**Example:**
```
docs/cortex/reviews/smart-retry-logic/20260329T162000-review.md
```

---

## Required Sections

Every review artifact must contain all of the following sections:

| Section | Description |
|---------|-------------|
| `target` | What is being reviewed — file, directory, PR reference, or component |
| `review findings` | Observations about the target: what was found, patterns noted, issues identified |
| `contract compliance` | **Required — cannot be omitted.** Assessment of the active contract's done criteria and validators. Each done criterion must be explicitly evaluated (met / not met / partial). |
| `recommendations` | Concrete next steps based on the findings |

---

## Contract Compliance Section

The contract compliance section is a hard requirement — it cannot be omitted or skipped. It must:

1. Name the active contract being checked (path and id)
2. Evaluate each done criterion from the contract: `met`, `not met`, or `partial` with explanation
3. Report on validator results if validators were run
4. State an overall compliance verdict: `compliant`, `non-compliant`, or `partial`

This section is the primary output that drives the validate → repair or validate → assure decision.

---

## Creating Command

```bash
/cortex-review [<target>]
```

- The `<target>` can be a single file, a directory, or a PR reference
- If no argument is provided, reviews the current active contract scope (from `write_roots`)
- Output is always written as a repo-local artifact — chat-only responses do not count as review outputs
- Reads the active contract from `.cortex/state.json` or `docs/cortex/handoffs/current-state.md`

**Example:**
```
/cortex-review src/api/retry.ts
```

---

## Notes

- Review artifacts are written to the target project repo, not the Cortex framework repo
- A review finding non-compliance typically triggers `/cortex-investigate` to begin the repair loop
- See `docs/COMMANDS.md` for the full `/cortex-review` reference
- See `docs/cortex/contracts/README.md` for done criteria and validator field definitions
