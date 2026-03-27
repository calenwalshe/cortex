# Cortex

A unified Claude Code operating framework that harmonizes **GSD**, **Superpowers**, and **GStack** into a single, non-conflicting system.

## The Problem

Three excellent frameworks exist for Claude Code — GSD (workflow management), Superpowers (coding discipline), and GStack (strategic thinking). All three try to own the plan-execute-verify loop. Installing them together creates conflicting orchestration instructions.

## The Solution

Cortex separates them by **concern**:

| Layer | Source | What It Owns | When Active |
|-------|--------|-------------|-------------|
| **Workflow** | GSD (as-is) | State, phases, milestones | Session start, phase transitions |
| **Discipline** | Superpowers (extracted) | TDD, debugging, code review | During implementation |
| **Thinking** | GStack (extracted) | Anti-sycophancy, forcing questions, security | Always on |

No collisions because each layer answers a different question:
- GSD: "What should I do next?"
- Superpowers: "Am I writing this correctly?"
- GStack: "Am I reasoning honestly?"

## Quick Start

```bash
# Clone with submodules
git clone --recurse-submodules <repo-url> ~/projects/cortex

# Add the behavioral rules to your CLAUDE.md
cat ~/projects/cortex/CLAUDE.md.snippet >> ~/.claude/CLAUDE.md

# Sync upstreams when needed
~/projects/cortex/bin/sync-upstream.sh
```

## Upstream Tracking

Cortex tracks three upstream repos and extracts specific components:

| Upstream | Type | Extracted Components |
|----------|------|---------------------|
| [obra/superpowers](https://github.com/obra/superpowers) | Git submodule | TDD, debugging, code review |
| [garrytan/gstack](https://github.com/garrytan/gstack) | Git submodule | Anti-sycophancy, forcing questions, /investigate, /cso |
| GSD | Local copy | Reference only (runs as-is) |

See `upstream/UPSTREAM.md` for the full extraction mapping.

## Structure

See `CORTEX.md` for the full architecture and layer activation rules.
