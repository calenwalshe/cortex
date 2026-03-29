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

```bash
# Clone the repo
git clone https://github.com/calenwalshe/cortex.git ~/projects/cortex

# Run the installer (symlinks skills, agents, hooks into ~/.claude/)
node ~/projects/cortex/bin/install.js

# Or via the shell wrapper
bash ~/projects/cortex/dotfiles-setup.sh
```

Once installed, start with `/cortex-clarify <your idea>` to begin the intelligence cycle. The clarify command produces a written problem frame you can review before committing to research and spec work.

## Structure

```
cortex/                          # Framework repo
├── CORTEX.md                    # Architecture reference
├── docs/
│   ├── INTELLIGENCE_FLOW.md    # Sequential spine diagram
│   ├── COMMANDS.md             # 7-command reference
│   ├── CONTINUITY.md           # Continuity strategy + schemas + contract loop
│   ├── EVALS.md                # Eval lifecycle + 8-dimension matrix
│   └── AGENTS.md               # Agent roster + permissions
├── skills/
│   ├── cortex-clarify/         # Fuzzy idea → clarify brief
│   ├── cortex-research/        # Research dossier (concept/impl/evals + approval gate)
│   ├── cortex-spec/            # Spec + GSD handoff + contract
│   ├── cortex-investigate/     # Investigation artifacts
│   ├── cortex-review/          # Review + contract compliance + repair-on-failure
│   ├── cortex-audit/           # Security + quality audit (7 lenses)
│   └── cortex-status/          # State reconstruction after /clear or compaction
├── .claude/
│   ├── agents/                 # 4 subagents: specifier, critic, scribe, eval-designer
│   ├── hooks/                  # 10 hooks: session lifecycle, phase guard, task gating
│   └── settings.json           # Hook event registrations (9 events)
├── templates/cortex/           # Artifact templates (clarify, research, spec, contract, evals)
├── scripts/cortex/             # scaffold_runtime.sh — bootstrap docs/cortex/ in target repos
├── bin/                        # install.js — idempotent installer with --dry-run support
├── dotfiles-setup.sh           # Shell wrapper for bin/install.js
├── layers/                     # Discipline + Thinking rule extracts
└── upstream/                   # Tracked upstream sources (Superpowers, GStack)
```

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
