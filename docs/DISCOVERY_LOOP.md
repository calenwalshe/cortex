# Discovery Loop

Cortex's pre-spec intelligence work is a loop, not a line. Clarify frames the problem. Research gathers evidence. When evidence challenges the frame, the loop returns to clarify. When a critical uncertainty cannot be resolved by research alone, an experiment is opened to test a hypothesis under controlled conditions. Only when `reclarify_required` is false, all critical uncertainties are resolved or accepted, and every core assumption is backed by evidence does `/cortex-spec` permit commitment. This document is the authoritative design reference for the discovery loop. All subsequent implementation phases — phase guard patches, scaffold updates, skill changes — reference this document as the source of truth.

Cross-references: `docs/INTELLIGENCE_FLOW.md` (flow diagram), `docs/COMMANDS.md` (command interface).

---

## 1. Mode Transitions

### Valid Modes

The eight valid values for the `mode` field in `.cortex/state.json`:

| Mode | Description |
|------|-------------|
| `clarify` | Framing the problem; producing a clarify brief |
| `research` | Gathering evidence; producing a research dossier |
| `experiment` | Running a bounded hypothesis test; producing a learning contract and result |
| `spec` | Writing the execution spec; the commitment boundary |
| `execute` | GSD-driven implementation; post-spec phases |
| `validate` | Post-implementation validation; running evals |
| `repair` | Fixing failures found in validate; re-enters validate on completion |
| `assure` | Final sign-off and archival |

### Transition Triggers and State Field Drivers

**clarify → research**
- Trigger: Clarify brief is written and approved.
- State field written: `mode: research`; `reclarify_required: false` (reset on each new brief).
- See §7 Terminal States: each clarify iteration narrows the set of possible terminals toward one.

**research → clarify (backtrack)**
- Trigger: Research evidence invalidates the original problem frame or core assumptions.
- State field written: `reclarify_required: true` (written by `/cortex-research`).
- Effect: `/cortex-spec` blocks until `reclarify_required` is set back to `false` by a new clarify brief.
- Pre-spec backtracking is always permitted — there is no penalty for returning to clarify.

**research → experiment**
- Trigger: A critical uncertainty has `resolution_path: experiment` and the human decides to open an experiment rather than proceed to spec.
- State field written: `mode: experiment`.

**experiment → research**
- Trigger: Experiment closes with `decision: iterate` — the hypothesis was wrong or partial; more evidence needed.
- State field written: `mode: research`; `experiment_complete: true` (for that experiment entry).

**experiment → clarify (backtrack)**
- Trigger: Experiment closes with `decision: re-clarify` — the frame itself is wrong.
- State field written: `mode: clarify`; `reclarify_required: true`.

**research → spec**
- Trigger: All three spec-readiness blockers clear (see Section 4).
- State field written: `mode: spec`.

**spec → execute**
- Trigger: Spec is written, approved, and imported into GSD.
- State field written: `mode: execute`.

**validate → repair**
- Trigger: Eval failures detected during validate.
- State field written: `mode: repair`.

**repair → validate**
- Trigger: Repair work is complete.
- State field written: `mode: validate`.
- Constraint: Post-spec repair re-enters `validate`, never `clarify`. The repair loop is bounded.

**validate → assure**
- Trigger: All evals pass; human approves.
- State field written: `mode: assure`.

---

## 2. Artifact Schemas

### File Paths

All experiment artifacts live under:

```
docs/cortex/experiments/{slug}/
```

Where `{slug}` matches the project slug in `.cortex/state.json`.

### Lifecycle Events and Artifact Writes

| Event | Artifact Written | Path |
|-------|-----------------|------|
| `/cortex-experiment open` | `learning-contract.md` | `docs/cortex/experiments/{slug}/learning-contract-{id}.md` |
| `/cortex-experiment close` | `experiment-result.md` | `docs/cortex/experiments/{slug}/experiment-result-{id}.md` |
| `/cortex-experiment run` | No artifact written | Human-driven; notes taken externally |

### Learning Contract Schema

The learning-contract is the pre-experiment planning artifact. It encodes the hypothesis, experiment design, and convergence criteria before any experiment work begins.

**YAML front matter fields:**

```yaml
---
id: <unique identifier, e.g. EXP-001>
status: <open | closed>
owner: <responsible agent or human>
slug: <project slug from state.json>
created: <ISO 8601 timestamp>
---
```

**Body sections (11 fields):**

1. **Problem Statement** — What specific question does this experiment answer?
2. **Core Hypothesis** — The falsifiable claim being tested. Format: "We believe [X] will result in [Y] because [Z]."
3. **Key Assumptions** — List the assumptions this hypothesis depends on.
4. **Target Context** — Where/when/with whom will the experiment run?
5. **Experiment Design** — The method: what will be built, run, or observed, and how.
6. **Key Metrics / Evidence** — What measurements or observations will be used to evaluate the hypothesis?
7. **Learning Threshold** — The minimum result that would confirm or falsify the hypothesis.
8. **Risks & Dependencies** — What could prevent the experiment from running or producing valid results?
9. **Appetite / Timebox** — `<!-- REQUIRED -->` Maximum time or effort budget. Contract is incomplete without this field.
10. **Expected Learning** — What does success look like? What does failure tell us?

**Post-experiment block (Results section):**

After the experiment closes, the following fields are filled in:

- **Actual Outcomes** — What was observed?
- **Validated Learning** — What was learned from the outcomes?
- **Decision** — One of: `promote | iterate | re-clarify | abandon`
- **Rationale** — Why this decision?
- **Next Steps** — What happens next based on the decision?

### Experiment Result Schema

The experiment-result is the close artifact. It is written by `/cortex-experiment close` and is intentionally minimal — a record of outcomes, not a planning document.

**Fields:**

1. **Experiment ID** — Matches `id` in the learning contract front matter.
2. **Linked Contract** — Path to the learning-contract this result closes.
3. **Hypothesis Tested** — The core hypothesis from the learning contract (copied verbatim).
4. **Actual Outcomes** — What was observed during the experiment.
5. **Validated Learning** — What the outcomes mean for the hypothesis and the broader problem.
6. **Decision** — One of: `promote | iterate | re-clarify | abandon`
7. **Rationale** — Reasoning behind the decision.
8. **Next Steps** — Immediate actions following this decision.

---

## 3. Uncertainty Register Schema

The uncertainty register lives in `docs/cortex/handoffs/open-questions.md`. Each entry has five structured fields.

### Fields Per Entry

| Field | Type | Valid Values |
|-------|------|-------------|
| `type` | enum | `frame \| knowledge \| design \| evidence \| eval` |
| `severity` | enum | `critical \| noncritical` |
| `resolution_path` | enum | `research \| experiment \| human` |
| `status` | enum | `open \| resolved \| deferred \| accepted-risk` |
| `resolved_by` | pointer | Path to the artifact (dossier, experiment-result) that resolved this entry. Null if not yet resolved. |

### Field Definitions

- **type: frame** — Uncertainty about whether the problem is correctly framed; requires `/cortex-clarify`.
- **type: knowledge** — Missing domain knowledge; resolvable by `/cortex-research`.
- **type: design** — Uncertainty about approach or architecture; may require experiment or human judgment.
- **type: evidence** — An assumption that needs empirical confirmation; typically `resolution_path: experiment`.
- **type: eval** — Uncertainty about how success will be measured; requires human alignment.

### Backward Compatibility

Existing flat entries in `open-questions.md` (plain prose or bullet lists) remain valid. Structured fields are additive. When processing flat entries, the following defaults apply:

| Field | Default |
|-------|---------|
| `type` | `knowledge` |
| `severity` | `noncritical` |
| `resolution_path` | `research` |
| `status` | `open` |
| `resolved_by` | `null` |

Flat entries should be migrated to structured form incrementally as they are revisited.

---

## 4. Spec-Readiness Gate

`/cortex-spec` enforces three blockers before it will write a spec. All three must clear.

### Blocker 1: reclarify_required is false

`.cortex/state.json` must have `reclarify_required: false`. If it is `true`, `/cortex-spec` must block with:

```
BLOCKED: reclarify_required is true.
Research evidence has changed the problem frame. Run /cortex-clarify to reframe before speccing.
```

### Blocker 2: No critical open uncertainties

The uncertainty register (`docs/cortex/handoffs/open-questions.md`) must contain no entries where both `severity: critical` AND `status: open`. If any exist, `/cortex-spec` must block with:

```
BLOCKED: [N] critical uncertainties are still open.
Resolve or explicitly accept-risk each one before speccing.
```

### Blocker 3: Core assumptions backed by evidence

Every core assumption in the research dossier must be backed by at least one research finding or experiment result. If any assumption is unbacked, `/cortex-spec` must block with:

```
BLOCKED: [N] core assumption(s) have no evidence backing.
Run /cortex-research or /cortex-experiment to gather supporting evidence.
```

See also: §7 Terminal States — the spec-readiness gate permits spec only when terminal is `commit-to-build`. The other six terminals represent earlier stopping points.

### experiment_complete Gate (Conditional)

This gate applies only when the uncertainty register contains one or more entries with both `severity: critical` AND `resolution_path: experiment`.

When the gate is active, `.cortex/state.json` must have `experiment_complete: true` for each such entry before `/cortex-spec` proceeds. Slugs that resolved all critical uncertainties via research (`resolution_path: research` or `resolution_path: human`) are unaffected by this gate.

### state.json Schema Extensions

New fields added to `.cortex/state.json` by this feature:

```json
{
  "reclarify_required": false,
  "experiment_complete": false,
  "mode": "experiment"
}
```

- `reclarify_required` (boolean, top-level, required): Written `true` by `/cortex-research` when evidence changes the frame. Written `false` by `/cortex-clarify` when a new brief is produced. Default: `false`.
- `experiment_complete` (boolean, top-level, conditional): Written `true` by `/cortex-experiment close` when the experiment ends with any decision. Only checked by `/cortex-spec` if the uncertainty register requires it. Default: `false`.
- `mode: experiment` (string): Added as a valid value for the existing `mode` field. Written by `/cortex-experiment open`.

All existing `state.json` files remain valid — these are additive fields.

---

## 5. Write-Root Policy

### Permitted Write Roots During Experiment Mode

When `mode: experiment`, the phase guard adds the following permitted write root:

```
docs/cortex/experiments/
```

This root is scoped to: `docs/cortex/experiments/{slug}/learning-contract-{id}.md` and `docs/cortex/experiments/{slug}/experiment-result-{id}.md`.

### Product-Path Write Guard

The product-path write guard remains intact and is not relaxed by experiment mode. Writes to any path outside the explicitly permitted roots are denied regardless of mode.

### Permitted Roots (Full Set, Experiment Mode)

```
.cortex/
docs/cortex/
docs/cortex/experiments/
```

The phase guard is patched in `.claude/hooks/cortex-phase-guard.sh` to include `docs/cortex/experiments/` in the permitted write root prefixes. The scaffold is patched in `scripts/cortex/scaffold_runtime.sh` to include `experiments` in `DOCS_SUBDIRS` so the directory is created on first scaffold run.

---

## 6. Convergence Guardrails

The discovery loop uses six guardrails drawn from HDD (Hypothesis-Driven Development), Lean Startup, and Shape Up to prevent infinite loops and scope creep.

### Guardrail 1: Fixed Timebox / Appetite

Every learning contract must include an `Appetite / Timebox` field (`<!-- REQUIRED -->`). A contract without a timebox is incomplete and must not be opened. `/cortex-experiment open` must validate this field is non-empty before writing the contract.

### Guardrail 2: Learning Threshold

Every learning contract must define a `Learning Threshold` — the minimum result that confirms or falsifies the hypothesis. Experiments without a defined threshold produce ambiguous outcomes that cannot drive a decision.

### Guardrail 3: Specific Testable Hypothesis

The `Core Hypothesis` field must be falsifiable and specific. Format: "We believe [X] will result in [Y] because [Z]." Vague hypotheses ("this might work") are not acceptable.

### Guardrail 4: Minimal Viable Experiment

The `Experiment Design` must describe the smallest experiment that can test the hypothesis within the timebox. The discovery loop is not a platform for building prototypes that grow into features.

### Guardrail 5: Defined Decision Rule Outcomes

Every learning contract must be closeable with one of four explicit outcomes. No other outcomes are valid:

| Decision | Meaning | Next Mode |
|----------|---------|-----------|
| `promote` | Hypothesis confirmed; ready to spec | `research` → `/cortex-spec` |
| `iterate` | Partial learning; refine and re-experiment | `research` |
| `re-clarify` | Hypothesis was wrong because the frame was wrong | `clarify` |
| `abandon` | Hypothesis falsified; this path is not worth pursuing | `research` or human decision |

See also: §7 Terminal States for the convergence model that determines when the discovery loop ends.

### Guardrail 6: WIP Limit

A slug must not have more than one active (status: open) learning contract simultaneously. `/cortex-experiment open` must check the `docs/cortex/experiments/{slug}/` directory for any existing open learning contracts and warn loudly if one is found:

```
WARNING: Slug {slug} already has an active learning contract.
Close the existing experiment before opening a new one.
```

This warning does not block — it is surfaced to the human who makes the final call.

---

## 7. Terminal States

The discovery loop is a **terminal-state finder**, not a spec-generator. Every slug is heading toward one of seven valid resolutions. The loop converges when the set of possible terminals narrows to exactly one. `/cortex-close --terminal <name>` records which terminal was reached when a slug closes.

### The Seven Terminals

| Terminal | Category | When Reached | Commit Action | Artifact |
|---|---|---|---|---|
| `commit-to-build` | Non-transitional | Real problem, viable solution, scope confirmed | Proceed to spec and execution | spec.md, contract |
| `kill-with-learning` | Non-transitional | Problem is real but this solution approach has no value; stop and document why | Record rationale, archive slug | decisions.md entry |
| `decompose` | Non-transitional | Problem is real but too broad; must split into N focused child slugs | Create N child clarify briefs | child briefs |
| `experiment-required` | Non-transitional | Evidence insufficient; a bounded test is needed before committing | Open a learning contract | learning-contract.md |
| `already-exists` | Non-transitional | The existing system already handles this adequately, even if imperfectly | Document the existing mechanism | decisions.md entry |
| `hold-on-dependency` | Non-transitional | Blocked by an external dependency; no action possible until it resolves | Record blocker and trigger | decisions.md entry |
| `reframe-and-continue` | **Transitional** | Research has invalidated the current problem frame; the loop must restart with a new clarify brief | Produce iter N+1 clarify brief (supersedes current) | new clarify brief |

**`reframe-and-continue` is transitional** — reaching it does not close the slug. It triggers a new clarify iteration. The six non-transitional terminals are the only valid `--terminal` values for `/cortex-close`.

### 4→7 Refinement: Mapping from Necessity-Gate Verdicts

The existing `/cortex-spec` necessity gate (§4) produces four verdicts. Each verdict refines into one or two of the seven terminals. This is a refinement, not a replacement — the necessity gate still runs, and the four verdicts are still valid. The seven terminals are a more precise vocabulary for *which* BUILD/NARROW/DEFER/REJECT outcome applies to a specific slug.

| Necessity Verdict | Terminal Refinement | Split Criterion |
|---|---|---|
| `BUILD` | `commit-to-build` | 1:1 — no refinement needed |
| `NARROW` | `decompose` OR `reframe-and-continue` | Decompose: the problem is structurally too broad (splits into N children). Reframe: the scope is narrowable within the same slug by reconsidering the frame. |
| `DEFER` | `experiment-required` OR `hold-on-dependency` | Experiment-required: closeable by running a bounded test. Hold-on-dependency: blocked by something external; no test helps. |
| `REJECT` | `kill-with-learning` OR `already-exists` | Kill-with-learning: problem exists but this solution has no value. Already-exists: the problem is already solved by the existing system. |

**The REJECT split is already in the existing code.** `/cortex-spec` SKILL.md describes REJECT as: *"This solves a problem that doesn't exist, OR the existing system already handles it."* The OR is precisely the Kill-with-Learning vs Already-Exists split — mechanically grounded in existing prose, not a new abstraction.

### Convergence Model

At the start of a slug, the clarify brief's `initial_terminal_set:` frontmatter declares the full set of terminals the slug could plausibly reach. On each clarify iteration, research evidence eliminates terminals from the set. The `ruled_out:` frontmatter field accumulates eliminated terminals with their ruling-out evidence.

**The loop converges when `initial_terminal_set` minus `ruled_out` has exactly one terminal remaining.**

At that point, `/cortex-close --terminal <name>` closes the slug at the surviving terminal.

**Loop stops earlier** if: (a) the surviving set reaches one terminal before all iterations complete, (b) `/cortex-spec` necessity gate fires with high confidence (≥0.7) before the set is formally narrowed — the necessity verdict maps to a terminal and the slug closes at that terminal.

**Example:** A slug starts with `initial_terminal_set: [commit-to-build, already-exists, experiment-required]`. After iter-1 research, `already-exists` is ruled out (the feature doesn't exist). After iter-2 research, `experiment-required` is ruled out (the mechanism is well-understood). The set is now `[commit-to-build]` — exactly one terminal — and the slug proceeds to spec via `commit-to-build`.

### Terminal Declaration in `/cortex-close`

`/cortex-close --terminal <name>` is required when closing any slug. The `--terminal` argument:
1. Must be one of the seven terminal slugs listed above
2. Must not appear in the brief's `ruled_out:` list
3. Is recorded in `decisions.md` Archive Index: `terminal: {name}`

Cross-reference: §1 Mode Transitions describes how `reframe-and-continue` (the transitional terminal) produces a new clarify iteration. §4 Spec-Readiness Gate governs when `commit-to-build` is reachable.
