# Cortex Command Reference

All commands write artifacts to the target project repo (the repo where Cortex is installed and used). The Cortex framework repo itself is not modified by command invocations.

Commands follow the intelligence spine: `/cortex-clarify` → `/cortex-research` → `/cortex-spec` → `/cortex-bridge` → `/cortex-ship` → `/cortex-close`. Validation commands (`/cortex-investigate`, `/cortex-review`, `/cortex-audit`) and utility commands (`/cortex-status`, `/cortex-fit`, `/cortex-stash`, `/cortex-drive`, `/cortex-intent`) can be invoked at any point.

<!-- THIS FILE IS AUTO-GENERATED from command-registry.json -->
<!-- Do not edit manually. Run: node scripts/cortex/generate-docs.js -->

---

## /cortex-audit

**Syntax**
```bash
/cortex-audit [<target>] [--comprehensive] [--diff] [--quick]
```

**Purpose**
Writes a security and quality audit artifact covering all 7 required audit lenses.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `<target>` | Optional | Scope to audit | — |
| `--comprehensive` | Optional | Extended audit depth | — |
| `--diff` | Optional | Audit only changed files | — |
| `--quick` | Optional | Quick surface-level audit | — |

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| Audit | `docs/cortex/audits/<slug>/<timestamp>.md` | findings per lens, severity ratings, remediation |

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `artifacts` | appends | `audit path` |

**Block Conditions**
- None

---

## /cortex-investigate

**Syntax**
```bash
/cortex-investigate [<subject>]
```

**Purpose**
Writes an investigation artifact with root cause analysis and optionally produces a repair contract.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `<subject>` | Optional | What to investigate — failure or unexpected behavior | — |

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| Investigation | `docs/cortex/investigations/<slug>/<timestamp>.md` | findings, root cause, evidence, repair recommendations |
| Repair contract (optional) | `docs/cortex/contracts/<slug>/contract-NNN.md` | repair scope from investigation |

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `artifacts` | appends | `investigation path` |

**Block Conditions**
- No slug AND no subject argument

---

## /cortex-review

**Syntax**
```bash
/cortex-review [<target>] [--security] [--pr N]
```

**Purpose**
Writes a review artifact evaluating the target against the active contract's done criteria and validators.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `<target>` | Optional | File, PR, or component to review | — |
| `--security` | Optional | Add security lens | — |
| `--pr` | Optional | Review a specific PR number | — |

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| Review | `docs/cortex/reviews/<slug>/<timestamp>.md` | review findings, contract compliance, recommendations |

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `artifacts` | appends | `review path` |
| `mode` | conditional | `repair (on P0 eval failures)` |

**Block Conditions**
- None

---

## /cortex-drive

**Syntax**
```bash
/cortex-drive [<idea>] [--to <mode>] [--autonomy <preset>] [--dry-run]
```

**Purpose**
Autonomous lifecycle controller — drives a slug from clarify through done with adaptive decisions at each transition.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `<idea>` | Optional | Start a new slug from scratch | — |
| `--to` | Optional | Stop at this lifecycle mode | — |
| `--autonomy` | Optional | Override autonomy preset | — |

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| Decision log | `docs/cortex/handoffs/decisions.md` | autonomy decision entries |

**Block Conditions**
- Circuit breaker (2 consecutive same-action failures)
- Mandatory gates
- Non-negotiable violations
- Kill criteria

---

## /cortex-fit

**Syntax**
```bash
/cortex-fit <X> [against <Y>]
```

**Purpose**
Evaluates composition-stage compatibility: does an incoming tool/framework/agent fit the Cortex ecosystem?

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `<X>` | Required | Incoming entity to evaluate | — |
| `against <Y>` | Optional | Existing context to compare against | — |

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| Fit report | `docs/cortex/fit/<slug>/fit-report.md` | 5-dimension analysis, Tech Radar ring, clarify brief fields |

**Block Conditions**
- None

---

## /cortex-intent

**Syntax**
```bash
/cortex-intent init|review|update|diff
```

**Purpose**
Manages the owner-intent.md and preferences.json artifacts that give Cortex a durable alignment layer.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `init` | Optional | Interactive bootstrap from CLAUDE.md and project history | — |
| `review` | Optional | Check staleness, contradictions, drift | — |
| `update <section>` | Optional | Targeted edit to section or preference | — |
| `diff` | Optional | Show changes since last confirmed version | — |

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| Owner intent | `docs/cortex/intent/owner-intent.md` | mission, objectives, metrics, non-negotiables, tradeoffs, kill criteria |
| Preferences | `docs/cortex/intent/preferences.json` | structured preference records with strength/confidence/staleness |

**Block Conditions**
- None

---

## /cortex-stash

**Syntax**
```bash
/cortex-stash add|list|show|review|promote|discard
```

**Purpose**
Zero-friction capture of tangential ideas during active work. Global stash survives /clear and slug transitions.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `add "<idea>"` | Optional | Stash an idea | — |
| `list|show|review|promote|discard` | Optional | Manage stash entries | — |

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| Stash entry | `~/.cortex/stash/<id>-<label>.md` | idea, context, timestamp, disposition |

**Block Conditions**
- None

---

## /cortex-status

**Syntax**
```bash
/cortex-status
```

**Purpose**
Reconstructs current working context from repo-local artifacts and updates continuity handoff files.

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| Current state | `docs/cortex/handoffs/current-state.md` | refreshed working state snapshot |
| Next prompt | `docs/cortex/handoffs/next-prompt.md` | paste-ready restart prompt |

**Block Conditions**
- None

---

## /cortex-clarify

**Syntax**
```bash
/cortex-clarify <idea> [--autonomy <preset>] [--gate <name>=<bool>] [--dry-run]
```

**Purpose**
Converts a fuzzy idea into a written problem frame (clarify brief) — the gate to all downstream research and spec work.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `<idea>` | Required | The idea, problem, or feature to clarify | — |
| `--autonomy` | Optional | Override autonomy preset (supervised, gates-only, full-auto) | — |
| `--gate` | Optional | Override a specific gate (repeatable) | — |
| `--dry-run` | Optional | Print resolved autonomy gate table without executing | — |

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| Clarify brief | `docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md` | goal, non-goals, constraints, assumptions, open questions, next research steps |

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `slug` | writes | `derived slug` |
| `mode` | writes | `clarify` |
| `approval_status` | writes | `pending` |
| `active_contract` | writes | `null` |
| `artifacts` | appends | `clarify brief path` |
| `gates.clarify_complete` | writes | `true` |

**Block Conditions**
- Warns (does NOT block) if state.json has a different active slug; requires user confirmation

---

## /cortex-research

**Syntax**
```bash
/cortex-research [<topic>] [--phase concept|implementation|evals] [--depth quick|standard|deep] [--team] [--write-plan]
```

**Purpose**
Produces a research dossier for the current slug at a specified phase and depth.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `<topic>` | Optional | Focus topic for this research pass | — |
| `--phase` | Optional | Research phase (concept, implementation, evals) | — |
| `--depth` | Optional | Research depth (quick, standard, deep) | — |
| `--team` | Optional | Invoke agent team for research | — |
| `--write-plan` | Optional | Write eval-plan.md from eval-proposal.md | — |

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| Research dossier | `docs/cortex/research/<slug>/<phase>-<timestamp>.md` | findings, trade-offs, recommendations, open questions |
| Eval proposal | `docs/cortex/evals/<slug>/eval-proposal.md` | proposed eval dimensions, fixtures, thresholds |
| Eval plan | `docs/cortex/evals/<slug>/eval-plan.md` | approved eval dimensions with execution plan |

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `mode` | writes | `research` |
| `artifacts` | appends | `dossier or eval proposal path` |
| `gates.research_complete` | writes | `true` |

**Block Conditions**
- No clarify brief exists for active slug

---

## /cortex-spec

**Syntax**
```bash
/cortex-spec [--autonomy <preset>] [--gate <name>=<bool>] [--dry-run]
```

**Purpose**
Compresses clarify brief and research into a spec, GSD handoff, and first execution contract.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `--autonomy` | Optional | Override autonomy preset | — |
| `--gate` | Optional | Override a specific gate | — |
| `--dry-run` | Optional | Print resolved gate table without executing | — |

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| Spec | `docs/cortex/specs/<slug>/spec.md` | problem, scope, architecture, interfaces, dependencies, risks, tasks, acceptance criteria |
| GSD handoff | `docs/cortex/specs/<slug>/gsd-handoff.md` | GSD-ready work order |
| Contract | `docs/cortex/contracts/<slug>/contract-001.md` | deliverables, done criteria, validators, repair budget |

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `mode` | writes | `spec` |
| `approval_status` | writes | `pending` |
| `active_contract` | writes | `contract path` |
| `gates.spec_complete` | writes | `true` |

**Block Conditions**
- No clarify brief
- No research dossier (unless trivial)
- reclarify_required is true
- Critical open questions unresolved

---

## /cortex-bridge

**Syntax**
```bash
/cortex-bridge [--slug <slug>] [--autonomy <preset>] [--gate <name>=<bool>] [--dry-run]
```

**Purpose**
Generates a complete GSD .planning/ scaffold from Cortex artifacts. Creates feature branch.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `--slug` | Optional | Override active slug | — |

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| GSD scaffold | `.planning/{PROJECT,ROADMAP,REQUIREMENTS,STATE,config}.{md,json}` | GSD milestone structure from spec and contract |

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `mode` | writes | `execute` |
| `artifacts` | appends | `all .planning/ paths` |

**Block Conditions**
- Missing spec, contract, or gsd-handoff for active slug

---

## /cortex-ship

**Syntax**
```bash
/cortex-ship [--issue <N>] [--draft] [--dry-run]
```

**Purpose**
Ships validated code to GitHub: creates branch, pushes, opens PR via /gsd:ship, writes PR state back to Cortex.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `--issue` | Optional | Link PR to GitHub issue #N | — |
| `--draft` | Optional | Open as draft PR | — |
| `--dry-run` | Optional | Show what would happen without side effects | — |

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `github.pr_number` | writes | `PR number` |
| `github.pr_url` | writes | `PR URL` |
| `gates.pr_opened` | writes | `true` |

**Block Conditions**
- No active slug
- Validators not passed
- Dirty working tree
- No GitHub remote
- gh not authenticated
- PR already opened

---

## /cortex-close

**Syntax**
```bash
/cortex-close
```

**Purpose**
Archives a completed slug: copies artifacts to cold path, closes linked GitHub issue, records closure, resets state.

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| Archive | `docs/cortex/archive/<slug>/` | copy of all slug artifacts |

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `slug` | writes | `null` |
| `mode` | writes | `done` |
| `gates` | writes | `all false` |

**Block Conditions**
- No active slug
- Slug confirmation mismatch

---

## /cortex-experiment

**Syntax**
```bash
/cortex-experiment <open|run|close>
```

**Purpose**
Manages the full lifecycle of a bounded hypothesis test: open, run, and close with a structured decision.

**Inputs**

| Argument | Required | Description | Default |
|----------|----------|-------------|---------|
| `open|run|close` | Required | Subcommand: start, orientation, or close experiment | — |

**Outputs**

| Artifact | Path | Contents |
|----------|------|---------|
| Learning contract | `docs/cortex/experiments/<slug>/learning-contract-<id>.md` | hypothesis, design, threshold, timebox |
| Experiment result | `docs/cortex/experiments/<slug>/experiment-result-<id>.md` | outcomes, learning, decision, rationale |

**State Effects**

| Field | Operation | Value |
|-------|-----------|-------|
| `mode` | writes | `experiment (open) / decision-driven (close)` |
| `experiment_complete` | writes | `true` |

**Block Conditions**
- No active slug (open)
- Mode not experiment (run/close)
- No open learning contract (close)

---

## Flag Reference

| Flag | Commands | Values | Description |
|------|----------|--------|-------------|
| `--comprehensive` | `/cortex-audit` | (flag — no value) | Extended audit depth |
| `--diff` | `/cortex-audit` | (flag — no value) | Audit only changed files |
| `--quick` | `/cortex-audit` | (flag — no value) | Quick surface-level audit |
| `--security` | `/cortex-review` | (flag — no value) | Add security lens |
| `--pr` | `/cortex-review` | (flag — no value) | Review a specific PR number |
| `--to` | `/cortex-drive` | (flag — no value) | Stop at this lifecycle mode |
| `--autonomy` | `/cortex-drive` | (flag — no value) | Override autonomy preset |
| `--autonomy` | `/cortex-clarify` | supervised \| gates-only \| full-auto | Override autonomy preset |
| `--gate` | `/cortex-clarify` | (flag — no value) | Override a specific gate (repeatable) |
| `--dry-run` | `/cortex-clarify` | (flag — no value) | Print resolved autonomy gate table without executing |
| `--phase` | `/cortex-research` | concept \| implementation \| evals | Research phase |
| `--depth` | `/cortex-research` | quick \| standard \| deep | Research depth |
| `--team` | `/cortex-research` | (flag — no value) | Invoke agent team for research |
| `--write-plan` | `/cortex-research` | (flag — no value) | Write eval-plan.md from eval-proposal.md |
| `--autonomy` | `/cortex-spec` | (flag — no value) | Override autonomy preset |
| `--gate` | `/cortex-spec` | (flag — no value) | Override a specific gate |
| `--dry-run` | `/cortex-spec` | (flag — no value) | Print resolved gate table without executing |
| `--slug` | `/cortex-bridge` | (flag — no value) | Override active slug |
| `--issue` | `/cortex-ship` | (flag — no value) | Link PR to GitHub issue #N |
| `--draft` | `/cortex-ship` | (flag — no value) | Open as draft PR |
| `--dry-run` | `/cortex-ship` | (flag — no value) | Show what would happen without side effects |

---

## Artifact Path Quick Reference

All paths below are relative to the **target project repo**.

```
docs/cortex/
├── archive/<slug>/
├── audits/<slug>/<timestamp>.md
├── clarify/<slug>/<timestamp>-clarify-brief.md
├── contracts/<slug>/contract-001.md
├── contracts/<slug>/contract-NNN.md
├── evals/<slug>/eval-plan.md
├── evals/<slug>/eval-proposal.md
├── experiments/<slug>/experiment-result-<id>.md
├── experiments/<slug>/learning-contract-<id>.md
├── fit/<slug>/fit-report.md
├── handoffs/current-state.md
├── handoffs/decisions.md
├── handoffs/next-prompt.md
├── intent/owner-intent.md
├── intent/preferences.json
├── investigations/<slug>/<timestamp>.md
├── research/<slug>/<phase>-<timestamp>.md
├── reviews/<slug>/<timestamp>.md
├── specs/<slug>/gsd-handoff.md
├── specs/<slug>/spec.md

.cortex/
├── state.json
└── compaction/
    └── precompact-<timestamp>.md
```

See `docs/CONTINUITY.md` for continuity file schemas and `docs/EVALS.md` for the eval artifact lifecycle.
