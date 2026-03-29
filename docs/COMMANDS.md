# Cortex Command Reference

All commands write artifacts to the target project repo (the repo where Cortex is installed and used). The Cortex framework repo itself is not modified by command invocations.

Commands follow the intelligence spine: `/cortex-clarify` → `/cortex-research` → `/cortex-spec` → (GSD execution) → `/cortex-investigate` / `/cortex-review` / `/cortex-audit` → `/cortex-status`.

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

**Example**
```
/cortex-clarify "add smart retry logic to the API client"
```

---

## /cortex-research

**Syntax**
```bash
/cortex-research [<topic>] [--phase concept|implementation|evals] [--depth quick|standard|deep] [--team]
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

**Outputs**

| Artifact | Path | Contents |
|----------|------|----------|
| Research dossier | `docs/cortex/research/<slug>/<phase>-<timestamp>.md` | Findings, trade-offs, recommendations, open questions for the requested phase |

**Rules**
- Reads the clarify brief as primary input context. Clarify brief must exist.
- Each `--phase` produces a separate dossier — phases are not combined in a single output.
- `--phase evals` produces an eval proposal (see `/cortex-audit` and `docs/EVALS.md`).
- Each phase must be explicitly requested by the human — the system does not auto-advance to the next phase.
- `--team` is opt-in only. Agent team mode is never default behavior.
- Current SKILL.md uses legacy `--quick` / `--deep` flags and writes to `~/research/`. This document describes the vNext interface. SKILL.md will be updated in Phase 3.

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

**Example**
```
/cortex-status
```

---

## Flag Reference

| Flag | Commands | Values | Description |
|------|----------|--------|-------------|
| `--phase` | `/cortex-research` | `concept` \| `implementation` \| `evals` | Research phase; each produces a separate dossier |
| `--depth` | `/cortex-research` | `quick` \| `standard` \| `deep` | Controls research thoroughness and output length |
| `--team` | `/cortex-research` | (flag — no value) | Opt-in: invokes agent team for research; adds cost |

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
└── evals/<slug>/eval-plan.md

.cortex/
├── state.json
└── compaction/
    └── precompact-<timestamp>.md
```

See `docs/CONTINUITY.md` for continuity file schemas and `docs/EVALS.md` for the eval artifact lifecycle.
