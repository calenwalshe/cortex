# Agents

These agents are active in the current Cortex install layout under `.claude/agents/`.

---

## Agent Roster

| Agent | Role | Write Scope | Read Scope | Mode |
|-------|------|-------------|------------|------|
| `cortex-specifier` | Drafts specs and contracts from research dossiers | `docs/cortex/specs/`, `docs/cortex/contracts/` | All | Sub-agent |
| `cortex-critic` | Adversarial reviewer of specs, contracts, and decisions | None (read-only) | All | Sub-agent |
| `cortex-scribe` | Maintains continuity artifacts at session transitions | `docs/cortex/handoffs/`, `.cortex/` | All | Sub-agent |
| `cortex-eval-designer` | Proposes eval suites, rubrics, fixtures, and thresholds | `docs/cortex/evals/` | All | Sub-agent |

All paths above refer to the **target project repo** where Cortex is installed, not the Cortex framework repo.
The framework repo may still include `.cortex/` and `.planning/` for dogfooding and development, but runtime artifacts belong in the target project repo.

---

## Per-Agent Specifications

### cortex-specifier

cortex-specifier drafts specs and contracts from research dossiers and clarify briefs. It does not conduct research — it reads existing dossiers and clarify briefs as input. Its job is compression: turning a research dossier + clarify brief into a structured spec.md and first execution contract.

**Tools available:** File read tools (all paths), file write tools (restricted to write scope below), bash access for path operations only.

**Write permission scope:**
- `docs/cortex/specs/<slug>/` — spec.md, gsd-handoff.md
- `docs/cortex/contracts/<slug>/` — contract-001.md

**Read permission scope:** All files in the target repo and Cortex framework.

**Invocation:** Invoked as a sub-agent by `/cortex-spec`. Can also be invoked directly via `@cortex-specifier`.

**Output artifacts:**
- `docs/cortex/specs/<slug>/spec.md` — full problem spec with schema (problem, scope, arch decisions, interfaces, deps, risks, sequencing, tasks, acceptance criteria)
- `docs/cortex/specs/<slug>/gsd-handoff.md` — GSD-ready handoff pack
- `docs/cortex/contracts/<slug>/contract-001.md` — first execution contract

---

### cortex-critic

cortex-critic is a read-only adversarial reviewer. It reviews specs, contracts, and architectural decisions for logical gaps, missing edge cases, incorrect assumptions, and unstated dependencies. It does not propose fixes — it identifies problems and explains their potential impact.

**Tools available:** File read tools (all paths). No write tools. No bash access.

**Write permission scope:** None. cortex-critic never writes files directly to any path.

**Read permission scope:** All files in the target repo and Cortex framework.

**Invocation:** Invoked as a sub-agent by `/cortex-review` for contract compliance review. Can also be invoked directly via `@cortex-critic`. Available via `--team` flag in `/cortex-research`.

**Output artifacts:**
- Critique report returned inline or written to `docs/cortex/reviews/<slug>/` by the calling command (not by the agent itself, since critic is read-only).

---

### cortex-scribe

cortex-scribe maintains all continuity artifacts. It runs at session transitions, compaction events, and phase transitions. Its job is to ensure that repo-local artifacts always reflect the current state of work so that a stateless executor can resume without guessing.

**Tools available:** File read tools (all paths), file write tools (restricted to write scope below).

**Write permission scope:**
- `docs/cortex/handoffs/` — session handoff artifacts
- `.cortex/` — machine state files (state.json, compaction snapshots)

**Read permission scope:** All files in the target repo and Cortex framework.

**Invocation:** Invoked by hooks at session transitions, compaction events, and phase transitions. Can be invoked directly via `@cortex-scribe` or by running `/cortex-status`.

**Hook triggers:**

| Hook | Claude Code Event | When |
|------|------------------|------|
| `cortex-session-end` | Stop (async) | After every agent response turn — writes `current-state.md` from state.json |
| `cortex-precompact` | PreCompact | Before `/compact` — writes pre-compaction snapshot to `.cortex/compaction/` |
| `cortex-postcompact` | PostCompact | After `/compact` — writes `last-compact-summary.md` and refreshes `next-prompt.md` |

**Output artifacts:**
- `docs/cortex/handoffs/current-state.md` updates — current slug, mode, approval status, active contract, recent artifacts, open questions, blockers, next action
- `docs/cortex/handoffs/next-prompt.md` — short restart prompt for paste-after-/clear
- `docs/cortex/handoffs/decisions.md` — decision log entries
- `.cortex/state.json` — machine state updates
- `.cortex/compaction/precompact-<timestamp>.md` — pre-compaction snapshots

---

### cortex-eval-designer

cortex-eval-designer proposes eval suites. It reads the spec and contract, then proposes rubrics, fixtures, and thresholds for all relevant dimensions from the candidate eval matrix. It does not execute evals — it defines what they should look like.

**Tools available:** File read tools (all paths), file write tools (restricted to write scope below).

**Write permission scope:**
- `docs/cortex/evals/<slug>/` — eval proposals

**Read permission scope:** All files in the target repo and Cortex framework.

**Invocation:** Invoked as a sub-agent by `/cortex-research --phase evals`. Can also be invoked directly via `@cortex-eval-designer`.

**Output artifacts:**
- `docs/cortex/evals/<slug>/eval-proposal.md` — proposed dimensions, fixtures, rubrics, thresholds, failure taxonomy, and `approval_required` flag

---

## Permission Model

Write-restricted agents (specifier, scribe, eval-designer) can only write to their designated paths listed above. Any write attempt outside those paths is a violation of the permission model.

Read-only agents (critic) cannot write any files. cortex-critic produces output only as inline responses or as artifacts written by the calling command on its behalf.

No agent writes to `.planning/` — GSD owns all planning state. This is a hard constraint.

No agent writes outside `docs/cortex/` or `.cortex/` unless explicitly listed in their write scope above.

---

## Invocation

| Mode | How |
|------|-----|
| Sub-agent (standard) | Cortex commands invoke agents when needed — e.g. `/cortex-spec` invokes cortex-specifier |
| Team mode | `/cortex-research --team` invokes the full agent team for concept research |
| Direct invocation | `@cortex-specifier`, `@cortex-critic`, `@cortex-scribe`, `@cortex-eval-designer` |

### `--team` Flag Composition

When `/cortex-research --team` is invoked, the following agents run in parallel as sub-agents alongside the primary research executor:

| Agent | Role in team mode | What it does |
|-------|------------------|--------------|
| `cortex-critic` | Adversarial reviewer | Reviews research findings for logical gaps, unsupported assumptions, and missing edge cases. Returns a critique that is incorporated into the final dossier before it is written. |
| `cortex-specifier` | Compression synthesizer | Available to draft a preliminary problem frame or scope from early findings — useful when the research pass will immediately feed into `/cortex-spec`. |
| `cortex-eval-designer` | Eval candidate identifier | Flags which eval dimensions are likely to apply given the research findings — useful during concept research to anticipate eval complexity before the evals phase. |
| `cortex-scribe` | Continuity writer | Updates `current-state.md` and `next-prompt.md` after the team research completes, reflecting the new artifacts and next recommended action. |

**Coordination model:** The primary research executor runs the full research pipeline (all phases and tools). Sub-agents receive a copy of the synthesized findings and return their output concurrently. The primary executor merges agent outputs before writing the final dossier. cortex-critic's findings are incorporated as a "Critique" section. Agent team mode is opt-in and adds API cost — it is never the default.

---

## Installation

Agent markdown definitions are installed at `~/.claude/agents/`. The installer symlinks definitions from the Cortex repo into this path.

Installation path: `~/.claude/agents/cortex-specifier.md`, `~/.claude/agents/cortex-critic.md`, etc.
