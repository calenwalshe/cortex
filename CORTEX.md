# Cortex

> A lifecycle intelligence system that sits above GSD. Cortex converts fuzzy ideas
> into GSD-ready execution contracts via 7 commands and a sequential spine. GSD
> remains the workflow owner; Cortex adds the intelligence layer — clarifying,
> researching, speccing, validating, repairing, and assuring so that execution is
> always grounded in a clear definition of done.

## Layer Architecture

| Layer | Owner | Scope | Question |
|-------|-------|-------|----------|
| 1. Workflow | GSD | Execution, phases, milestones | "What do I do next?" |
| 2. Intelligence | Cortex | Clarify → spec → validate → repair → assure | "Is this the right thing to build, and is it correct?" |
| 3. Discipline | Superpowers extracts | During implementation | "Am I writing this correctly?" |
| 4. Thinking | GStack extracts | Always on | "Am I reasoning honestly?" |

## 8-Command Surface

| Command | Purpose | Output Artifact |
|---------|---------|----------------|
| `/cortex-clarify` | Convert a fuzzy idea into a written problem frame with goal, non-goals, constraints, assumptions, and open questions | `docs/cortex/clarify/<slug>/<timestamp>-clarify-brief.md` |
| `/cortex-research` | Run concept, implementation, or eval research with configurable depth, optional team mode, and optional eval-plan write step (`--write-plan`) | `docs/cortex/research/<slug>/<phase>-<timestamp>.md` (concept/implementation) or `docs/cortex/evals/<slug>/eval-proposal.md` / `eval-plan.md` |
| `/cortex-spec` | Compress clarify + research into a GSD-ready handoff pack, spec.md, and first execution contract | `docs/cortex/specs/<slug>/spec.md`, `gsd-handoff.md`; `docs/cortex/contracts/<slug>/contract-001.md` |
| `/cortex-investigate` | Write investigation artifacts and optionally hand off into a GSD repair contract | `docs/cortex/investigations/<slug>/` |
| `/cortex-review` | Review implementation against contract compliance and quality lenses | `docs/cortex/reviews/<slug>/` |
| `/cortex-audit` | Write security/correctness audit with required lenses (auth, data, secrets, unsafe tools, input validation, deps, misuse) | `docs/cortex/audits/<slug>/` |
| `/cortex-status` | Reconstruct current state from repo-local artifacts; update continuity handoff files | `.cortex/state.json`, `docs/cortex/` continuity files |
| `/cortex-experiment` | Open a bounded hypothesis test, run it, and close with a decision (promote/iterate/re-clarify/abandon) | `docs/cortex/experiments/<slug>/learning-contract-{id}.md` (open), `experiment-result-{id}.md` (close) |

## Artifact Roots

Both artifact roots live in the **target project repo** — the repository where Cortex is being used, not in the Cortex framework repo itself.

| Root | Location | Contents |
|------|----------|----------|
| `docs/cortex/` | Target project repo | Human-readable intelligence artifacts: clarify briefs, research dossiers, specs, GSD handoffs, contracts, eval proposals, eval plans, investigations, reviews, audits |
| `.cortex/` | Target project repo | Machine state: `state.json`, `dirty-files.json`, compaction snapshots, validator results, continuity files |

> **These paths are in the project where Cortex is used, not in the Cortex framework repo itself.**
> The framework repo may still include `.cortex/` and `.planning/` for dogfooding and development, but runtime command output belongs to the target project repo.

## Ownership Boundary

| Owner | Owns |
|-------|------|
| GSD | `.planning/`, `STATE.md`, phases, milestones, roadmaps, execution |
| Cortex | `docs/cortex/` and `.cortex/` in the target repo, intelligence artifacts, continuity state |

**Hard constraint: Cortex never writes to `.planning/`. GSD owns all workflow state.**

## Sequential Spine

The full lifecycle from idea to done follows a fixed spine:

1. **clarify** — the idea is framed as a problem: goal, non-goals, constraints, assumptions, open questions.
2. **research** — concept, implementation, and/or eval research produces a dossier.
3. **spec** — clarify + research compress into a `spec.md`, `gsd-handoff.md`, and a `contract-001.md`. The spec must be approved before execution begins.
4. **[GSD execute]** — execution is handed to GSD. GSD reads `gsd-handoff.md` as its work-order and owns the phase/plan lifecycle. Cortex does not touch `.planning/` during this stage.
5. **validate** — after GSD completes, Cortex picks up by running validators defined in the contract. Artifacts are checked against done criteria.
6. **repair** — if validators fail, a repair contract opens. Repair feeds back to validate (not back to clarify).
7. **assure** — all validators pass; eval suite runs; human approval is obtained if required.
8. **done** — the contract is closed; continuity artifacts are updated.

The pre-spec phases (clarify → research → spec) operate as a discovery loop, not a strict sequence. Research evidence can return the flow to clarify (`reclarify_required: true`). A critical uncertainty that cannot be resolved by research opens an experiment. Only when all three spec-readiness blockers clear does `/cortex-spec` permit commitment. See `docs/DISCOVERY_LOOP.md` for the full loop design: mode transitions, spec-readiness gate, write-root policy, and convergence guardrails.

See `docs/INTELLIGENCE_FLOW.md` for the full ASCII spine diagram with loop annotations and gate conditions.

## Continuity Model

Chat history is ephemeral. All Cortex state lives in repo-local artifacts under `docs/cortex/` and `.cortex/`. After `/clear` or compaction, running `/cortex-status` reconstructs current context from `current-state.md`, `next-prompt.md`, and the active contract — no context is lost between sessions.

## Layer Activation Rules

### Layer 1: Workflow (GSD)
- **Activates:** Session start, `/gsd:*` commands, phase transitions
- **Owns:** `.planning/`, `STATE.md`, phases, milestones, roadmaps
- **Rule:** No other layer writes to `.planning/` or manages workflow state
- **Source:** Runs as-is from `~/.claude/get-shit-done/` (not extracted)
- **Cortex note:** `/cortex-*` commands operate during the intelligence phase — clarify, research, spec, validate, repair, assure — before and after GSD execution. They sit alongside GSD, not inside it.

### Layer 2: Discipline (Superpowers Extracts)
- **Activates:** During code implementation tasks
- **Owns:** Coding standards — TDD enforcement, design-before-code, debugging protocol
- **Rule:** These are behavioral rules that enhance GSD tasks, not replace them.
  When GSD says "execute task 3", Layer 2 says "write the test first."
- **Source:** Extracted from `upstream/superpowers/`, adapted for Cortex

### Layer 3: Thinking (GStack Extracts)
- **Activates:** Always on (injected at session start)
- **Owns:** Reasoning quality — anti-sycophancy, honest pushback, security thinking
- **Rule:** These are passive behavioral modifiers. They shape HOW Claude reasons
  without dictating WHAT to do. Never conflict with workflow orchestration.
- **Source:** Extracted from `upstream/gstack/`, adapted for Cortex

## Collision Prevention

1. **GSD owns all state.** No other layer writes to `.planning/` or `STATE.md`.
2. **Discipline rules are behavioral, not orchestrational.** They say "write tests first" not "now run this workflow."
3. **Thinking rules are always-on but passive.** They shape HOW Claude reasons without dictating WHAT to do.
4. **Skill namespace:** All Cortex skills use `/cortex-*` prefix (8 skills total). No collision with `/gsd:*` or any upstream skill namespace.
5. **No duplicate review loops.** GSD's verify-work IS the review gate. Discipline and thinking layers enhance that gate's quality.
6. **Cortex never writes to `.planning/`** — GSD owns all workflow state.

## File Structure

```
cortex/
├── CORTEX.md                  # This file — master reference
├── layers/
│   ├── workflow/               # Layer 1: GSD integration notes
│   ├── discipline/             # Layer 2: Superpowers extracts
│   │   ├── tdd.md
│   │   ├── design-first.md
│   │   ├── debugging.md
│   │   └── code-review.md
│   └── thinking/               # Layer 3: GStack extracts
│       ├── anti-sycophancy.md
│       ├── forcing-questions.md
│       ├── investigate.md
│       └── security-audit.md
├── skills/                     # Cortex user-facing commands (Layer 2)
│   ├── cortex-status/
│   ├── cortex-review/
│   ├── cortex-investigate/
│   ├── cortex-audit/
│   ├── cortex-clarify/
│   ├── cortex-research/
│   ├── cortex-experiment/
│   └── cortex-spec/
├── .claude/
│   ├── agents/                 # Installed: 4 agents (cortex-specifier, cortex-critic,
│   │                           # cortex-scribe, cortex-eval-designer)
│   ├── hooks/                  # Installed: 11 hook scripts
│   └── settings.json           # Global hook wiring across 9 Claude Code events
├── bin/                        # Scripts
│   ├── install.sh
│   ├── sync-upstream.sh
│   └── uninstall.sh
├── upstream/                   # Tracked upstream sources
│   ├── UPSTREAM.md
│   ├── gsd/
│   ├── superpowers/
│   └── gstack/
└── docs/                       # Architecture and reference docs
    ├── INTELLIGENCE_FLOW.md    # Sequential spine diagram with loops and gates
    ├── COMMANDS.md             # 7-command reference with inputs, outputs, rules
    ├── CONTINUITY.md           # Continuity strategy and artifact schemas
    ├── EVALS.md                # Eval lifecycle, matrix, and harness guide
    └── AGENTS.md               # Agent roster, tools, permission modes
```
