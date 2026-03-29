# Intelligence Flow: The Sequential Spine

The sequential spine describes how a feature moves from a fuzzy idea to a shipped,
verified outcome. Cortex owns the intelligence phases. GSD owns execution. The repair
loop re-enters validate — it never restarts from clarify.

---

## The Spine

```
  ┌──────────┐   ┌──────────┐   ┌──────┐
  │ clarify  │──▶│ research │──▶│ spec │
  └──────────┘   └──────────┘   └──────┘
                                    │
                           ── GSD handoff ──
                                    │
                                    ▼
                             ┌─────────────┐
                             │  [GSD] exec │  ◀── GSD owns this phase
                             └─────────────┘
                                    │
                                    ▼
                             ┌──────────┐
                  ┌──────────│ validate │◀────────────┐
                  │          └──────────┘             │
                  │ fail               │ pass         │
                  ▼                   ▼               │
           ┌────────────┐      ┌────────────┐         │
           │   repair   │─────▶│   assure   │         │
           └────────────┘      └────────────┘         │
                  │                   │               │
                  └──── re-validate ──┘               │
                  (loops back to validate,             │
                   not back to clarify)    fail ───────┘

                             assure pass
                                    │
                                    ▼
                                 ┌──────┐
                                 │ done │
                                 └──────┘

  Cortex owns: clarify, research, spec, validate, repair, assure
  GSD owns: execute
```

---

## Phase Descriptions

### clarify

**Owner:** Cortex

The raw idea is interrogated until the problem is framed precisely. A clarify brief
captures: goal, non-goals, constraints, assumptions, open questions, and next research
steps. Ambiguity is surfaced here, not silently carried forward.

**Gate to advance:** Clarify brief is written; open questions are recorded (even if
unanswered). The brief does not need every question resolved — it needs them visible.

**Continuity artifacts written:** `docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md`,
`docs/cortex/continuity/current-state.md`, `docs/cortex/continuity/open-questions.md`

---

### research

**Owner:** Cortex

Research runs in one or more phases — concept (problem space, prior art), implementation
(architecture options, library tradeoffs, integration patterns), or evals (eval dimensions,
fixtures, rubrics). Each phase produces a dossier. Research depth is configurable
(quick / standard / deep).

**Gate to advance:** At least one research dossier exists. All open questions from
clarify are either answered or explicitly deferred with rationale.

**Continuity artifacts written:** `docs/cortex/research/<slug>/<phase>-<timestamp>.md`,
`docs/cortex/continuity/current-state.md`, `docs/cortex/continuity/open-questions.md`

---

### spec

**Owner:** Cortex

Clarify and research compress into three deliverables: `spec.md` (problem framing, arch
decision, interfaces, dependencies, risks, sequencing, acceptance criteria), `gsd-handoff.md`
(the work-order GSD reads), and `contract-001.md` (objective, deliverables, scope, write
roots, done criteria, validators, approvals, rollback hints). Human reviews and approves
the spec before GSD handoff.

**Gate to advance:** `spec.md`, `gsd-handoff.md`, and `contract-001.md` all exist and
are approved. `/cortex-spec` does NOT auto-invoke GSD — the human makes the import step
explicit.

**Continuity artifacts written:** `docs/cortex/specs/<slug>/spec.md`,
`docs/cortex/specs/<slug>/gsd-handoff.md`,
`docs/cortex/contracts/<slug>/contract-001.md`,
`docs/cortex/continuity/current-state.md`,
`docs/cortex/continuity/next-prompt.md`

---

### execute (GSD)

**Owner:** GSD

GSD reads `gsd-handoff.md` as its work-order. It owns the phase and plan lifecycle,
produces commits, and runs its own verification gates. Cortex does not write to
`.planning/` or interfere with GSD execution. When GSD marks the plan complete,
control returns to Cortex at the validate phase.

**Gate to advance:** GSD phase or plan marked complete.

**Continuity artifacts written:** None by Cortex during this phase. GSD writes to
`.planning/` independently.

---

### validate

**Owner:** Cortex

Cortex runs the validators defined in the active contract against GSD's output. Each
validator must pass against done criteria. If all pass, the spine advances to assure.
If any fail, the spine branches to repair.

**Gate to advance (to assure):** All contract validators passed.
**Gate to branch (to repair):** One or more validators failed.

**Continuity artifacts written:** `.cortex/dirty-files.json`,
`docs/cortex/continuity/eval-status.md`,
`docs/cortex/continuity/current-state.md`

---

### repair

**Owner:** Cortex

A repair contract opens targeting the specific validator failures. The repair contract
follows the same schema as the original contract: objective, deliverables, validators,
done criteria. After changes are complete, the spine re-enters validate — it does not
restart from clarify or spec. Each repair iteration updates continuity artifacts.

**Gate to advance (back to validate):** Repair changes are complete and committed.

**Continuity artifacts written:** `docs/cortex/contracts/<slug>/repair-contract-<n>.md`,
`docs/cortex/continuity/current-state.md`,
`docs/cortex/continuity/next-prompt.md`

---

### assure

**Owner:** Cortex

All validators passed. The eval suite runs across relevant dimensions (functional
correctness, regression, integration, safety/security, performance, resilience, style,
UX/taste). Subjective, high-stakes, or ambiguous evals require explicit human approval
before assure can close. If any eval fails at this stage, control returns to validate
(not to clarify).

**Gate to advance:** All evals passed; human approval obtained where required.

**Continuity artifacts written:** `docs/cortex/evals/<slug>/eval-status.md`,
`docs/cortex/continuity/eval-status.md`,
`docs/cortex/continuity/current-state.md`

---

### done

**Owner:** Cortex

The contract is closed. Continuity state is finalized. The slug moves to completed
status in `.cortex/state.json`. Future references to this feature's decisions are
preserved in `docs/cortex/continuity/decisions.md`.

**Continuity artifacts written:** `.cortex/state.json` (slug closed),
`docs/cortex/continuity/decisions.md`,
`docs/cortex/continuity/current-state.md`

---

## Gate Conditions

| From → To | Gate Condition |
|-----------|---------------|
| clarify → research | Clarify brief written; open questions surfaced (need not be resolved) |
| research → spec | Research dossier exists for at least one phase |
| spec → execute | `spec.md` + `gsd-handoff.md` + `contract-001.md` exist and are approved by human |
| execute → validate | GSD phase/plan marked complete |
| validate → repair | One or more contract validators failed |
| validate → assure | All contract validators passed |
| repair → validate | Repair changes complete; re-enters validate (not clarify) |
| assure → done | All evals passed; human approval obtained where required |

---

## GSD Handoff Boundary

Cortex produces two artifacts that constitute the GSD work-order:

- **`gsd-handoff.md`** — describes the task in GSD-readable terms: objective,
  acceptance criteria, sequencing guidance, references to spec and contract.
- **`spec.md`** — the architecture and interface reference GSD executors can read
  during implementation.

The handoff is explicit. A human (or the `/cortex-spec` command) places `gsd-handoff.md`
into the GSD input path. `/cortex-spec` does NOT auto-invoke GSD — the human decides
when to hand off. GSD never calls back into Cortex. After GSD completes, Cortex picks
up at validate by reading contract validators against GSD's output.

**Key constraint:** Cortex never writes to `.planning/`. GSD owns all workflow state.
The boundary is a one-way handoff — not a bidirectional integration.

---

## Continuity Touchpoints

| Phase | Artifacts Written |
|-------|------------------|
| clarify | `clarify-brief.md`, `current-state.md`, `open-questions.md` |
| research | `research dossier`, `current-state.md`, `open-questions.md` |
| spec | `spec.md`, `gsd-handoff.md`, `contract-001.md`, `current-state.md`, `next-prompt.md` |
| execute (GSD) | None by Cortex |
| validate | `dirty-files.json`, `eval-status.md`, `current-state.md` |
| repair | `repair-contract-<n>.md`, `current-state.md`, `next-prompt.md` |
| assure | `eval-status.md` (final), `current-state.md` |
| done | `state.json` (slug closed), `decisions.md`, `current-state.md` |

`current-state.md` is updated at every phase transition. `next-prompt.md` is refreshed
at spec, validate, and repair. `eval-status.md` is updated at validate and assure.

---

## Contract Loop

No task closes without satisfying the contract's validator list. This is the LOOP-01
through LOOP-04 guarantee:

- **LOOP-01:** No task closes without satisfying the contract's validator list.
- **LOOP-02:** If validation fails, the system produces a repair recommendation or
  opens a repair contract.
- **LOOP-03:** After each repair iteration, continuity artifacts are updated.
- **LOOP-04:** State transitions follow: clarify → research → spec → execute →
  validate → repair → assure → done.

The repair loop is bounded — it re-enters validate after each iteration. If the loop
cannot converge (repeated failures with no progress), a human decision is required
before the loop continues. The loop does not silently cycle.
