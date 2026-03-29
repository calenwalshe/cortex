# docs/cortex/specs/

**Artifact type:** Spec and GSD handoff — produced by `/cortex-spec`

---

## Naming Pattern

```
docs/cortex/specs/<slug>/spec.md
docs/cortex/specs/<slug>/gsd-handoff.md
```

- `<slug>` matches the slug from the corresponding clarify brief
- Both files are always written together by a single `/cortex-spec` invocation
- No timestamp in the filename — there is one canonical spec and one canonical handoff per slug

**Example:**
```
docs/cortex/specs/smart-retry-logic/spec.md
docs/cortex/specs/smart-retry-logic/gsd-handoff.md
```

---

## Required Fields: spec.md

| Field | Description |
|-------|-------------|
| `problem` | Problem statement — what is broken or missing |
| `scope.in` | What is in scope for this effort |
| `scope.out` | What is explicitly out of scope |
| `architecture decision` | The selected approach and rationale |
| `interfaces` | API surfaces, data contracts, or integration points this work produces or consumes |
| `dependencies` | External dependencies: libraries, services, APIs |
| `risks` | Known risks and mitigations |
| `sequencing` | Order of implementation phases or tasks |
| `tasks` | Breakdown of work items, each with a clear deliverable |
| `acceptance criteria` | Conditions that must be true for the spec to be considered fulfilled |

---

## Required Fields: gsd-handoff.md

The GSD handoff is a GSD-ready work order for explicit human import into GSD planning. It must contain:

| Field | Description |
|-------|-------------|
| `objective` | What this work order delivers in one sentence |
| `deliverables` | List of concrete outputs |
| `requirements` | Requirements being addressed (requirement IDs if available) |
| `tasks` | GSD-formatted task list with types and done criteria |
| `acceptance criteria` | Must match the spec's acceptance criteria |
| `contract link` | Path to the corresponding contract in `docs/cortex/contracts/<slug>/contract-001.md` |

---

## Creating Command

```bash
/cortex-spec
```

- No flags or arguments — operates on the current active slug
- Requires the clarify brief to exist (will not run without it)
- Requires at least one research dossier to exist (will not run without it)
- **Does NOT auto-invoke GSD** — the human must explicitly import `gsd-handoff.md` into GSD as a separate step
- The spec and the contract it produces must be human-approved before execution begins — approval is a hard gate

**Example:**
```
/cortex-spec
```

---

## Notes

- `/cortex-spec` also produces the first execution contract at `docs/cortex/contracts/<slug>/contract-001.md`.
- The `gsd-handoff.md` is the bridge to GSD. It is not a GSD plan file — it is a source document the human imports manually.
- See `docs/COMMANDS.md` for the full `/cortex-spec` reference.
- See `docs/cortex/contracts/README.md` for contract schema details.
