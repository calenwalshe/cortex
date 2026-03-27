# Cortex

> A unified Claude Code operating framework that harmonizes GSD, Superpowers,
> and GStack into a single, non-conflicting system.

## Architecture

Cortex separates three frameworks by **concern**, not by tool:

| Layer | Owner | Scope | Question |
|-------|-------|-------|----------|
| 1. Workflow | GSD | Session start, phase transitions | "What should I do next?" |
| 2. Discipline | Superpowers extracts | During implementation | "Am I writing this correctly?" |
| 3. Thinking | GStack extracts | Always on (behavioral) | "Am I reasoning honestly?" |

## Layer Activation Rules

### Layer 1: Workflow (GSD)
- **Activates:** Session start, `/gsd:*` commands, phase transitions
- **Owns:** `.planning/`, `STATE.md`, phases, milestones, roadmaps
- **Rule:** No other layer writes to `.planning/` or manages workflow state
- **Source:** Runs as-is from `~/.claude/get-shit-done/` (not extracted)

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

1. **GSD owns all state.** No other layer writes to .planning/ or STATE.md.
2. **Discipline rules are behavioral, not orchestrational.** They say "write
   tests first" not "now run this workflow."
3. **Thinking rules are always-on but passive.** They shape HOW Claude reasons
   without dictating WHAT to do.
4. **Skill namespace:** All Cortex skills use `/cortex-*` prefix. No collision
   with `/gsd:*` or any upstream skill namespace.
5. **No duplicate review loops.** GSD's verify-work IS the review gate.
   Discipline and thinking layers enhance that gate's quality.

## Upstream Tracking

Cortex tracks three upstream repos. See `upstream/UPSTREAM.md` for:
- Current pinned versions
- What files were extracted from where
- How to sync when upstreams update

```bash
# Sync upstreams to latest
bin/sync-upstream.sh
```

## Installation

```bash
# Clone with submodules
git clone --recurse-submodules <cortex-repo-url> ~/projects/cortex

# Install (symlinks layers into ~/.claude/)
bin/install.sh

# Verify
/cortex-status
```

## File Structure

```
cortex/
├── CORTEX.md              # This file — master config
├── layers/
│   ├── workflow/           # Layer 1: GSD integration notes
│   ├── discipline/         # Layer 2: Superpowers extracts
│   │   ├── tdd.md
│   │   ├── design-first.md
│   │   ├── debugging.md
│   │   └── code-review.md
│   └── thinking/           # Layer 3: GStack extracts
│       ├── anti-sycophancy.md
│       ├── forcing-questions.md
│       ├── investigate.md
│       └── security-audit.md
├── skills/                 # Cortex-specific skills
│   ├── cortex-status/
│   ├── cortex-review/
│   ├── cortex-investigate/
│   └── cortex-audit/
├── agents/                 # Subagent definitions
├── hooks/                  # Session hooks
├── bin/                    # Scripts
│   ├── install.sh
│   ├── sync-upstream.sh
│   └── uninstall.sh
└── upstream/               # Tracked upstream sources
    ├── UPSTREAM.md
    ├── gsd/                # Local copy (reference only)
    ├── superpowers/        # Git submodule
    └── gstack/             # Git submodule
```
