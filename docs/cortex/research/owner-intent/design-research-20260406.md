# Owner Intent — Design Research

**Slug:** owner-intent
**Phase:** concept
**Date:** 2026-04-06
**Status:** complete

---

## Problem Statement

Cortex tracks execution state (`.cortex/state.json`) and produces intelligence artifacts (`docs/cortex/`), but has no first-class artifact for **stable owner intent**. Every slug starts from scratch — there's no persistent "why", no tradeoff preferences, no kill criteria, no success metrics that survive across slugs. `cortex-drive` makes autonomous decisions with no model of what the owner actually wants.

This research designs two artifacts — `owner-intent.md` and `preferences.json` — that give Cortex a durable alignment layer.

---

## 1. owner-intent.md Schema

### 1.1 Format Decision: YAML Frontmatter + Markdown Sections

Same pattern as clarify briefs. Rationale:
- Frontmatter fields are machine-parseable (cortex-drive reads them)
- Markdown sections are human-readable and editable
- Consistent with every other Cortex artifact
- Pure YAML loses the "readable document" quality; pure markdown loses machine parseability

### 1.2 Sections

| Section | Required? | Purpose |
|---------|-----------|---------|
| **Frontmatter** | Required | Machine-readable metadata: version, scope, last_updated, author |
| **Mission** | Required | One sentence. The enduring "why" that doesn't change between slugs. |
| **Objectives** | Required | 3-7 concrete outcomes the project exists to achieve. Each is testable. |
| **Success Metrics** | Required | How you know the objectives are being met. Quantitative where possible. |
| **Non-Negotiables** | Required | Hard constraints that no slug may violate. These are kill criteria for any proposal. |
| **Tradeoff Preferences** | Required | Explicit ranked preferences for when objectives conflict (speed vs correctness, etc). |
| **Kill Criteria** | Optional | Conditions under which a slug or the entire project should be abandoned. |
| **Current Initiatives** | Optional | Active high-level efforts that map to one or more slugs. Updated as work progresses. |
| **Anti-Goals** | Optional | Things this project explicitly will never do. Stronger than non-goals on a clarify brief. |
| **Review Cadence** | Optional | How often the owner expects to re-examine this document. Default: every 5 slugs or 30 days. |

### 1.3 Scope Model

Two levels:
- **Global intent** (`~/.cortex/owner-intent.md`) — cross-project preferences and values. Applies everywhere. Thin: mission, non-negotiables, tradeoff defaults.
- **Project intent** (`docs/cortex/intent/owner-intent.md`) — project-specific objectives, metrics, kill criteria. Overrides global where they conflict.

Resolution order (same as autonomy config): invocation context > project intent > global intent.

### 1.4 Relationship to Other Artifacts

| Artifact | Relationship |
|----------|-------------|
| Clarify brief | Intent provides the "why" that frames clarify's "what". Clarify inherits non-negotiables as constraints. |
| Spec | Spec's acceptance criteria must be traceable to at least one objective in intent. |
| Contract | Contract validators can reference intent success metrics. |
| cortex-drive decision table | Drive reads intent before every dispatch. Non-negotiables become hard stops. Tradeoff preferences guide judgment calls (row 3, row 11). |
| cortex-sync (future) | Compares current execution against intent. Produces drift report. |

### 1.5 Complete Example: owner-intent.md for Cortex

```markdown
---
version: 1
scope: project
last_updated: 2026-04-06
author: calen
review_cadence: 30d
---

# Owner Intent — Cortex

## Mission

Cortex converts fuzzy ideas into correct, validated software by wrapping
Claude Code sessions in a lifecycle intelligence layer — so that every piece
of work is clarified, researched, specified, executed, and verified before
it ships.

## Objectives

1. **Lifecycle completeness** — Every non-trivial change passes through the
   full spine (clarify -> research -> spec -> execute -> validate -> done).
   No shortcuts that skip validation.

2. **Autonomous capability** — cortex-drive can take a stash idea through
   to a closed slug without human intervention for standard-complexity work.
   Human gates fire only for mandatory stops (taste, reclarify, budget).

3. **Zero context loss** — After /clear, /compact, or session crash,
   /cortex-status reconstructs full working state from disk artifacts.
   No intelligence is stored only in chat.

4. **Honest quality signal** — Validators, evals, and reviews produce
   accurate pass/fail signals. A passing eval means the work is actually
   correct, not that the eval is weak.

5. **Low ceremony** — The system adds intelligence, not bureaucracy.
   Trivial work gets thin pipelines. The overhead of Cortex on a
   standard slug should be under 15 minutes of wall time for the
   intelligence phases (clarify + research + spec).

6. **Composability** — Cortex layers cleanly over GSD without collision.
   Each system owns its namespace. No dual-write conflicts.

## Success Metrics

- Slug completion rate: >80% of started slugs reach `done` without
  manual rescue (measured over rolling 10 slugs)
- Context recovery: /cortex-status after /clear restores working state
  in <30 seconds with zero information loss
- False positive rate on validators: <10% (validators that pass when
  the work is actually broken)
- Autonomous drive success: >60% of standard-complexity slugs complete
  via cortex-drive without human escalation
- Time-to-spec for standard complexity: <15 minutes wall time

## Non-Negotiables

- **No code without contract.** Production code must not be written
  before a contract is approved. The phase guard enforces this.
- **Validators must run.** No slug closes without validators passing.
  LOOP-01 is non-negotiable.
- **Disk is truth.** All state lives in repo artifacts. Chat is
  ephemeral. Any feature that stores state only in memory or chat
  context is a bug.
- **GSD owns execution.** Cortex does not write to .planning/ except
  via /cortex-bridge. No exceptions.
- **No sycophantic evals.** Eval rubrics must test for actual
  correctness, not surface compliance. A passing rubric score on
  broken code is worse than a failing score on working code.

## Tradeoff Preferences

When objectives conflict, resolve in this order:

1. **Correctness > Speed** — A slower slug that ships correct code
   beats a fast slug that ships bugs. Always.
2. **Autonomy > Ceremony** — Prefer automated decisions over human
   gates, except for mandatory stops. Default to gates-only, not
   supervised.
3. **Durability > Features** — Continuity and state management fixes
   take priority over new commands or capabilities.
4. **Simplicity > Generality** — Solve the concrete case well before
   abstracting. YAGNI applies to framework features.
5. **Evidence > Opinion** — When there's a disagreement about approach,
   the side with data (benchmarks, eval results, user feedback) wins.

## Kill Criteria

- If Cortex adds >30 minutes overhead to a standard slug with no
  measurable quality improvement, the system is net-negative. Strip
  it back to essentials.
- If cortex-drive autonomous mode produces >3 consecutive slugs that
  require human rescue, the autonomous capability is not ready.
  Disable it and investigate.
- If validators consistently produce false positives (>25% rate over
  10 slugs), the eval system is unreliable. Freeze new features and
  fix evals.

## Current Initiatives

- **Owner intent system** (this slug) — Give Cortex a durable alignment
  layer so autonomous decisions are grounded in owner values.
- **Execution supervisor** — Instrument the execute phase for
  observability and guardrails.
- **Semantic retrieval** — Enable fact-based memory retrieval for
  research and decision-making.

## Anti-Goals

- Cortex will never be a general-purpose project management tool.
  It serves one user (the owner) working with one AI (Claude).
- Cortex will never require a database, external service, or network
  dependency for core operation. It is a file-based system.
- Cortex will never generate marketing copy, slide decks, or
  non-engineering artifacts. It is an engineering intelligence layer.
```

---

## 2. preferences.json Schema

### 2.1 Field Design

Each preference is a structured record, not a flat key-value pair. This gives cortex-drive enough metadata to make calibrated decisions.

```typescript
interface Preference {
  key: string;           // dot-notation path: "tradeoff.speed_vs_correctness"
  value: string | number | boolean | string[];
  scope: "global" | "project" | "slug";
  strength: "suggestion" | "preference" | "requirement";
  confidence: number;    // 0.0 - 1.0, owner's confidence in this preference
  source: "explicit" | "inferred" | "default";
  last_confirmed: string; // ISO 8601 date
  expires_after?: string; // ISO 8601 duration (e.g., "P90D") or null for never
  context?: string;       // Why this preference exists — one sentence
}
```

**Field explanations:**

| Field | Purpose |
|-------|---------|
| `key` | Namespaced identifier. Categories: `tradeoff.*`, `quality.*`, `workflow.*`, `tool.*`, `style.*` |
| `value` | The preference value. Type depends on the key. |
| `scope` | Where it applies. `global` = all projects, `project` = this repo, `slug` = current slug only. |
| `strength` | How binding it is. `suggestion` = try this first. `preference` = do this unless there's a strong reason not to. `requirement` = hard constraint, same as non-negotiable. |
| `confidence` | Owner's certainty. 1.0 = "I've tested this, it's right." 0.5 = "I think this is right but haven't validated." cortex-drive may override low-confidence preferences with evidence. |
| `source` | How it was established. `explicit` = owner typed it. `inferred` = extracted from behavior patterns. `default` = system default, never confirmed. |
| `last_confirmed` | When the owner last explicitly agreed this is still valid. Drives staleness calculation. |
| `expires_after` | Optional TTL. After expiry, preference is treated as `source: "default"` until reconfirmed. |
| `context` | Freeform rationale. Helps cortex-drive understand the "why" behind the preference. |

### 2.2 Preference Categories

**Tradeoff preferences** (`tradeoff.*`)
- `tradeoff.speed_vs_correctness` — which side to favor
- `tradeoff.autonomy_vs_control` — how much human oversight
- `tradeoff.generality_vs_specificity` — abstract vs concrete solutions
- `tradeoff.features_vs_stability` — new capability vs reliability

**Quality bars** (`quality.*`)
- `quality.test_coverage_minimum` — numeric threshold
- `quality.max_validator_false_positive_rate` — threshold before evals are unreliable
- `quality.review_depth` — "surface" | "standard" | "deep"
- `quality.acceptable_tech_debt` — "none" | "low" | "moderate"

**Workflow preferences** (`workflow.*`)
- `workflow.default_autonomy` — "supervised" | "gates-only" | "full-auto"
- `workflow.preferred_complexity_default` — "trivial" | "standard" | "complex"
- `workflow.max_repair_iterations` — integer
- `workflow.research_depth` — "shallow" | "standard" | "deep"

**Tool preferences** (`tool.*`)
- `tool.preferred_test_framework` — e.g., "vitest", "pytest"
- `tool.preferred_language` — e.g., "typescript", "python"
- `tool.git_commit_style` — e.g., "conventional", "imperative"

**Style preferences** (`style.*`)
- `style.code_comments` — "minimal" | "moderate" | "verbose"
- `style.abstraction_level` — "concrete" | "moderate" | "abstract"
- `style.naming_convention` — "camelCase" | "snake_case" etc.

### 2.3 Staleness Model

Preferences age. The staleness model:

```
age = now - last_confirmed
ttl = expires_after ?? default_ttl_for_strength

if strength == "requirement":
    default_ttl = null  (never expires — must be explicitly removed)
elif strength == "preference":
    default_ttl = "P180D"  (6 months)
elif strength == "suggestion":
    default_ttl = "P90D"   (3 months)

if age > ttl:
    effective_strength = demote_one_level(strength)
    # preference -> suggestion, suggestion -> ignored
    # requirement never demotes automatically
```

Staleness doesn't delete preferences — it **demotes** them. A stale preference becomes a weaker signal, not no signal. Requirements never auto-demote (they must be explicitly changed or removed).

cortex-drive checks staleness at initialization (Phase 1). If >3 preferences are stale, it logs a warning to `decisions.md`: "N preferences stale — consider running /cortex-intent review."

### 2.4 Complete Example: preferences.json for Cortex

```json
{
  "$schema": "cortex/preferences/v1",
  "project": "cortex",
  "last_updated": "2026-04-06T18:00:00Z",
  "preferences": [
    {
      "key": "tradeoff.speed_vs_correctness",
      "value": "correctness",
      "scope": "project",
      "strength": "requirement",
      "confidence": 1.0,
      "source": "explicit",
      "last_confirmed": "2026-04-06",
      "context": "Cortex is infrastructure. Bugs in the intelligence layer compound into every slug it drives."
    },
    {
      "key": "tradeoff.autonomy_vs_control",
      "value": "autonomy",
      "scope": "project",
      "strength": "preference",
      "confidence": 0.8,
      "source": "explicit",
      "last_confirmed": "2026-04-06",
      "context": "Goal is for cortex-drive to handle standard slugs end-to-end. Mandatory gates remain."
    },
    {
      "key": "tradeoff.generality_vs_specificity",
      "value": "specificity",
      "scope": "project",
      "strength": "preference",
      "confidence": 0.9,
      "source": "explicit",
      "last_confirmed": "2026-04-06",
      "context": "Solve concrete cases first. YAGNI. Generalize only when 3+ concrete cases share a pattern."
    },
    {
      "key": "tradeoff.features_vs_stability",
      "value": "stability",
      "scope": "project",
      "strength": "preference",
      "confidence": 0.7,
      "source": "explicit",
      "last_confirmed": "2026-04-06",
      "expires_after": "P180D",
      "context": "Current priority is hardening existing commands. Will shift once core is stable."
    },
    {
      "key": "quality.test_coverage_minimum",
      "value": 0,
      "scope": "project",
      "strength": "suggestion",
      "confidence": 0.5,
      "source": "inferred",
      "last_confirmed": "2026-04-06",
      "expires_after": "P90D",
      "context": "Cortex is mostly markdown skills and shell hooks — traditional test coverage doesn't map well. Validators and evals serve as the test layer."
    },
    {
      "key": "quality.review_depth",
      "value": "standard",
      "scope": "project",
      "strength": "preference",
      "confidence": 0.8,
      "source": "explicit",
      "last_confirmed": "2026-04-06"
    },
    {
      "key": "quality.max_validator_false_positive_rate",
      "value": 0.10,
      "scope": "project",
      "strength": "requirement",
      "confidence": 0.9,
      "source": "explicit",
      "last_confirmed": "2026-04-06",
      "context": "If validators lie, the entire system is unreliable. 10% is the ceiling."
    },
    {
      "key": "workflow.default_autonomy",
      "value": "gates-only",
      "scope": "project",
      "strength": "preference",
      "confidence": 0.8,
      "source": "explicit",
      "last_confirmed": "2026-04-06",
      "context": "Gates-only is the current sweet spot. Supervised is too slow, full-auto needs more trust."
    },
    {
      "key": "workflow.max_repair_iterations",
      "value": 3,
      "scope": "project",
      "strength": "preference",
      "confidence": 0.7,
      "source": "explicit",
      "last_confirmed": "2026-04-06"
    },
    {
      "key": "workflow.research_depth",
      "value": "standard",
      "scope": "project",
      "strength": "suggestion",
      "confidence": 0.6,
      "source": "inferred",
      "last_confirmed": "2026-04-06",
      "expires_after": "P90D",
      "context": "Standard depth is usually enough. Deep research warranted for novel domains."
    },
    {
      "key": "tool.preferred_language",
      "value": ["typescript", "python", "bash"],
      "scope": "global",
      "strength": "preference",
      "confidence": 1.0,
      "source": "explicit",
      "last_confirmed": "2026-04-06"
    },
    {
      "key": "tool.git_commit_style",
      "value": "conventional",
      "scope": "global",
      "strength": "requirement",
      "confidence": 1.0,
      "source": "explicit",
      "last_confirmed": "2026-04-06",
      "context": "Conventional commits (feat:, fix:, chore:, docs:, etc). Enforced by CLAUDE.md."
    },
    {
      "key": "style.code_comments",
      "value": "minimal",
      "scope": "global",
      "strength": "preference",
      "confidence": 0.9,
      "source": "explicit",
      "last_confirmed": "2026-04-06",
      "context": "Clean readable code, not comment-heavy code. Comments for why, not what."
    },
    {
      "key": "style.abstraction_level",
      "value": "concrete",
      "scope": "project",
      "strength": "preference",
      "confidence": 0.9,
      "source": "explicit",
      "last_confirmed": "2026-04-06",
      "context": "No unnecessary abstractions. Solve the concrete case. Matches CLAUDE.md coding style."
    }
  ]
}
```

---

## 3. File Location Decision

### Arguments For Each Location

**`.cortex/intent/` (machine state root)**
- Pro: Consistent with `.cortex/state.json` — runtime reads come from `.cortex/`
- Pro: Already gitignored patterns exist for machine state
- Con: Intent is a durable human-authored artifact, not transient machine state
- Con: `.cortex/` is for things that change every session; intent changes every few months

**`docs/cortex/intent/` (artifact root)**
- Pro: Intent is a durable artifact like clarify briefs, specs, and contracts
- Pro: Version-controlled and visible in PRs
- Pro: Follows the existing ownership boundary: `docs/cortex/` = human-readable intelligence artifacts
- Pro: Other developers (if any) can read and understand project intent
- Con: Slightly longer path for machine reads

**Project root (like CLAUDE.md)**
- Pro: Maximum visibility
- Pro: CLAUDE.md already contains some intent-like content (coding style, workflow)
- Con: Root is already cluttered; these are Cortex artifacts, not repo-level config
- Con: Breaks the Cortex artifact root convention

### Recommendation: `docs/cortex/intent/`

**Rationale:** owner-intent.md and preferences.json are durable intelligence artifacts, not transient machine state. They belong in the same root as clarify briefs, specs, and contracts. They're authored by humans, version-controlled, and should be visible in diffs.

File layout:
```
docs/cortex/intent/
  owner-intent.md     # The "why" document
  preferences.json    # Structured preference records
```

Global-scope versions (optional, for cross-project defaults):
```
~/.cortex/intent/
  owner-intent.md     # Global mission + non-negotiables
  preferences.json    # Global preference defaults
```

cortex-drive resolution: read project-level first, fall back to global, merge. Project values override global values for the same key.

---

## 4. Bootstrap Mechanism

### 4.1 Command: `/cortex-intent`

A dedicated command is warranted. Manual authoring + template is not sufficient because:
- The document needs to be internally consistent (tradeoff preferences should align with non-negotiables)
- preferences.json has structural requirements that are easy to get wrong by hand
- The command can seed from existing CLAUDE.md content and project history
- Updates need staleness checks and conflict detection

**Subcommands:**

| Subcommand | Action |
|------------|--------|
| `/cortex-intent init` | Interactive bootstrap. Reads CLAUDE.md, recent slugs, and project structure. Asks 5-8 focused questions. Writes both files. |
| `/cortex-intent review` | Re-reads both files. Flags stale preferences, checks for contradictions between intent and recent execution patterns, suggests updates. |
| `/cortex-intent update` | Targeted update to a specific section or preference. Bumps `last_updated` / `last_confirmed`. |
| `/cortex-intent diff` | Shows what changed since last confirmed version. Useful before a review cadence checkpoint. |

### 4.2 Bootstrap Flow (`/cortex-intent init`)

1. Read existing signals: `CLAUDE.md`, `.cortex/state.json`, recent archived slugs, `docs/cortex/handoffs/decisions.md`
2. Extract implicit preferences (coding style rules, workflow patterns, tradeoff signals)
3. Ask the owner 5-8 questions:
   - "What is this project for? (one sentence)"
   - "What are the 3-5 most important outcomes?"
   - "What must never be violated?" (seed from CLAUDE.md constraints)
   - "When speed and correctness conflict, which wins?"
   - "What would make you abandon this project or a feature?"
   - "How much autonomous decision-making do you want?"
4. Generate `owner-intent.md` and `preferences.json`
5. Present for review. Owner edits or approves.
6. Write to `docs/cortex/intent/`

### 4.3 How Intent Gets Updated Over Time

Three triggers:

1. **Review cadence** — Every N slugs or N days (configurable in frontmatter). cortex-drive checks at initialization and logs a reminder if overdue. Does not block execution.

2. **Drift detection** (future: cortex-sync) — When execution patterns consistently diverge from stated preferences, flag the drift. Example: preferences.json says `correctness > speed` but the last 5 slugs skipped validation. Either the execution is wrong or the preference is outdated.

3. **Explicit update** — Owner runs `/cortex-intent update` when priorities shift. Common after completing a major initiative or changing project direction.

Staleness is passive, not blocking. A stale preference still influences decisions — it just carries less weight. Only requirements are immune to staleness decay.

---

## 5. cortex-drive Integration

How cortex-drive consumes these artifacts:

### Phase 1 (Initialize) — Add to step 1:
```
1. Read .cortex/state.json
2. Read docs/cortex/intent/owner-intent.md (parse frontmatter + sections)
3. Read docs/cortex/intent/preferences.json (parse, apply staleness)
4. Check review cadence — if overdue, log warning
5. Build effective_preferences (merge global + project, apply staleness demotions)
```

### Decision Table — Intent-Aware Modifications:

| Row | Current Behavior | With Intent |
|-----|-----------------|-------------|
| 1 (backlog ranking) | Rank by leverage/urgency/deps | Also weight by alignment to `objectives` in intent. Slugs that serve no objective get deprioritized. |
| 3 (research depth) | Judgment call | Check `workflow.research_depth` preference. If `deep` and current research is shallow, always escalate. |
| 6 (auto-approve) | Auto-approve if autonomy allows | Check `tradeoff.autonomy_vs_control`. If value is `control`, never auto-approve even if config allows. |
| 11 (repair) | Create repair contract | Check `workflow.max_repair_iterations` preference. Check kill criteria — if budget exceeded, stop. |
| All rows | No alignment check | Before dispatch, verify the action doesn't violate any non-negotiable. If it would, stop with reason. |

### New Safety Check (Phase 5):

| Check | Condition | Action |
|-------|-----------|--------|
| Intent violation | Proposed action would violate a non-negotiable | Stop: "Action violates non-negotiable: {which one}" |
| Kill criteria met | Current slug or project matches a kill criterion | Stop: "Kill criterion triggered: {which one}" |
| Review overdue | Review cadence exceeded by 2x | Warning in decisions.md (non-blocking) |

---

## 6. Open Questions for Spec Phase

1. **Should preferences.json support inheritance chains?** (global -> project -> slug). Current design supports it but the merge logic needs specifying. Recommendation: keep it simple — two levels (global + project), slug-level preferences are rare and can be inline in the contract.

2. **Should inferred preferences be auto-written?** cortex-drive could observe patterns and write `source: "inferred"` preferences. Risk: the system starts "learning" things the owner didn't intend. Recommendation: inferred preferences are written with `strength: "suggestion"` and `expires_after: "P30D"` — they surface quickly for confirmation or rejection.

3. **How does intent interact with the necessity gate?** The necessity gate asks "should this exist?" — intent could provide the criteria. If a proposed slug serves no objective, the necessity gate should flag it. Recommendation: wire intent objectives into necessity gate evaluation.

4. **Version history for intent?** Git provides version history, but should there be an explicit changelog section? Recommendation: no — git diff is sufficient. The `last_updated` field in frontmatter is enough.
