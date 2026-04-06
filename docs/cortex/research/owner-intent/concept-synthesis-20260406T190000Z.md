# Research Dossier: owner-intent — synthesis

**Slug:** owner-intent
**Phase:** concept (synthesis)
**Timestamp:** 20260406T190000Z
**Depth:** standard (4 parallel research agents)

---

## Executive Summary

Owner intent is a genuine gap — not a nice-to-have. The necessity gate has a `{context}` slot with nothing filling it. cortex-drive ranks work by hardcoded heuristics (leverage/urgency/deps) with no awareness of what the owner actually wants. Tradeoff preferences (speed vs correctness, autonomy vs control) have no home anywhere in the system. CLAUDE.md captures behavioral HOW constraints; nothing captures strategic WHY objectives.

The implementation is: two files (`owner-intent.md` + `preferences.json`) in `docs/cortex/intent/`, a `/cortex-intent` bootstrap command, and wiring into 4 must-have integration points (drive row 1, necessity gate, clarify constraint injection, and CLAUDE.md/memory boundary).

---

## Finding 1: The Gap Is Real but Narrow

### What already captures intent (scattered, non-machine-parseable)

| Source | What it captures | Machine-readable? |
|--------|-----------------|-------------------|
| `~/.claude/CLAUDE.md` | Process rules (TDD, atomic commits, anti-sycophancy) | No — Claude reads, skills can't parse |
| `~/.claude/rules/*.md` | Communication + workflow preferences | No |
| Memory files | Behavioral feedback (research methodology) | No |
| `autonomous-builder-ideas.md` | Priority stack (what to build, in order) | Partially — cortex-drive reads it |
| cortex-drive SKILL.md | Ranking heuristics (leverage/urgency/deps) | Hardcoded, not configurable |
| Necessity gate | 5 diagnostic questions | Has `{context}` slot, nothing fills it |

### What's genuinely missing (no home anywhere)

| Missing | Impact |
|---------|--------|
| Strategic objectives (what is Cortex trying to become?) | Drive ranks by heuristics, not alignment |
| Success metrics (how do we know it's working?) | No way to evaluate if a slug moved the needle |
| Non-negotiables as enforceable constraints | Some in CLAUDE.md but not propagated to clarify briefs |
| Tradeoff preferences (speed vs correctness) | Nowhere. Not in CLAUDE.md, memory, or ideas.md |
| Kill criteria (when to stop) | Necessity gate has REJECT but no owner-defined criteria |
| Temporal focus (current priorities) | No mechanism for "this month, focus on X" |

### Boundary: intent vs CLAUDE.md vs memory

| System | What it owns |
|--------|-------------|
| **CLAUDE.md** | HOW constraints — behavioral rules, coding style, communication |
| **Memory** | Learned corrections — behavioral feedback from past sessions |
| **owner-intent.md** | WHY objectives — mission, outcomes, metrics, non-negotiables, kill criteria |
| **preferences.json** | WHAT tradeoffs — structured, machine-readable preference records with strength/confidence/staleness |

No redundancy if the boundary is respected. Risk: non-negotiables in intent overlapping with rules in CLAUDE.md. Mitigation: intent captures strategic constraints (no runtime deps), CLAUDE.md captures behavioral constraints (always TDD).

---

## Finding 2: Schema Design

### owner-intent.md — YAML frontmatter + markdown sections

| Section | Required? | Purpose |
|---------|-----------|---------|
| Mission | Required | One sentence enduring "why" |
| Objectives | Required | 3-7 testable outcomes |
| Success Metrics | Required | Quantitative where possible |
| Non-Negotiables | Required | Hard constraints no slug may violate |
| Tradeoff Preferences | Required | Ranked resolution order when objectives conflict |
| Kill Criteria | Optional | When to abandon |
| Current Initiatives | Optional | Active efforts mapping to slugs |
| Anti-Goals | Optional | Things this project will never do |
| Review Cadence | Optional | How often to re-examine (default: 30 days) |

Complete working example for Cortex written in the design dossier — 6 objectives, 5 success metrics, 5 non-negotiables, 5 ranked tradeoff preferences, 3 kill criteria, 3 anti-goals.

### preferences.json — Structured records with staleness

Each preference has 9 fields: key (dot-namespaced), value, scope, strength (suggestion/preference/requirement), confidence (0-1), source (explicit/inferred/default), last_confirmed, expires_after, context.

Staleness model: preferences demote by one strength level when TTL expires. Requirements never auto-demote. Suggestions expire at 90 days, preferences at 180 days.

14-entry example written for Cortex covering tradeoffs, quality bars, workflow, tools, and style.

### File location: `docs/cortex/intent/`

Intent is a durable intelligence artifact, not transient machine state. Belongs with clarify briefs and specs. Version-controlled, visible in PRs.

Optional global: `~/.cortex/intent/` for cross-project defaults. Project overrides global.

---

## Finding 3: Integration Points (Priority-Ranked)

### Must-Have (4 integration points)

| # | Integration | File | What changes |
|---|-------------|------|-------------|
| 1 | **Drive Row 1 — backlog ranking** | `cortex-drive/SKILL.md` | Add alignment scoring: filter by non-negotiable violations, then weight by objective alignment + leverage + urgency + deps |
| 2 | **Necessity gate — strategic lens** | `cortex-spec/SKILL.md` | Add 6th diagnostic question: "Does this serve a stated owner objective?" Wire `owner-intent.md` objectives into necessity gate `{context}` slot |
| 3 | **Clarify — constraint auto-injection** | `cortex-clarify/SKILL.md` | Auto-inject owner non-negotiables into every clarify brief's Constraints section |
| 4 | **Drive safety checks** | `cortex-drive/SKILL.md` | Before every dispatch, verify action doesn't violate non-negotiable. Check kill criteria. Log review cadence warnings. |

### Nice-to-Have (5 integration points)

| # | Integration | What changes |
|---|-------------|-------------|
| 5 | Spec acceptance criteria | Owner success metrics seed acceptance criteria |
| 6 | Spec coherence check | Cross-check spec against owner non-negotiables |
| 7 | Clarify goal framing | Intent-influenced problem framing |
| 8 | Drive rows 3,6,11 | Tradeoff preferences for speed/depth/budget |
| 9 | Drive preference-aware dispatch | Read workflow.research_depth, max_repair_iterations |

---

## Finding 4: Bootstrap Mechanism

### `/cortex-intent` command with 4 subcommands

| Subcommand | Action |
|------------|--------|
| `init` | Interactive bootstrap. Reads CLAUDE.md + recent slugs + project history. Asks 5-8 questions. Writes both files. |
| `review` | Flag stale preferences, check contradictions, suggest updates. |
| `update` | Targeted edit to a section/preference. Bumps timestamps. |
| `diff` | Show changes since last confirmed version. |

### Update triggers

1. **Review cadence** — every N slugs or N days (configurable). Non-blocking warning.
2. **Drift detection** (future cortex-sync) — when execution diverges from preferences.
3. **Explicit update** — owner runs `/cortex-intent update` when priorities shift.

---

## Revised Task Map

### Must-Do

| # | Task | Files | Effort |
|---|------|-------|--------|
| 1 | Create owner-intent.md template | `templates/cortex/owner-intent.md` | Small |
| 2 | Create preferences.json schema | `schemas/preferences.schema.json` | Small |
| 3 | Write /cortex-intent SKILL.md (init, review, update, diff) | `skills/cortex-intent/SKILL.md` | Medium |
| 4 | Wire drive Phase 1 to read intent + preferences | `skills/cortex-drive/SKILL.md` | Small |
| 5 | Wire drive Row 1 with alignment scoring | `skills/cortex-drive/SKILL.md` | Small |
| 6 | Wire necessity gate with intent context | `skills/cortex-spec/SKILL.md` | Small |
| 7 | Wire clarify constraint auto-injection | `skills/cortex-clarify/SKILL.md` | Small |
| 8 | Add drive safety checks (non-negotiable violations, kill criteria) | `skills/cortex-drive/SKILL.md` | Small |
| 9 | Bootstrap: write Cortex's own owner-intent.md | `docs/cortex/intent/owner-intent.md` | Small |
| 10 | Bootstrap: write Cortex's own preferences.json | `docs/cortex/intent/preferences.json` | Small |

### Should-Do

| # | Task | Effort |
|---|------|--------|
| 11 | Register /cortex-intent in runtime-manifest.json | Tiny |
| 12 | Add intent to CORTEX.md documentation | Small |
| 13 | Add intent to COMMANDS.md | Small |

### Defer

| # | Task | Reason |
|---|------|--------|
| 14 | Global ~/.cortex/intent/ support | Single-project scope is sufficient for now |
| 15 | Inferred preference auto-writing | Risk of learning unintended patterns |
| 16 | cortex-sync drift detection | Separate slug (D4) |

---

## Open Questions Resolved

> "Where do these files live?"
**Answer:** `docs/cortex/intent/` — durable intelligence artifacts, version-controlled.

> "Structured schema or freeform for owner-intent.md?"
**Answer:** YAML frontmatter + markdown sections (same pattern as clarify briefs).

> "How does cortex-drive use preferences for ranking?"
**Answer:** Filter by non-negotiable violations → weight by objective alignment + leverage + urgency + dependencies.

> "Should preferences have expiry dates?"
**Answer:** Yes. Staleness model demotes strength by one level. Requirements never auto-demote.

> "Bootstrap: command or manual authoring?"
**Answer:** `/cortex-intent init` command — reads existing CLAUDE.md, asks 5-8 questions, generates both files.

> "Should cortex-clarify auto-inject owner non-negotiables?"
**Answer:** Yes. Every clarify brief gets non-negotiables as standing constraints.

> "Overlap with CLAUDE.md and memory?"
**Answer:** Clear boundary. CLAUDE.md = HOW (behavioral). Memory = learned corrections. Intent = WHY (strategic). Preferences = WHAT tradeoffs (structured).

---

## Sources

### Internal
- `skills/cortex-drive/SKILL.md` — Row 1 ranking, decision table, safety checks
- `skills/cortex-spec/SKILL.md` — Necessity gate (lines 108-164), `{context}` slot
- `skills/cortex-clarify/SKILL.md` — Constraint/non-goal population (lines 90-103)
- `docs/cortex/archive/necessity-gate/` — Necessity gate implementation and research
- `~/.claude/CLAUDE.md`, `~/.claude/rules/*.md` — Existing behavioral preferences
- Memory files — Existing feedback preferences
- `docs/cortex/research/autonomous-builder-ideas.md` — Section D (items D1-D5)

### Design
- `docs/cortex/research/owner-intent/design-research-20260406.md` — Complete schemas, examples, bootstrap design
