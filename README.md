# Cortex

An AI-native skill suite for [Claude Code](https://claude.ai/code) that assembles three upstream frameworks — **GSD**, **GStack**, and **Superpowers** — into five ready-to-use slash commands.

---

## Architecture

Cortex is a three-layer stack. Each layer has a distinct job.

```
┌─────────────────────────────────────────────────────────┐
│                    CORTEX  SKILLS                        │
│   /cortex-audit  /cortex-research  /cortex-investigate   │
│   /cortex-review  /cortex-status                         │
│                                                          │
│   The assembled, ready-to-invoke interface               │
├───────────────────────────┬─────────────────────────────┤
│         GSTACK            │        SUPERPOWERS           │
│                           │                              │
│  Security audit protocol  │  TDD discipline              │
│  (/cso v2)                │  Anti-sycophancy rules       │
│  Iron Law investigation   │  Code review standards       │
│  Engineering review lens  │  Forcing questions           │
│  Security review lens     │                              │
│                           │                              │
│  Source of: audit,        │  Source of: investigate      │
│  investigate, review      │  (TDD), review (anti-syco)   │
├───────────────────────────┴─────────────────────────────┤
│                       GSD                                │
│                                                          │
│  Workflow layer: discuss → plan → execute → verify       │
│  Phase management, state tracking, atomic commits        │
│  /gsd:debug manages debug session state                  │
│  /cortex-status reports GSD project state                │
└─────────────────────────────────────────────────────────┘
```

### Layer 1 — GSD (Workflow)

[GSD](https://github.com/get-shit-done-cc) is the outermost loop. It enforces a structured workflow: discuss a phase, plan it, execute with atomic commits, verify against acceptance criteria, then advance. Cortex lives inside this loop — when `/gsd:debug` runs a debug session, it delegates the investigation protocol to `/cortex-investigate`. `/cortex-status` surfaces whether GSD is active and what phase you're in.

### Layer 2a — GStack (Thinking Protocols)

GStack is a library of expert-mode Claude Code protocols. Cortex draws three protocols from it:

| GStack protocol | Cortex skill | What it contributes |
|----------------|-------------|---------------------|
| `/cso` (v2) | `/cortex-audit` | 6-phase security audit, OWASP Top 10, STRIDE, confidence gates |
| `/investigate` | `/cortex-investigate` | Iron Law, scope lock, structured Debug Report |
| Code review | `/cortex-review` | Engineering lens, security lens, output format |

### Layer 2b — Superpowers (Discipline Protocols)

Superpowers is a set of behavioural constraints that keep Claude honest under pressure. Cortex draws two disciplines from it:

| Superpowers rule | Applied in |
|-----------------|-----------|
| TDD — failing test before fix | `/cortex-investigate` Phase 4 |
| Anti-sycophancy — no praise, findings only | `/cortex-review` (mandatory) |

### Layer 3 — Cortex (Integration)

Cortex is the glue. It packages the GStack + Superpowers protocols as Claude Code SKILL.md files, routes session state through GSD, and adds the research pipeline (`/cortex-research`) which is Cortex-native — not sourced from an upstream.

---

## Skills

### `/cortex-audit` — Security Audit
*Protocol source: GStack /cso v2*

Chief Security Officer mode. Six structured phases — no guessing, no vibes.

- **Phase 0** — Stack detection and architecture model
- **Phase 1** — Attack surface census (endpoints, webhooks, CI configs, IaC)
- **Phase 2** — Secrets archaeology through full git history
- **Phase 3** — Dependency supply chain audit (`npm audit`, `pip-audit`, etc.)
- **Phase 4** — OWASP Top 10 scan via grep patterns
- **Phase 5** — STRIDE threat model across every trust boundary
- **Phase 6** — Security Posture Report (CRITICAL / HIGH / MEDIUM / LOW)

Confidence gate: daily mode = 8/10+ confidence only. `--comprehensive` drops to 2/10.

```
/cortex-audit                 # full daily audit
/cortex-audit --comprehensive # monthly deep scan
/cortex-audit --diff          # changed files only vs base branch
/cortex-audit --quick         # infrastructure + secrets only
```

---

### `/cortex-research` — Deep Multi-Source Research
*Protocol source: Cortex-native*

Multi-source intelligence pipeline. Pulls from Tavily, Jina Reader, Firecrawl, Crawl4AI, Perplexity, Gemini, and gpt-researcher. Cross-references findings across sources and stores structured briefs locally.

| Tool | Purpose |
|------|---------|
| Tavily | Primary web search |
| Jina Reader | Clean URL extraction |
| Firecrawl | Full site scraping |
| Crawl4AI | Autonomous site crawling |
| Perplexity | Quick deep research |
| Gemini | Cross-reference + YouTube transcripts |
| gpt-researcher | Autonomous deep investigation |

Research output: `~/research/intake/` (raw) and `~/research/processed/briefs/` (synthesised).

```
/cortex-research <topic>           # full multi-source research
/cortex-research <topic> --quick   # Perplexity single-shot
/cortex-research <topic> --deep    # autonomous gpt-researcher run
/cortex-research <URL>             # extract and analyse a page
/cortex-research <youtube-url>     # transcript via Gemini
```

---

### `/cortex-investigate` — Systematic Debugging
*Protocol sources: GStack /investigate (Iron Law, scope lock, Debug Report) + Superpowers (TDD)*

**The Iron Law: no fix without confirmed root cause. If Phase 1 is not complete, no fix may be proposed.**

1. **Root Cause Investigation** — read errors fully, reproduce consistently, check recent git changes, trace data flow to source
2. **Scope Lock** — restrict edits to the narrowest directory; declare it before proceeding
3. **Pattern Analysis** — match against race conditions, nil propagation, state corruption, integration failures, config drift, stale cache
4. **Hypothesis Testing** — one hypothesis at a time; 3-Strike Rule: three failed hypotheses → stop and escalate
5. **Implementation** — failing test first (Superpowers TDD), single minimal fix, full test suite pass
6. **Debug Report** — symptom, root cause, fix, evidence, regression test, status

GSD integration: `/gsd:debug` manages session state; `/cortex-investigate` enforces the investigation protocol within that session.

```
/cortex-investigate   # also triggers on: "debug this", "why is this broken", "root cause"
```

---

### `/cortex-review` — Multi-Lens Code Review
*Protocol sources: GStack (engineering + security lenses) + Superpowers (anti-sycophancy)*

Three lenses applied to every review. Anti-sycophancy is mandatory — no praise, no filler, no performative agreement.

**Engineering lens** (GStack): correctness, edge cases, naming, test quality, architecture fit, YAGNI
**Security lens** (GStack): injection, XSS, auth bypass, hardcoded secrets, SSRF, path traversal
**YAGNI lens**: grep for actual usage before recommending anything; unused → suggest removal, not improvement

Output: BLOCK / WARN / NOTE / SECURITY with a final verdict of APPROVE, REQUEST CHANGES, or NEEDS DISCUSSION.

```
/cortex-review            # review staged or changed files
/cortex-review --security # security lens only
/cortex-review --pr N     # review a specific GitHub PR
```

---

### `/cortex-status` — System Health

Reports the state of the full stack: GSD workflow layer, GStack/Superpowers upstream versions, API key availability, Python tool installations.

```
/cortex-status
```

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 CORTEX STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Layer 1 (Workflow):   GSD active
Layer 2 (Discipline): 3/4 rules loaded
Layer 3 (Thinking):   4/4 rules loaded

Upstreams:
  Superpowers: a3f2d1c
  GStack:      v2.4.1
  GSD:         local copy

APIs:
  Tavily:      configured
  Gemini:      configured
  OpenAI:      configured
  Perplexity:  NOT SET
  Firecrawl:   NOT SET
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Installation

### Via `/install-skill` (Claude Code)

```
/install-skill https://github.com/calenwalshe/cortex
```

### Manual

```bash
git clone https://github.com/calenwalshe/cortex.git
cp -r cortex/skills/* ~/.claude/skills/
```

Each skill is a single `SKILL.md` file. Claude Code picks them up automatically on next launch.

---

## How It Works

Cortex skills are plain Markdown files. Claude Code reads them as behavioural instructions. When you type a slash command, Claude loads the corresponding `SKILL.md` and follows the protocol — calling tools, running bash, reading files — exactly as defined.

No daemon. No runtime. No external service beyond what each protocol itself requires. State (research briefs, debug reports, audit findings) is written to your filesystem by the protocols.

---

## API Keys (Research skill)

| Env Var | Service |
|---------|---------|
| `TAVILY_API_KEY` | Tavily search |
| `FIRECRAWL_API_KEY` | Firecrawl scraping |
| `PPLX_API_KEY` | Perplexity |
| `GEMINI_API_KEY` | Gemini cross-reference + YouTube |
| `OPENAI_API_KEY` | gpt-researcher backend |

The skill degrades gracefully — uses whatever is configured, skips the rest.

---

## Design Philosophy

- **Protocol over personality** — deterministic phases, not improvisation. The audit runs the same six phases every time.
- **No security theatre** — the audit scans git history, CI configs, and dependency trees, not just application code.
- **No sycophancy** — reviews and debug reports state findings plainly. No praise.
- **Evidence before fixes** — the Iron Law prevents fixes without confirmed root cause. Reviews grep before recommending.
- **Confidence gates** — findings are filtered by confidence threshold so noise doesn't drown signal.
- **Stack transparency** — `/cortex-status` shows exactly which upstream version each protocol comes from.
