# docs/cortex/research/

**Artifact type:** Research dossier — findings written by `/cortex-research`

---

## Naming Pattern

```
docs/cortex/research/<slug>/<phase>-<timestamp>.md
```

- `<slug>` matches the slug from the corresponding clarify brief in `docs/cortex/clarify/<slug>/`
- `<phase>` is one of: `concept`, `implementation`, `evals`
- `<timestamp>` is ISO 8601 compact format: `YYYYMMDDTHHMMSS`

**Examples:**
```
docs/cortex/research/smart-retry-logic/concept-20260329T143000.md
docs/cortex/research/smart-retry-logic/implementation-20260329T150000.md
docs/cortex/research/smart-retry-logic/evals-20260329T152000.md
```

---

## Required Sections

Every research dossier must contain all of the following sections:

| Section | Description |
|---------|-------------|
| `summary` | 2–4 sentence overview of the research outcome and primary finding |
| `findings` | Detailed research results — facts, observations, comparisons |
| `trade-offs` | Options considered with pros/cons for each |
| `recommendations` | Specific recommendations derived from the findings |
| `open questions` | Questions remaining after research — may block spec or require further research |
| `sources` | References, documents, code paths, or artifacts consulted |

---

## Phase Semantics

Each `--phase` invocation produces a separate dossier. Phases are not combined in a single output.

| Phase | Focus | Gate |
|-------|-------|------|
| `concept` | What are we building and why? Problem space, approaches, prior art | Clarify brief must exist |
| `implementation` | How do we build it? Technical approach, design decisions, sequencing | Clarify brief must exist |
| `evals` | How do we know it works? Produces an eval proposal covering evaluation dimensions | Clarify brief must exist; at least one prior dossier recommended |

- The `evals` phase produces an eval proposal written to `docs/cortex/evals/<slug>/eval-proposal.md`
- Each phase must be explicitly requested by the human — the system does not auto-advance to the next phase

---

## Creating Command

```bash
/cortex-research [<topic>] [--phase concept|implementation|evals] [--depth quick|standard|deep] [--team]
```

| Flag | Values | Default | Description |
|------|--------|---------|-------------|
| `--phase` | `concept`, `implementation`, `evals` | `concept` | Research phase; each produces a separate dossier |
| `--depth` | `quick`, `standard`, `deep` | `standard` | Controls research thoroughness |
| `--team` | (flag) | Off | Opt-in agent team for research; adds cost |

- Reads the clarify brief as primary input context — clarify brief must exist before running
- `--team` is opt-in only; never default behavior

**Example:**
```
/cortex-research --phase implementation --depth deep
```

---

## Notes

- Multiple dossiers for the same slug/phase are allowed (re-research). The timestamp disambiguates them.
- See `docs/COMMANDS.md` for the full `/cortex-research` reference.
- See `docs/EVALS.md` for the eval proposal format produced by `--phase evals`.
