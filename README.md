# Cortex

A lifecycle intelligence system for Claude Code — converts fuzzy ideas into GSD-ready execution contracts with contract-gated execution, compaction-proof continuity, and first-class evals.

## The Problem

Three excellent frameworks exist for Claude Code — GSD (workflow management), Superpowers (coding discipline), and GStack (strategic thinking). They complement each other, but they create a structural gap: none of them own the space between "I have an idea" and "I have a GSD-ready plan."

Ideas get turned into code without adequate problem framing, research, or eval coverage. Context is lost after `/clear` or compaction because chat history is not a durable store. Done criteria are ambiguous — "it works" is not a validator. And when something breaks, there is no documented contract to diff against.

The result is drift: what gets built diverges from what was meant, and there is no artifact trail to recover from.

## The Solution

Cortex adds an intelligence layer that sits between idea and execution. GSD still owns workflow — phases, milestones, task execution. Cortex owns everything that should happen before and after: problem framing, research, spec, contract authoring, continuity, evals, and repair.

### Layer Architecture

| Layer | Owner | Scope |
|-------|-------|-------|
| **Workflow** | GSD (as-is) | State, phases, milestones, task execution |
| **Intelligence** | Cortex | Clarify → research → spec → validate → repair → assure |
| **Discipline** | Superpowers extracts | During implementation — TDD, debugging, code review |
| **Thinking** | GStack extracts | Always on — anti-sycophancy, forcing questions, security |

No layer owns what another layer owns. GSD does not adjudicate on spec quality. Cortex does not manage phases. Discipline rules apply during implementation, not during planning.

### The 7-Command Surface

Cortex adds 7 commands to your Claude Code workflow:

| Command | What it does |
|---------|-------------|
| `/cortex-clarify` | Converts a fuzzy idea into a written clarify brief — goal, non-goals, constraints, assumptions, open questions, next research steps |
| `/cortex-research` | Runs research in one of three phases: `concept`, `implementation`, or `evals`. Supports `--depth quick|standard|deep` and `--team` for agent-team mode. |
| `/cortex-spec` | Compresses clarify brief + research dossier into a GSD-ready handoff pack, spec.md, and first execution contract |
| `/cortex-investigate` | Writes investigation artifacts to `docs/cortex/investigations/` in the target repo; can hand off into a GSD repair contract |
| `/cortex-review` | Writes review artifacts to `docs/cortex/reviews/` including a contract compliance lens |
| `/cortex-audit` | Writes audit artifacts to `docs/cortex/audits/` with required lenses: auth, data, secrets, unsafe tools, input validation, deps, misuse |
| `/cortex-status` | Reconstructs current state from repo-local artifacts and updates the continuity handoff files — the recovery command after `/clear` or compaction |

Commands run in spine order for new work: clarify → research → spec → [GSD execute] → validate → repair → assure → done. Investigate, review, and audit can run at any time.

## Quick Start

> **Installer update in progress (Phase 6).** The installer is being revised as part of vNext. Use the manual install for now.

```bash
# Clone the repo
git clone https://github.com/calenwalshe/cortex.git ~/projects/cortex

# Run the installer
node ~/projects/cortex/bin/install.js
```

Once installed, start with `/cortex-clarify <your idea>` to begin the intelligence cycle. The clarify command produces a written problem frame you can review before committing to research and spec work.

## Structure

```
cortex/                          # Framework repo
├── CORTEX.md                    # Architecture reference
├── docs/
│   ├── INTELLIGENCE_FLOW.md    # Sequential spine diagram
│   ├── COMMANDS.md             # 7-command reference
│   ├── CONTINUITY.md           # Continuity strategy + schemas
│   ├── EVALS.md                # Eval lifecycle + matrix
│   └── AGENTS.md               # Agent roster + permissions
├── skills/
│   ├── cortex-clarify/         # Fuzzy idea → clarify brief  [Phase 3]
│   ├── cortex-research/        # Research dossier (concept/impl/evals)
│   ├── cortex-spec/            # Spec + GSD handoff + contract  [Phase 3]
│   ├── cortex-investigate/     # Investigation artifacts
│   ├── cortex-review/          # Review + contract compliance
│   ├── cortex-audit/           # Security + quality audit
│   └── cortex-status/          # State reconstruction
├── agents/                      # Phase 4: 4 subagents
├── hooks/                       # Phase 4: 10 hooks
├── bin/                         # Installer + utilities
├── layers/                      # Discipline + Thinking rule extracts
└── upstream/                    # Tracked upstream sources
```

`cortex-clarify` and `cortex-spec` skills are Phase 3 deliverables — not yet implemented. `agents/` and `hooks/` are Phase 4 deliverables.

## Upstream Tracking

Cortex tracks two upstream repos and extracts specific behavioral rules:

| Upstream | Type | Extracted Components |
|----------|------|---------------------|
| [obra/superpowers](https://github.com/obra/superpowers) | Git submodule | TDD, debugging, code review |
| [garrytan/gstack](https://github.com/garrytan/gstack) | Git submodule | Anti-sycophancy, forcing questions, /investigate, /cso |
| GSD | Local copy | Reference only (runs as-is) |

See `upstream/UPSTREAM.md` for the full extraction mapping.

## Architecture Reference

See `CORTEX.md` for the full architecture and layer activation rules. See `docs/` for detailed references on commands, continuity, evals, and agents.
