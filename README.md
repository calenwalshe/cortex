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

### The 16-Command Surface

Cortex adds 16 commands to your Claude Code workflow:

| Command | What it does |
|---------|-------------|
| `/cortex-clarify` | Converts a fuzzy idea into a written clarify brief — goal, non-goals, constraints, assumptions, open questions, next research steps |
| `/cortex-research` | Runs research in one of three phases: `concept`, `implementation`, or `evals`. Supports `--depth quick|standard|deep`, `--team`, and `--write-plan` for eval plan generation after approval checks. |
| `/cortex-spec` | Compresses clarify brief + research dossier into a GSD-ready handoff pack, spec.md, and first execution contract |
| `/cortex-bridge` | Generates a complete GSD `.planning/` scaffold from Cortex artifacts (one-time handoff rendering) |
| `/cortex-investigate` | Writes investigation artifacts to `docs/cortex/investigations/` in the target repo; can hand off into a GSD repair contract |
| `/cortex-review` | Writes review artifacts to `docs/cortex/reviews/` including a contract compliance lens |
| `/cortex-audit` | Writes audit artifacts to `docs/cortex/audits/` with required lenses: auth, data, secrets, unsafe tools, input validation, deps, misuse |
| `/cortex-experiment` | Opens a bounded hypothesis test, runs it, and closes with a decision (promote/iterate/re-clarify/abandon) |
| `/cortex-status` | Reconstructs current state from repo-local artifacts and updates the continuity handoff files — the recovery command after `/clear` or compaction |
| `/cortex-close` | Archives a completed slug: copies artifacts to cold path, records close in decisions.md, resets state |
| `/cortex-stash` | Captures an idea for later without starting the full pipeline |
| `/cortex-fit` | Composition-stage compatibility check for cross-artifact coherence |
| `/cortex-drive` | Autonomous lifecycle controller — drives a slug from clarify through done with adaptive decisions |
| `/cortex-parallel` | Create isolated worktree for parallel builds — multiple slugs building concurrently without conflict |

Commands run in spine order for new work: clarify → research → spec → [GSD execute] → validate → repair → assure → done. Investigate, review, and audit can run at any time.

Runtime artifacts are written to the **target project repo** where Cortex is installed (for example `docs/cortex/` and `.cortex/`); this framework repo may still contain `.cortex/` and `.planning/` for dogfooding and development.

## Quick Start

```bash
# Clone the repo
git clone https://github.com/calenwalshe/cortex.git ~/projects/cortex

# Install — core profile (default): framework skills only, no external API dependencies
node ~/projects/cortex/bin/install.js

# Install — full profile: framework skills + tool skills (power-search, google, cli)
node ~/projects/cortex/bin/install.js --profile=full

# Bootstrap runtime artifacts in your target project repo
node ~/projects/cortex/bin/install.js --project /path/to/your/project

# Dry run (show what would be installed without writing anything)
node ~/projects/cortex/bin/install.js --dry-run

# Verbose output (show every symlink and wiring step)
node ~/projects/cortex/bin/install.js --verbose
```

### Install Profiles

| Profile | Skills installed | Use when |
|---------|-----------------|----------|
| `core` (default) | All `cortex-*` framework skills | Behind a corporate firewall, no external API access, or maintaining a downstream fork |
| `full` | Framework skills + `power-search`, `google`, `cli` tool skills + `power-search` pip package | Full local development with Tavily, Perplexity, Gemini, Gmail, etc. |

The active profile is written to `~/.claude/.cortex-profile` after each install. Re-running with a different profile upgrades or downgrades the tool skill set without touching framework skills.

For downstream fork setup (e.g. cloning Cortex into a Meta internal environment), see [`DOWNSTREAM.md`](./DOWNSTREAM.md).

The `--project` step scaffolds `docs/cortex/` and `.cortex/` in your target repo, including `.cortex/state.json` and `.cortex/dirty-files.json`, so hooks and runtime state work immediately.
Runtime inventory and hook wiring are defined in `runtime-manifest.json`; installer behavior and installer tests read from that manifest as the single source of truth.

Once installed and bootstrapped, start with `/cortex-clarify <your idea>` to begin the intelligence cycle. The clarify command produces a written problem frame you can review before committing to research and spec work.

## Structure

```
cortex/                          # Framework repo
├── CORTEX.md                    # Architecture reference
├── docs/
│   ├── INTELLIGENCE_FLOW.md    # Sequential spine diagram
│   ├── COMMANDS.md             # Command reference
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
│   ├── cortex-status/          # State reconstruction after /clear or compaction
│   ├── power-search/           # Tool skill: unified search/AI router — Tavily, Jina, Firecrawl, Crawl4AI, Perplexity, Gemini, GPT (--profile=full)
│   ├── google/                 # Tool skill: Gmail, Drive, Stitch (--profile=full)
│   └── cli/                    # Tool skill: context-aware shell execution (--profile=full)
├── .claude/
│   ├── agents/                 # Subagent definitions
│   ├── hooks/                  # Hook scripts (session lifecycle, phase guard, task gating)
│   └── settings.json           # Project-local hook event wiring (uses $CLAUDE_PROJECT_DIR)
├── runtime-manifest.json       # Single source of truth for runtime inventory + hook event wiring
├── templates/cortex/           # Artifact templates (clarify, research, spec, contract, evals)
├── scripts/cortex/             # scaffold_runtime.sh — bootstrap docs/cortex/ in target repos
├── bin/                        # install.js — idempotent installer with --profile and --dry-run support
├── DOWNSTREAM.md               # Downstream fork guide — arc diff workflow, .arcconfig template
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
