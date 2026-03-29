# docs/cortex/investigations/

**Artifact type:** Investigation artifact — root cause analysis written by `/cortex-investigate`

---

## Naming Pattern

```
docs/cortex/investigations/<slug>/<timestamp>-investigation.md
```

- `<slug>` matches the slug from the corresponding clarify brief and active contract
- `<timestamp>` is ISO 8601 compact format: `YYYYMMDDTHHMMSS`
- Multiple investigations for the same slug are allowed; the timestamp disambiguates them

**Example:**
```
docs/cortex/investigations/smart-retry-logic/20260329T160000-investigation.md
```

---

## Required Sections

Every investigation artifact must contain all of the following sections:

| Section | Description |
|---------|-------------|
| `subject` | What is being investigated — the failure, unexpected behavior, or anomaly |
| `findings` | Observations, evidence gathered, and factual conclusions from the investigation |
| `root cause` | The identified root cause of the failure or unexpected behavior |
| `evidence` | Specific artifacts, logs, test outputs, or code paths supporting the root cause conclusion |
| `repair recommendations` | Concrete recommendations for fixing the identified root cause |

---

## Repair Contracts

An investigation may optionally produce a repair contract when the investigation determines that a bounded repair loop is needed. If a repair contract is produced, it is written to:

```
docs/cortex/contracts/<slug>/contract-NNN.md
```

Where `NNN` increments from the most recent existing contract number. The human must explicitly import the repair contract into GSD — `/cortex-investigate` does not call GSD commands.

---

## Creating Command

```bash
/cortex-investigate [<subject>]
```

- Typically invoked after a validator failure, unexpected behavior, or failed eval
- The `<subject>` argument describes the failure or unexpected behavior to investigate
- If no argument is provided, operates on the current active contract context
- Writes the investigation artifact to this directory
- May also write a repair contract to `docs/cortex/contracts/<slug>/`

**Example:**
```
/cortex-investigate "rate limiter not triggering in test environment"
```

---

## Notes

- Investigation artifacts are written to the target project repo, not the Cortex framework repo
- The repair loop (investigate → repair → validate) re-enters at the `validate` phase — it never re-enters at `clarify`
- See `docs/COMMANDS.md` for the full `/cortex-investigate` reference
- See `docs/cortex/contracts/README.md` for repair contract numbering
