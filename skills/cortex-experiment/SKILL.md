# Cortex Experiment — Hypothesis-Driven Discovery

Manages the full lifecycle of a bounded hypothesis test: open a learning contract, run the experiment, and close with a decision. The 8th Cortex command. Produces `learning-contract-{id}.md` (open) and `experiment-result-{id}.md` (close) under `docs/cortex/experiments/{slug}/`. Updates `.cortex/state.json` and `docs/cortex/handoffs/current-state.md` at each phase transition.

Design reference: `docs/DISCOVERY_LOOP.md`

## User-invocable

When the user types `/cortex-experiment`, run this skill.
Also trigger when: "open an experiment", "run the experiment", "close the experiment", "write a learning contract", "write an experiment result", "start a hypothesis test", "end an experiment".

## Arguments

- `/cortex-experiment open` — start a new experiment for the active slug; writes the learning contract
- `/cortex-experiment run` — orientation-only; prints the active contract summary; no artifact written
- `/cortex-experiment close` — close the active experiment; collects results; writes experiment-result artifact; transitions mode

---

## Instructions

### `/cortex-experiment open`

#### Phase 1: Read state

Read `.cortex/state.json`.

- Extract `slug`.
- If `slug` is null, empty, or the key does not exist, block:
  ```
  BLOCKED: No active slug. Run /cortex-clarify first.
  ```

#### Phase 2: WIP limit check

Scan `docs/cortex/experiments/{slug}/` for any file matching `learning-contract-*.md` that has `status: open` in its YAML front matter.

If one is found, print a loud warning (do NOT block — the human decides whether to proceed):

```
WARNING: Slug {slug} already has an active learning contract.
Close the existing experiment before opening a new one.
```

Continue only if the human confirms they want to proceed or if no open contract was found.

#### Phase 3: Determine experiment ID

Scan `docs/cortex/experiments/{slug}/` for existing files matching `learning-contract-*.md`. Extract the numeric portion from each experiment ID in the file's YAML front matter (e.g., `EXP-001` → `1`). Next ID = max found + 1, zero-padded to 3 digits, formatted as `EXP-{NNN}`.

If no existing learning contracts exist for this slug, start at `EXP-001`.

#### Phase 4: Validate required fields

Before writing any artifact, interactively confirm with the user that the following fields are ready:

1. **Core Hypothesis** — must match the format `"We believe [X] will result in [Y] because [Z]."`. Warn if the format is missing but do not hard-block; record the user's response.
2. **Learning Threshold** — must be non-empty. If the user cannot provide it, warn that the contract is incomplete.
3. **Appetite / Timebox** — REQUIRED. Block if the user cannot provide it:
   ```
   BLOCKED: Appetite / Timebox is required. This contract is incomplete without it.
   ```

#### Phase 5: Write learning contract

1. Read `templates/cortex/learning-contract.md`.
2. Populate YAML front matter:
   - `id`: experiment ID from Phase 3 (e.g., `EXP-001`)
   - `status: open`
   - `owner`: current agent identifier
   - `slug`: active slug from state.json
   - `created`: current UTC timestamp in ISO 8601 format (e.g., `2026-04-01T18:00:00Z`)
3. Create the target directory if it does not exist:
   ```bash
   mkdir -p docs/cortex/experiments/{slug}/
   ```
4. Write the populated template to:
   ```
   docs/cortex/experiments/{slug}/learning-contract-{id}.md
   ```
   Example: `docs/cortex/experiments/my-slug/learning-contract-EXP-001.md`

#### Phase 6: Update state.json

Write the following fields to `.cortex/state.json`:

| Field | Value |
|-------|-------|
| `mode` | `"experiment"` |
| `artifacts` | Append `docs/cortex/experiments/{slug}/learning-contract-{id}.md` |

All other existing fields are preserved unchanged.

#### Phase 7: Update current-state.md

Write the following fields to `docs/cortex/handoffs/current-state.md`:

| Field | Value |
|-------|-------|
| `mode` | `experiment` |
| `next_action` | `Fill in all learning-contract fields, then run /cortex-experiment run` |

#### Phase 8: Output summary

```
EXPERIMENT OPENED
════════════════════════════════════════
Slug:        {slug}
Experiment:  {id}
Contract:    docs/cortex/experiments/{slug}/learning-contract-{id}.md
Status:      open

Next: Fill in learning-contract fields, then run /cortex-experiment run
════════════════════════════════════════
```

---

### `/cortex-experiment run`

#### Phase 1: Validate mode

Read `.cortex/state.json`. Check the `mode` field.

If `mode` is not `"experiment"`, block:
```
BLOCKED: No active experiment. Run /cortex-experiment open first.
```

#### Phase 2: Locate active contract

Scan `docs/cortex/experiments/{slug}/` for files matching `learning-contract-*.md` with `status: open` in their YAML front matter.

If none found, block:
```
BLOCKED: No open learning contract found for slug {slug}.
```

#### Phase 3: Output active contract summary

Print the following fields from the open learning contract:

- Experiment ID
- Core Hypothesis
- Learning Threshold
- Appetite / Timebox

#### Phase 4: Guidance output

Print the following reminder verbatim:

```
No artifact is written by /cortex-experiment run.
This is the human-driven phase — run the experiment and take notes externally.
When the experiment is complete, run /cortex-experiment close.
```

**State.json changes:** None. `run` is read-only and guidance-only.

---

### `/cortex-experiment close`

#### Phase 1: Validate mode

Read `.cortex/state.json`. Check the `mode` field.

If `mode` is not `"experiment"`, block:
```
BLOCKED: No active experiment to close. Run /cortex-experiment open first.
```

#### Phase 2: Locate active contract

Scan `docs/cortex/experiments/{slug}/` for files matching `learning-contract-*.md` with `status: open` in their YAML front matter.

If none found, block:
```
BLOCKED: No open learning contract found for slug {slug}.
```

Record the experiment ID (`{id}`) from the located contract's front matter.

#### Phase 3: Collect result fields (interactively)

Require all five result fields before writing any artifact. If any are missing, block and prompt for them:

1. **Actual Outcomes** — What was observed during the experiment? Be specific and objective.
2. **Validated Learning** — What do the outcomes mean for the hypothesis and the broader problem?
3. **Decision** — MUST be exactly one of: `promote | iterate | re-clarify | abandon`.
   - Block if any other value is provided:
     ```
     BLOCKED: Decision must be one of: promote, iterate, re-clarify, abandon.
     ```
4. **Rationale** — Why this decision? Reference actual outcomes and validated learning.
5. **Next Steps** — What happens immediately after this experiment closes?

#### Phase 4: Write experiment result

1. Read `templates/cortex/experiment-result.md`.
2. Populate all 8 fields:
   - **Experiment ID**: `{id}` (from the located contract)
   - **Linked Contract**: `docs/cortex/experiments/{slug}/learning-contract-{id}.md`
   - **Hypothesis Tested**: Core Hypothesis copied verbatim from the learning contract
   - **Actual Outcomes**: from Phase 3
   - **Validated Learning**: from Phase 3
   - **Decision**: from Phase 3
   - **Rationale**: from Phase 3
   - **Next Steps**: from Phase 3
3. Write to:
   ```
   docs/cortex/experiments/{slug}/experiment-result-{id}.md
   ```
   Example: `docs/cortex/experiments/my-slug/experiment-result-EXP-001.md`

#### Phase 5: Update learning contract

Edit `docs/cortex/experiments/{slug}/learning-contract-{id}.md`:

1. Set `status: closed` in the YAML front matter.
2. Fill the `## Results` section with all five result fields collected in Phase 3 (Actual Outcomes, Validated Learning, Decision, Rationale, Next Steps).

#### Phase 6: Update state.json (decision-driven transitions)

Always write `experiment_complete: true` regardless of decision.

Append `docs/cortex/experiments/{slug}/experiment-result-{id}.md` to `artifacts`.

Transition `mode` and write `reclarify_required` based on decision:

| Decision | `mode` written | `reclarify_required` written | `experiment_complete` written |
|----------|---------------|------------------------------|-------------------------------|
| `promote` | `"research"` | unchanged | `true` |
| `iterate` | `"research"` | unchanged | `true` |
| `re-clarify` | `"clarify"` | `true` | `true` |
| `abandon` | `"research"` | unchanged | `true` |

#### Phase 7: Update current-state.md

Write the following fields to `docs/cortex/handoffs/current-state.md`:

| Decision | `mode` | `next_action` |
|----------|--------|---------------|
| `promote` | `research` | `Run /cortex-spec or continue research — hypothesis confirmed` |
| `iterate` | `research` | `Gather more evidence or open a new experiment — hypothesis partially supported` |
| `re-clarify` | `clarify` | `Run /cortex-clarify to reframe — the problem frame was wrong` |
| `abandon` | `research` | `Consult human on next path — hypothesis falsified` |

#### Phase 8: Output summary

```
EXPERIMENT CLOSED
════════════════════════════════════════
Slug:        {slug}
Experiment:  {id}
Decision:    {decision}
Result:      docs/cortex/experiments/{slug}/experiment-result-{id}.md
New mode:    {mode}

{decision-specific guidance}
════════════════════════════════════════
```

Decision-specific guidance text:

- `promote`: `Hypothesis confirmed. Run /cortex-spec or continue research.`
- `iterate`: `Hypothesis partially supported. Gather more evidence or open a new experiment.`
- `re-clarify`: `Problem frame was wrong. Run /cortex-clarify to reframe before proceeding.`
- `abandon`: `Hypothesis falsified. Consult human on next path — this direction is not worth pursuing.`

---

## Rules

- **Slug required**: `open` blocks if `.cortex/state.json` has no active slug. Run `/cortex-clarify` first.
- **WIP limit warning**: `open` warns loudly if an open learning contract already exists for the slug. Warning does not block — human decides.
- **Appetite/Timebox is REQUIRED**: `open` blocks if the user cannot provide an Appetite / Timebox. A contract without a timebox is incomplete and must not be written.
- **Mode guard**: `run` and `close` block if `state.json` mode is not `experiment`.
- **Decision enum**: `close` only accepts `promote`, `iterate`, `re-clarify`, or `abandon`. Any other value blocks.
- **experiment_complete invariant**: `experiment_complete: true` is written by `close` for ALL four decisions — the gate is satisfied regardless of which decision was taken.
- **Artifact paths are canonical**: All experiment artifacts live under `docs/cortex/experiments/{slug}/`. No other write roots are used by this skill.
- **`run` is read-only**: No artifact is written and no state.json changes are made by `/cortex-experiment run`. It is guidance-only.
- **state.json is additive**: `experiment_complete` and `reclarify_required` are new fields — existing state.json files without them remain valid. Default values are `false`.

## Output Format

### open

```
EXPERIMENT OPENED
════════════════════════════════════════
Slug:        {slug}
Experiment:  {id}
Contract:    docs/cortex/experiments/{slug}/learning-contract-{id}.md
Status:      open

Next: Fill in learning-contract fields, then run /cortex-experiment run
════════════════════════════════════════
```

### run

```
ACTIVE EXPERIMENT
════════════════════════════════════════
Slug:        {slug}
Experiment:  {id}
Hypothesis:  {core_hypothesis}
Threshold:   {learning_threshold}
Timebox:     {appetite_timebox}

No artifact is written by /cortex-experiment run.
This is the human-driven phase — run the experiment and take notes externally.
When the experiment is complete, run /cortex-experiment close.
════════════════════════════════════════
```

### close

```
EXPERIMENT CLOSED
════════════════════════════════════════
Slug:        {slug}
Experiment:  {id}
Decision:    {decision}
Result:      docs/cortex/experiments/{slug}/experiment-result-{id}.md
New mode:    {mode}

{decision-specific guidance}
════════════════════════════════════════
```
