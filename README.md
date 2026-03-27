# Cortex

An AI-native skill suite for [Claude Code](https://claude.ai/code) that upgrades Claude into a structured expert across five domains: security auditing, deep research, systematic debugging, code review, and system health monitoring.

Each skill is a standalone Claude Code slash command. Install them individually or as a full suite.

---

## Skills

### `/cortex-audit` — Security Audit

Chief Security Officer mode. Runs a structured security scan across your codebase.

- **Phase 0** — Stack detection and architecture modelling
- **Phase 1** — Attack surface census (endpoints, webhooks, infra configs)
- **Phase 2** — Secrets archaeology through git history
- **Phase 3** — Dependency supply chain audit (`npm audit`, `pip-audit`, etc.)
- **Phase 4** — OWASP Top 10 scan via grep patterns
- **Phase 5** — STRIDE threat model across trust boundaries
- **Phase 6** — Structured Security Posture Report (CRITICAL / HIGH / MEDIUM / LOW)

Operates with a confidence gate: daily mode reports only 8/10+ confidence findings to avoid alert fatigue; `--comprehensive` drops to 2/10 for a full sweep.

```
/cortex-audit                 # full daily audit
/cortex-audit --comprehensive # monthly deep scan, low confidence bar
/cortex-audit --diff          # only changed files vs base branch
/cortex-audit --quick         # infrastructure + secrets only
```

---

### `/cortex-research` — Deep Multi-Source Research

A systematic research pipeline that pulls from multiple search APIs, extracts content, cross-references with Gemini, and stores structured intelligence briefs locally.

**Sources used:**
| Tool | Purpose |
|------|---------|
| Tavily | Primary web search |
| Jina Reader | Clean URL extraction |
| Firecrawl | Full site scraping |
| Crawl4AI | Autonomous site crawling |
| Perplexity | Quick deep research |
| Gemini | Cross-reference & YouTube transcripts |
| gpt-researcher | Autonomous deep investigation |

Research briefs are saved to `~/research/` with consistent structure:
- `~/research/intake/` — raw source extracts
- `~/research/processed/briefs/` — synthesized intelligence briefs

```
/cortex-research <topic>              # full multi-source research
/cortex-research <topic> --quick      # Perplexity single-shot only
/cortex-research <topic> --deep       # autonomous gpt-researcher run
/cortex-research <URL>                # extract and analyse a specific page
/cortex-research <youtube-url>        # extract transcript via Gemini
```

---

### `/cortex-investigate` — Systematic Debugging

Structured debugging protocol combining TDD discipline (write failing test first) with the Iron Law: **no fixes without root cause investigation first**.

**The Iron Law:** If Phase 1 is not complete, no fix may be proposed.

**Phases:**
1. **Root Cause Investigation** — read errors carefully, reproduce consistently, check recent git changes, trace data flow to source
2. **Scope Lock** — restrict edits to the narrowest directory containing the affected files
3. **Pattern Analysis** — match against known bug patterns (race conditions, nil propagation, state corruption, integration failures, config drift)
4. **Hypothesis Testing** — one hypothesis at a time; 3-Strike Rule triggers escalation
5. **Implementation** — failing test first, single minimal fix, full test suite pass
6. **Debug Report** — structured output: symptom, root cause, fix, evidence, regression test

The 3-Strike Rule: after 3 failed hypotheses, stop and present options — continue with new hypothesis, escalate, or instrument for next occurrence.

```
/cortex-investigate           # triggered automatically on debug requests
```

---

### `/cortex-review` — Multi-Lens Code Review

Code review across three lenses: engineering correctness, security, and YAGNI. Follows strict anti-sycophancy rules — no praise, no filler, just findings.

**Engineering lens:** correctness, edge cases, naming, test quality, architecture fit
**Security lens:** injection, XSS, auth bypass, hardcoded secrets, SSRF, path traversal
**YAGNI lens:** grep for actual usage before recommending anything new; unused code gets removal recommendations, not improvement suggestions

Handles pushback honestly: verify and withdraw if wrong, restate with evidence if correct.

Output format uses BLOCK / WARN / NOTE / SECURITY severity levels with a final verdict of APPROVE, REQUEST CHANGES, or NEEDS DISCUSSION.

```
/cortex-review                # review staged or changed files
/cortex-review --security     # security lens only
/cortex-review --pr N         # review a specific GitHub PR
```

---

### `/cortex-status` — System Health

Prints a full status report of the Cortex installation: loaded layers, upstream versions (Superpowers, GStack, GSD), API key availability, Python tool installations, and GSD project state.

```
/cortex-status
```

Example output:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 CORTEX STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Layer 1 (Workflow):   GSD active
Layer 2 (Discipline): 3/4 rules loaded
Layer 3 (Thinking):   4/4 rules loaded

APIs:
  Tavily:      configured
  Gemini:      configured
  OpenAI:      configured
  Perplexity:  NOT SET
  Firecrawl:   NOT SET

Available skills:
  /cortex-status      — This report
  /cortex-investigate — Systematic debugging (Iron Law)
  /cortex-audit       — Security audit (OWASP + STRIDE)
  /cortex-review      — Multi-lens code review
  /cortex-research    — Deep multi-LLM research
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Installation

### Via `/install-skill` (Claude Code)

```
/install-skill https://github.com/calenwalshe/cortex
```

### Manual

Clone this repo and copy the skill directories into your Claude Code skills folder:

```bash
git clone https://github.com/calenwalshe/cortex.git
cp -r cortex/skills/* ~/.claude/skills/
```

Each skill directory contains a single `SKILL.md` file. Claude Code picks them up automatically on next launch.

---

## How It Works

Cortex skills are plain Markdown files that Claude Code reads as behavioural instructions. When you type a slash command (e.g. `/cortex-audit`), Claude Code loads the corresponding `SKILL.md` and follows the protocol defined inside it — calling tools, running bash commands, reading files, and producing structured output.

There is no runtime dependency, no daemon, and no network requirement beyond what each skill's own protocol calls for. The skills themselves are stateless; state (research briefs, debug reports) is written to disk by the protocols.

---

## API Keys (Research skill)

The research skill can use the following environment variables. Only configure the ones you have:

| Env Var | Service |
|---------|---------|
| `TAVILY_API_KEY` | Tavily search |
| `FIRECRAWL_API_KEY` | Firecrawl scraping |
| `PPLX_API_KEY` | Perplexity |
| `GEMINI_API_KEY` | Gemini cross-reference + YouTube |
| `OPENAI_API_KEY` | gpt-researcher backend |

The skill degrades gracefully — it uses whatever APIs are configured and skips the rest.

---

## Design Philosophy

- **Protocol over personality** — each skill is a structured protocol, not a vibe. The audit runs the same phases every time. The debugger enforces the Iron Law every time.
- **No security theater** — the audit looks at git history, CI configs, and dependency trees — not just your application code.
- **No sycophancy** — reviews and debug reports state findings plainly. No praise, no filler.
- **Confidence gates** — findings are filtered by confidence threshold so noise doesn't drown signal.
- **Evidence-first** — investigations require evidence before fixes. Reviews require grep before recommendations.
