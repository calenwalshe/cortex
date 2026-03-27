# Upstream Sources

Cortex extracts and harmonizes components from three upstream frameworks.
This file tracks what version each upstream is at and what we extracted.

## Tracking

| Upstream | Type | Source | Pinned At |
|----------|------|--------|-----------|
| GSD | Local copy | ~/projects/get-shit-done | Manual sync |
| Superpowers | Git submodule | github.com/obra/superpowers | v5.0.6 (eafe962) |
| GStack | Git submodule | github.com/garrytan/gstack | v0.12.12.0 (11695e3) |

## Update Process

```bash
# Update submodules to latest
cd ~/projects/cortex
bin/sync-upstream.sh

# This will:
# 1. git submodule update --remote upstream/superpowers upstream/gstack
# 2. Diff upstream changes against what Cortex extracted
# 3. Flag files that changed upstream and may need re-extraction
# 4. GSD: manual copy from ~/projects/get-shit-done
```

## What We Extract (And Where From)

### From Superpowers (Layer 2: Discipline)
| Extract | Source File | Cortex Location |
|---------|------------|-----------------|
| TDD enforcement rules | skills/test-driven-development/ | layers/discipline/tdd.md |
| Systematic debugging | skills/systematic-debugging/ | layers/discipline/debugging.md |
| Code review standards | skills/receiving-code-review/ | layers/discipline/code-review.md |
| Design-first gate | skills/brainstorming/ | layers/discipline/design-first.md |
| Code reviewer agent | agents/code-reviewer.md | agents/code-reviewer.md |

### From GStack (Layer 3: Thinking)
| Extract | Source File | Cortex Location |
|---------|------------|-----------------|
| Anti-sycophancy rules | office-hours/*.tmpl (~lines 89-151) | layers/thinking/anti-sycophancy.md |
| 6 forcing questions | office-hours/*.tmpl (~lines 152-235) | layers/thinking/forcing-questions.md |
| /investigate protocol | investigate/*.tmpl | layers/thinking/investigate.md |
| /cso security audit | cso/*.tmpl | layers/thinking/security-audit.md |

### From GSD (Layer 1: Workflow)
GSD is NOT extracted — it runs as-is via ~/.claude/get-shit-done/.
Cortex enhances GSD tasks, it does not replace or duplicate them.
The upstream/gsd copy is for reference and diff tracking only.
