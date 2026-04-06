# Cortex Command Reference

All commands write artifacts to the target project repo (the repo where Cortex is installed and used). The Cortex framework repo itself is not modified by command invocations.
The framework repo may still contain `.cortex/` and `.planning/` for dogfooding and development, but runtime command artifacts belong in the target project repo.

Commands follow the intelligence spine: `/cortex-clarify` → `/cortex-research` → `/cortex-spec` → `/cortex-bridge` → (GSD execution) → `/cortex-investigate` / `/cortex-review` / `/cortex-audit` → `/cortex-status` → `/cortex-close`. Utility commands (`/cortex-fit`, `/cortex-stash`, `/cortex-drive`) can be invoked at any point.

---

## /cortex-clarify

**Syntax**
```bash
/cortex-clarify <idea>
```

**Purpose**
Converts a fuzzy idea into a written problem frame (clarify brief) — the gate to all downstream research and spec work.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `<idea>` | Required | The idea, problem, or feature to clarify — a quoted string or inline text | — |

**Outputs**

| Artifact | Path | Contents |
|----------|------|----------|
| Clarify brief | `docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md` | goal, non-goals, constraints, assumptions, open questions, next research steps |

Paths are relative to the target project repo. The slug is derived from the idea text.

**Rules**
- Creates the slug from the idea text (lowercase, hyphenated).
- Does not start research or spec — clarify brief is a prerequisite artifact only.
- The clarify brief is the required gate to `/cortex-research`. Research cannot begin without one.
- Does not modify any GSD planning state (`.planning/`, `STATE.md`).

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `slug` | writes | derived slug |
| `mode` | writes | `"clarify"` |
| `approval_status` | writes | `"pending"` |
| `active_contract` | writes | `null` |
| `artifacts` | appends | clarify brief path |
| `gates.clarify_complete` | writes | `true` |

Also writes `docs/cortex/handoffs/current-state.md` with all continuity fields.

**Block Conditions**
- Warns (does NOT block) if `.cortex/state.json` already has a different active slug; requires user confirmation before overwriting the active context.

**Example**
```
/cortex-clarify "add smart retry logic to the API client"
```

---

## /cortex-research

**Syntax**
```bash
/cortex-research [<topic>] [--phase concept|implementation|evals] [--depth quick|standard|deep] [--team] [--write-plan]
```

**Purpose**
Produces a research dossier for the current slug at a specified phase and depth. Each phase (concept, implementation, evals) produces a separate dossier.

**Inputs**

| Argument / Flag | Required | Description | Default |
|-----------------|----------|-------------|---------|
| `<topic>` | Optional | Focus topic for this research pass | Current slug's clarify brief |
| `--phase` | Optional | Research phase: `concept`, `implementation`, or `evals` | `concept` |
| `--depth` | Optional | Research depth: `quick`, `standard`, or `deep` | `standard` |
| `--team` | Optional flag | Invokes an agent team for research (opt-in, adds cost) | Off |
| `--write-plan` | Optional flag | Writes `eval-plan.md` from `eval-proposal.md` when approvals allow | Off |

**Outputs**

| Artifact | Path | Contents |
|----------|------|----------|
| Research dossier (`concept`/`implementation`) | `docs/cortex/research/<slug>/<phase>-<timestamp>.md` | Findings, trade-offs, recommendations, open questions for the requested phase |
| Eval proposal (`evals`) | `docs/cortex/evals/<slug>/eval-proposal.md` | Proposed eval dimensions, fixtures, thresholds, failure taxonomy, and approval gate |
| Eval plan (`--write-plan`) | `docs/cortex/evals/<slug>/eval-plan.md` | Approved eval dimensions with execution plan and thresholds |

**Rules**
- Reads the clarify brief as primary input context. Clarify brief must exist.
- Each `--phase` produces a separate dossier — phases are not combined in a single output.
- `--phase evals` produces `eval-proposal.md` in `docs/cortex/evals/<slug>/`.
- `--write-plan` reads `eval-proposal.md` and writes `eval-plan.md` only when approval requirements are satisfied.
- Each phase must be explicitly requested by the human — the system does not auto-advance to the next phase.
- `--team` is opt-in only. Agent team mode is never default behavior.

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `mode` | writes | `"research"` |
| `artifacts` | appends | dossier path (concept/implementation) or eval proposal path |
| `gates.research_complete` | writes | `true` (when at least one dossier exists) |
| `reclarify_required` | writes (conditional) | `true` — only when research evidence invalidates the current problem frame |
| `approvals.evals` | writes (`--write-plan` only) | `true` — after successfully writing `eval-plan.md` |

Also writes `docs/cortex/handoffs/current-state.md`.

**Block Conditions**
- Blocks if no clarify brief exists for the active slug (run `/cortex-clarify` first)
- Blocks (`--write-plan`) if `eval-proposal.md` has `approval_required: true` and `Approval Status` is not `approved`
- Blocks (`--write-plan`) if `Approval Status: rejected` in the eval proposal

**Example**
```
/cortex-research --phase implementation --depth deep
```

---

## /cortex-spec

**Syntax**
```bash
/cortex-spec
```

**Purpose**
Compresses the clarify brief and research dossier(s) into a spec, a GSD handoff document, and the first execution contract.

**Inputs**

| Source | Description |
|--------|-------------|
| Clarify brief | Read from `docs/cortex/clarify/<slug>/` in the target repo |
| Research dossier(s) | Read from `docs/cortex/research/<slug>/` in the target repo |

No flags or arguments. The command always operates on the current active slug.

**Outputs**

| Artifact | Path | Contents |
|----------|------|----------|
| Spec | `docs/cortex/specs/<slug>/spec.md` | problem, scope, architecture decision, interfaces, dependencies, risks, sequencing, tasks, acceptance criteria |
| GSD handoff | `docs/cortex/specs/<slug>/gsd-handoff.md` | GSD-ready work order for explicit human import into GSD |
| Contract | `docs/cortex/contracts/<slug>/contract-001.md` | id, slug, phase, objective, deliverables, scope, write roots, done criteria, validators, approvals, rollback hints |

**Rules**
- Requires the clarify brief to exist. Will not run without it.
- Requires at least one research dossier to exist. Will not run without it.
- **Does NOT auto-invoke GSD.** The human must explicitly import `gsd-handoff.md` into GSD as a separate step. Cortex does not call GSD commands.
- The spec and contract must be human-approved before execution begins. Approval is a hard gate.
- Contract numbering starts at `contract-001.md`. Subsequent repair contracts increment the counter.

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `mode` | writes | `"spec"` |
| `approval_status` | writes | `"pending"` |
| `active_contract` | writes | `docs/cortex/contracts/<slug>/contract-001.md` |
| `artifacts` | appends | spec.md, gsd-handoff.md, and contract-001.md paths |
| `gates.spec_complete` | writes | `true` |

Also writes `docs/cortex/handoffs/current-state.md`.

**Block Conditions**
- Blocks if `.cortex/state.json` is missing or has no active slug
- Blocks if no clarify brief exists for the active slug
- Blocks if no research dossier exists for the active slug
- Blocks if `reclarify_required: true` in state.json
- Blocks if any open question has `severity: critical` AND `status: open` in `open-questions.md`
- Blocks if any core assumption in the research dossiers has no evidence backing

**Example**
```
/cortex-spec
```

---

## /cortex-investigate

**Syntax**
```bash
/cortex-investigate [<subject>]
```

**Purpose**
Writes an investigation artifact that documents findings, root cause analysis, and optionally produces a repair contract for handoff into GSD.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `<subject>` | Optional | What to investigate — a description of the failure or unexpected behavior | Current active contract context |

**Outputs**

| Artifact | Path | Contents |
|----------|------|----------|
| Investigation artifact | `docs/cortex/investigations/<slug>/` | Findings, root cause, evidence, repair recommendations |
| Repair contract (optional) | `docs/cortex/contracts/<slug>/contract-NNN.md` | Generated when investigation determines a repair loop is needed |

**Rules**
- Typically invoked after a validator failure, unexpected behavior, or failed eval.
- Can produce a repair contract for GSD handoff. The human imports the repair contract explicitly — the command does not call GSD.
- Investigation artifacts are written to the target project repo, not the Cortex repo.

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `artifacts` | appends | investigation artifact path (and repair contract path if written) |

Also updates `docs/cortex/handoffs/current-state.md` (`recent_artifacts`, `blockers` if BLOCKED, `next_action`).

**Block Conditions**
- Blocks if `slug` is null in state.json AND no `<subject>` argument is provided

**Example**
```
/cortex-investigate "rate limiter not triggering in test environment"
```

---

## /cortex-review

**Syntax**
```bash
/cortex-review [<target>]
```

**Purpose**
Writes a review artifact that evaluates the target against the active contract's done criteria and validators.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `<target>` | Optional | File, PR, or component to review | Current active contract scope |

**Outputs**

| Artifact | Path | Contents |
|----------|------|----------|
| Review artifact | `docs/cortex/reviews/<slug>/` | Review findings, contract compliance section, recommendations |

**Rules**
- Review always checks the active contract's done criteria and validators. Contract compliance is a required section — it cannot be omitted.
- Output is always written as a repo-local artifact. Chat-only responses do not count as review outputs.
- The `<target>` can be a single file, a directory, or a PR reference.

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `artifacts` | appends | review artifact path |
| `mode` | writes (conditional) | `"repair"` — only when P0 eval failures are detected |

Also updates `docs/cortex/handoffs/current-state.md` and `docs/cortex/handoffs/eval-status.md`.

**Block Conditions**
- None — slug defaults to `"unknown"` if neither state.json slug nor `<target>` argument is available.

**Example**
```
/cortex-review src/api/retry.ts
```

---

## /cortex-audit

**Syntax**
```bash
/cortex-audit [<target>]
```

**Purpose**
Writes a security and quality audit artifact covering all required audit lenses for the specified scope.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `<target>` | Optional | Scope to audit — file, directory, or component | Current active contract write roots |

**Outputs**

| Artifact | Path | Contents |
|----------|------|----------|
| Audit artifact | `docs/cortex/audits/<slug>/` | Findings per lens, severity ratings, remediation recommendations |

**Rules**
- Must cover all 7 required lenses:
  1. Authentication
  2. Data handling
  3. Secrets exposure
  4. Unsafe tool usage
  5. Input validation
  6. Dependency risks
  7. Misuse vectors
- No lens may be omitted without an explicit documented note explaining why it is not applicable.
- Output is always a repo-local artifact. Chat-only audit responses do not count.

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `artifacts` | appends | audit artifact path |

Also updates `docs/cortex/handoffs/current-state.md` (`recent_artifacts`, `blockers` if CRITICAL findings, `next_action`).

**Block Conditions**
- None — slug defaults to `"unknown"` if neither state.json slug nor `<target>` argument is available.

**Example**
```
/cortex-audit src/
```

---

## /cortex-status

**Syntax**
```bash
/cortex-status
```

**Purpose**
Reconstructs the current working context from repo-local artifacts and updates the continuity handoff files. The primary recovery command after `/clear`, `/compact`, or context exhaustion.

**Inputs**

| Source | Description |
|--------|-------------|
| `.cortex/state.json` | Machine-readable runtime state |
| `docs/cortex/` artifacts | All artifacts written by previous commands |
| `current-state.md` | Human-readable working state snapshot |

No flags or arguments.

**Outputs**

| Artifact | Path | Contents |
|----------|------|----------|
| Updated current-state.md | `docs/cortex/handoffs/current-state.md` | Refreshed working state snapshot |
| Updated next-prompt.md | `docs/cortex/handoffs/next-prompt.md` | Refreshed paste-ready restart prompt |
| Terminal summary | (stdout) | Current slug, mode, open questions, blockers, next recommended action |

**Rules**
- Safe to run at any time, including mid-session.
- Does not require chat history. Reads only from repo-local artifacts.
- Designed specifically for use after `/clear` or compaction when chat context is lost.
- Does not modify product code or GSD state.
- See `docs/CONTINUITY.md` for the full resume protocol and artifact schemas.

**State Effects**
- Reads `.cortex/state.json` (no mutations to state.json).
- Writes `docs/cortex/handoffs/current-state.md` with reconciled state from all artifact sources.
- Writes `docs/cortex/handoffs/next-prompt.md` with a paste-ready restart prompt.

**Block Conditions**
- None — safe to run at any time, including when no state.json exists.

**Example**
```
/cortex-status
```

---

## /cortex-experiment

**Syntax**
```bash
/cortex-experiment <open|run|close>
```

**Purpose**
Manages the full lifecycle of a bounded hypothesis test: open a learning contract, run the experiment (human-driven), and close with a structured decision. Implements the experiment mode in the discovery loop. Only used for critical uncertainties with `resolution_path: experiment` in the uncertainty register.

**Inputs**

| Argument | Required | Description |
|----------|----------|-------------|
| `open` | Required (one of three) | Start a new experiment; writes the learning contract |
| `run` | Required (one of three) | Orientation-only; prints active contract summary; no artifact written |
| `close` | Required (one of three) | Close the active experiment; collects results; writes experiment-result artifact |

**Outputs**

| Subcommand | Artifact | Path | Contents |
|------------|----------|------|----------|
| `open` | Learning contract | `docs/cortex/experiments/<slug>/learning-contract-{id}.md` | Hypothesis, experiment design, learning threshold, timebox, key metrics |
| `run` | (none) | — | Read-only guidance; no artifact written |
| `close` | Experiment result | `docs/cortex/experiments/<slug>/experiment-result-{id}.md` | Actual outcomes, validated learning, decision, rationale, next steps |

**State Transitions**

| Decision (close) | mode written | reclarify_required |
|------------------|--------------|--------------------|
| `promote` | `research` | unchanged |
| `iterate` | `research` | unchanged |
| `re-clarify` | `clarify` | `true` |
| `abandon` | `research` | unchanged |

`experiment_complete: true` is written to `.cortex/state.json` for ALL four decisions.

**State Effects**

| Subcommand | Field | Operation | Value |
|------------|-------|-----------|-------|
| `open` | `mode` | writes | `"experiment"` |
| `open` | `artifacts` | appends | learning contract path |
| `run` | _(none)_ | — | Read-only; no state.json changes |
| `close` | `experiment_complete` | writes | `true` (all decisions) |
| `close` | `mode` | writes | decision-driven (see State Transitions table above) |
| `close` | `reclarify_required` | writes (conditional) | `true` — only for `re-clarify` decision |
| `close` | `artifacts` | appends | experiment result path |

`open` and `close` also write `docs/cortex/handoffs/current-state.md`. `close` additionally updates the learning contract's `status` to `closed`.

**Block Conditions**

- `open` blocks if `.cortex/state.json` has no active slug (run `/cortex-clarify` first)
- `open` blocks if the user cannot provide an Appetite / Timebox (required field)
- `open` warns (does NOT block) if an open learning contract already exists for the slug
- `run` blocks if `state.json` mode is not `"experiment"`
- `close` blocks if `state.json` mode is not `"experiment"`
- `close` blocks if no open learning contract is found for the slug
- `close` blocks if decision is not one of `promote | iterate | re-clarify | abandon`
- `close` blocks if any required result field (Actual Outcomes, Validated Learning, Decision, Rationale, Next Steps) is missing

**Rules**
- `open` blocks if `.cortex/state.json` has no active slug. Run `/cortex-clarify` first.
- `open` warns loudly (does not block) if an open learning contract already exists for the slug.
- `open` blocks if the user cannot provide an Appetite / Timebox — this field is required.
- `run` and `close` block if `state.json` mode is not `experiment`.
- `close` only accepts `promote`, `iterate`, `re-clarify`, or `abandon` as decision values.
- `experiment_complete: true` is written by `close` for ALL four decisions — the gate is satisfied regardless of decision.
- `run` is read-only: no artifact is written, no state.json changes made.
- All experiment artifacts live under `docs/cortex/experiments/<slug>/`. No other write roots used.

**Example**
```
/cortex-experiment open
/cortex-experiment run
/cortex-experiment close
```

See `docs/DISCOVERY_LOOP.md` for full experiment mode semantics, convergence guardrails, and the WIP limit policy.

---

## /cortex-bridge

**Syntax**
```bash
/cortex-bridge [--slug <slug>]
```

**Purpose**
Generates a complete GSD `.planning/` scaffold from Cortex artifacts (spec, contract, gsd-handoff). One-time handoff that crosses the Cortex→GSD seam.

**Inputs**

| Argument / Flag | Required | Description | Default |
|-----------------|----------|-------------|---------|
| `--slug` | Optional | Slug to bridge | Current active slug from state.json |

**Outputs**

| Artifact | Path | Contents |
|----------|------|----------|
| PROJECT.md | `.planning/PROJECT.md` | Project context from spec |
| ROADMAP.md | `.planning/ROADMAP.md` | Phase breakdown from gsd-handoff |
| REQUIREMENTS.md | `.planning/REQUIREMENTS.md` | Requirements from spec acceptance criteria |
| STATE.md | `.planning/STATE.md` | Initial GSD state |
| config.json | `.planning/config.json` | GSD configuration |
| Phase CONTEXT.md | `.planning/phases/*/CONTEXT.md` | Per-phase context from contract done criteria |

**Rules**
- Requires spec, contract, and gsd-handoff to exist for the slug.
- Done criteria from the contract must appear **verbatim** in ROADMAP.md phase success criteria.
- This is the one sanctioned exception to "Cortex does not write to `.planning/`". GSD owns `.planning/` after the bridge runs.
- Does NOT auto-invoke GSD execution.

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `mode` | writes | `"execute"` |
| `artifacts` | appends | all generated `.planning/` paths |

**Block Conditions**
- Blocks if spec, contract, or gsd-handoff is missing for the active slug.

**Example**
```
/cortex-bridge
```

---

## /cortex-close

**Syntax**
```bash
/cortex-close
```

**Purpose**
Archives a completed slug: copies artifacts to cold path, records closure in decisions.md, and resets state to idle.

**Inputs**

None. Operates on the current active slug. Requires user confirmation (mandatory gate — cannot be skipped).

**Outputs**

| Artifact | Path | Contents |
|----------|------|----------|
| Archive | `docs/cortex/archive/<slug>/` | Copy of all slug artifacts |
| Decision log entry | `docs/cortex/handoffs/decisions.md` | Closure record |

**Rules**
- Slug confirmation gate is **mandatory** (no autonomy skip).
- Archive is copy-only — originals are never deleted.
- Ordering is safety-critical: copy artifacts first, update decisions.md second, reset state last.

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `slug` | writes | `null` |
| `mode` | writes | `"done"` |
| `active_contract` | writes | `null` |
| `artifacts` | writes | `[]` |
| `gates` | writes | all `false` |

**Block Conditions**
- Blocks if no active slug exists.

**Example**
```
/cortex-close
```

---

## /cortex-fit

**Syntax**
```bash
/cortex-fit <X> [against <Y>]
```

**Purpose**
Evaluates composition-stage compatibility: does an incoming tool, framework, or agent fit the Cortex ecosystem? Produces a fit report with forced-separation analysis and a Tech Radar ring signal.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `<X>` | Required | Incoming entity to evaluate | — |
| `against <Y>` | Optional | Existing context to compare against | Cortex ecosystem |

**Outputs**

| Artifact | Path | Contents |
|----------|------|----------|
| Fit report | `docs/cortex/fit/<slug>/fit-report.md` | 5-dimension forced-separation analysis, Tech Radar ring (Hold/Assess/Trial/Adopt), pre-populated clarify brief fields |

**Rules**
- SC2 forced-separation: no section may repeat content from another section.
- Status is always `pending-human-decision` — never auto-approves.
- Does NOT invoke `/cortex-clarify` — only pre-populates fields for optional use.

**State Effects**
- Writes fit report only. Does not modify `state.json` or `current-state.md`.

**Block Conditions**
- None.

**Example**
```
/cortex-fit "Mem0 memory layer" against "Cortex continuity system"
```

---

## /cortex-drive

**Syntax**
```bash
/cortex-drive [<idea>] [--to <mode>] [--autonomy <preset>]
```

**Purpose**
Autonomous lifecycle controller — drives a slug from clarify through done, making adaptive decisions at each transition. Invokes the appropriate Cortex command at each step.

**Inputs**

| Argument / Flag | Required | Description | Default |
|-----------------|----------|-------------|---------|
| `<idea>` | Optional | Start a new slug from scratch | Resume current slug |
| `--to <mode>` | Optional | Stop at this lifecycle mode | `done` |
| `--autonomy` | Optional | Override autonomy preset | Resolved from config |

**Outputs**

| Artifact | Path | Contents |
|----------|------|----------|
| Decision log | `docs/cortex/handoffs/decisions.md` | Autonomy decision entries for each transition |

**Rules**
- Always re-reads state from disk at the start of every iteration (never carries state in memory).
- Circuit breaker: same action failing 2x consecutively = stop and surface to human.
- Cortex-drive drives GSD — it does not execute tasks directly.
- Mandatory gates (`ux_taste_eval`, `human_action`, `reclarify`) are always HITL stops.

**State Effects**
- Delegates to individual commands — each command writes its own state effects.

**Block Conditions**
- Circuit breaker: 2 consecutive failures of the same action.
- Mandatory gate hits require human input.

**Example**
```
/cortex-drive "add rate limiting to the API"
/cortex-drive --to spec
```

---

## /cortex-stash

**Syntax**
```bash
/cortex-stash add "<idea>" [--context "..." | --no-context]
/cortex-stash list | show <id> | review | promote <id> | discard <id>
```

**Purpose**
Zero-friction capture of tangential ideas during active work. Global stash survives `/clear`, slug transitions, and project switches.

**Inputs**

| Subcommand | Required | Description |
|------------|----------|-------------|
| `add "<idea>"` | Required (for capture) | Idea text to stash |
| `--context` | Optional | Manual context override |
| `--no-context` | Optional | Skip auto-context capture |
| `list` | — | Show all stashed ideas |
| `show <id>` | — | Show a specific stash entry |
| `review` | — | Interactive triage of all entries |
| `promote <id>` | — | Promote to `/cortex-clarify` |
| `discard <id>` | — | Remove a stash entry |

**Outputs**

| Artifact | Path | Contents |
|----------|------|----------|
| Stash entry | `~/.cortex/stash/<id>-<label>.md` | Idea, context, timestamp, disposition |

**Rules**
- Stash is **global** (per-user, not per-project).
- Never modifies `state.json` or `current-state.md`.
- `add` is the only write operation. `list`, `show`, `review` are read-only. `promote` and `discard` delete entries.
- `disposition` is set at triage, not capture (always `explore` at capture time).

**State Effects**
- None — stash is independent of the Cortex lifecycle state.

**Block Conditions**
- None.

**Example**
```
/cortex-stash add "shared validator harness across phases"
/cortex-stash list
/cortex-stash promote 20260330T070001Z
```

---

## Flag Reference

| Flag | Commands | Values | Description |
|------|----------|--------|-------------|
| `--phase` | `/cortex-research` | `concept` \| `implementation` \| `evals` | Research phase; each produces a separate dossier |
| `--depth` | `/cortex-research` | `quick` \| `standard` \| `deep` | Controls research thoroughness and output length |
| `--team` | `/cortex-research` | (flag — no value) | Opt-in: invokes agent team for research; adds cost |
| `--write-plan` | `/cortex-research` | (flag — no value) | Writes `eval-plan.md` from `eval-proposal.md` after approval checks |
| `--slug` | `/cortex-bridge` | `<slug>` | Override active slug for bridge generation |
| `--to` | `/cortex-drive` | lifecycle mode name | Stop autonomous drive at this mode |
| `--autonomy` | `/cortex-clarify`, `/cortex-bridge`, `/cortex-drive` | `supervised` \| `gates-only` \| `full-auto` | Override autonomy preset for this invocation |
| `--context` | `/cortex-stash add` | `"text"` | Manual context override for stash entry |
| `--no-context` | `/cortex-stash add` | (flag — no value) | Skip auto-context capture |

---

## Artifact Path Quick Reference

All paths below are relative to the **target project repo** (the repo where Cortex is installed), not the Cortex framework repo.

```
docs/cortex/
├── clarify/<slug>/<timestamp>-clarify-brief.md
├── research/<slug>/<phase>-<timestamp>.md
├── specs/<slug>/spec.md
├── specs/<slug>/gsd-handoff.md
├── contracts/<slug>/contract-001.md
├── investigations/<slug>/...
├── reviews/<slug>/...
├── audits/<slug>/...
├── evals/<slug>/eval-proposal.md
├── evals/<slug>/eval-plan.md
├── experiments/<slug>/learning-contract-{id}.md
├── experiments/<slug>/experiment-result-{id}.md
├── fit/<slug>/fit-report.md
├── archive/<slug>/...
└── handoffs/decisions.md

~/.cortex/
└── stash/<id>-<label>.md

.cortex/
├── state.json
└── compaction/
    └── precompact-<timestamp>.md
```

See `docs/CONTINUITY.md` for continuity file schemas and `docs/EVALS.md` for the eval artifact lifecycle.
