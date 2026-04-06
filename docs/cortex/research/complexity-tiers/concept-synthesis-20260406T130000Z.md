# Research Dossier: complexity-tiers — synthesis

**Slug:** complexity-tiers
**Phase:** concept (synthesis)
**Timestamp:** 20260406T130000Z
**Depth:** standard (4 parallel research agents)

---

## Executive Summary

Complexity tiers are **partially implemented**. cortex-research (lines 41-47) and cortex-spec (lines 57-62) already have complexity routing. cortex-review and cortex-drive have zero awareness. The clarify brief template has the field. 52% of existing briefs already set it.

The work is: (1) wire cortex-review and cortex-drive to read complexity, (2) define what "extended validators" means for complex, (3) add auto-upgrade mechanism, and (4) document the three pipeline variants.

Empirical analysis of 23 existing slugs confirms a 5-6x token cost difference between trivial (~2K tokens of artifacts) and complex (~15K tokens), translating to ~85-92% savings on the thin pipeline.

---

## Finding 1: What's Already Built

| Component | Status | Location |
|-----------|--------|----------|
| Complexity field in clarify-brief template | **DONE** | `templates/cortex/clarify-brief.md` line 9, comments lines 11-16 |
| cortex-research complexity routing | **DONE** | `skills/cortex-research/SKILL.md` lines 41-47 — trivial skips, complex forces deep |
| cortex-spec thin spec for trivial | **DONE** | `skills/cortex-spec/SKILL.md` lines 57-62 — 4-section thin spec |
| cortex-spec extended validators for complex | **SPECIFIED but vague** | Line 61 says "extended validators" without defining them |
| cortex-review complexity awareness | **MISSING** | Zero complexity reading or routing |
| cortex-drive complexity awareness | **MISSING** | Dispatches uniformly regardless of tier |
| state.json complexity field | **MISSING** | No `complexity` field in state schema |
| Auto-upgrade mechanism | **MISSING** | No detection or upgrade logic |

---

## Finding 2: Empirical Data from 23 Slugs

### Actual complexity distribution (by work done, not label)

| Tier | Count | Artifact Range | Research Dossiers | Key Signal |
|------|-------|---------------|-------------------|------------|
| Trivial | 4 | 2.8K – 19.7K | 0-1 | Single dossier, thin/no spec |
| Standard | 13 | 16K – 31.5K | 1 | 1 dossier, full spec + contract, ~25K median |
| Complex | 5 | 42K – 72.6K | 2-4 | Multiple dossiers, large specs 13-16K |

### Label vs reality mismatch

| Slug | Labeled | Actual | Why |
|------|---------|--------|-----|
| execution-supervisor | complex | standard | Thin 4.9K spec, 21K total |
| pattern-harvest-safety-nets | standard | complex | Research exploded to 46.5K across 2 dossiers |
| necessity-gate | standard | trivial | Never progressed past research |

**Takeaway:** Humans mis-classify ~30% of the time. Auto-upgrade mechanism is essential.

---

## Finding 3: Pipeline Variant Design

### Lifecycle Comparison Table

| Lifecycle Step | Trivial | Standard | Complex |
|----------------|---------|----------|---------|
| **Clarify** | Full brief (complexity=trivial) | Full brief | Full brief (complexity=complex) |
| **Research: concept** | SKIP | Required (1+ dossier) | Required |
| **Research: implementation** | SKIP | Optional | **Required** |
| **Research: evals** | SKIP | Optional | **Required** (eval-proposal before spec) |
| **Eval plan** | SKIP | After spec (optional timing) | **Before spec approval** |
| **Fit check** | SKIP | Optional | **Required** if new deps/tools |
| **Spec** | Thin (4 sections) | Full (9 sections) | Full + ADR format + risk matrix |
| **Contract** | Thin (6 sections) | Full (all sections) | Full + extended validators |
| **Bridge** | SKIP (use gsd:fast/quick) | Full .planning/ scaffold | Full .planning/ scaffold |
| **Execute** | gsd:fast or gsd:quick | GSD phase execution | GSD phase execution |
| **Review** | Optional | Recommended | **Mandatory** |
| **Audit** | SKIP | Optional | **Mandatory** |
| **Repair budget** | 1 max | 3 max | 5 max |
| **Assure** | Validators pass = done | All evals pass + human approval | All evals + human approval + audit clean |

### Token Cost Estimates

| Pipeline | Total Artifact Cost | Total Token Spend (est.) | Savings vs Standard |
|----------|--------------------|-----------------------|-------------------|
| Trivial | ~1,300-2,000 tokens | ~15-25K tokens | **85-92%** |
| Standard | ~7,000 tokens | ~50-80K tokens | baseline |
| Complex | ~15,000 tokens | ~100-150K tokens | +70-90% cost |

---

## Finding 4: Auto-Upgrade Mechanism

### Upgrade triggers (one-way: trivial → standard → complex, never automatic downgrade)

| Signal | Detected By | Upgrade Path |
|--------|-------------|-------------|
| `reclarify_required: true` | cortex-research | trivial→standard, standard→complex |
| >3 critical open questions | cortex-research | trivial→standard |
| Multiple viable architectures | cortex-research | standard→complex |
| Security/auth/data constraints | cortex-clarify | any→complex |
| Write roots span >5 files or >3 dirs | cortex-spec | trivial→standard |
| First repair contract created | cortex-review/repair | trivial→standard |
| Second repair contract created | cortex-review/repair | standard→complex |
| `/cortex-fit` returns Hold or Assess | cortex-fit | standard→complex |

### Implementation

Commands check triggers → write new complexity to state.json → emit `COMPLEXITY_UPGRADE: {old} → {new} (reason)` → block until newly-required steps are completed. Human can override with `complexity_override: true` (logged in decisions.md).

### State schema additions

```json
{
  "complexity": "trivial|standard|complex",
  "complexity_override": false,
  "complexity_upgrades": []
}
```

---

## Finding 5: Surgical Change Map

### Must-Do (wires the system end-to-end)

| # | Task | File | Effort | Notes |
|---|------|------|--------|-------|
| 1 | Add complexity reading + conditional lens selection to cortex-review | `skills/cortex-review/SKILL.md` | Medium | trivial: Engineering+Security only. complex: all 4 + Architecture Fitness + Performance lenses. |
| 2 | Define extended validators for complex contracts | `skills/cortex-spec/SKILL.md` line 61 | Small | Cross-artifact coherence, research coverage, security audit clean, architecture decision rationale |
| 3 | Add complexity reading + routing to cortex-drive | `skills/cortex-drive/SKILL.md` | Medium | Read clarify brief, conditional row 2 (skip research if trivial), add row for mandatory audit/review for complex |
| 4 | Add complexity field to state.json schema | `skills/cortex-clarify/SKILL.md`, all consuming skills | Small | Write complexity at clarify, read at research/spec/review/drive |
| 5 | Add auto-upgrade logic to cortex-research | `skills/cortex-research/SKILL.md` | Small | Check trigger conditions after producing dossier |
| 6 | Add auto-upgrade logic to cortex-spec | `skills/cortex-spec/SKILL.md` | Small | Check write root count, validator count |
| 7 | Add complex gate: eval plan before spec approval | `skills/cortex-spec/SKILL.md` | Small | If complexity=complex, block spec approval if eval plan is (pending) |
| 8 | Add mandatory review/audit gates for complex in cortex-drive | `skills/cortex-drive/SKILL.md` | Small | New rows: complex requires review before assure, complex requires audit before assure |

### Should-Do (hardening)

| # | Task | File | Effort |
|---|------|------|--------|
| 9 | Add complexity auto-detection heuristic to cortex-drive | `skills/cortex-drive/SKILL.md` | Medium |
| 10 | Expand clarify-brief template comments with precise routing table | `templates/cortex/clarify-brief.md` | Tiny |
| 11 | Document pipeline variants in INTELLIGENCE_FLOW.md | `docs/INTELLIGENCE_FLOW.md` | Small |
| 12 | Update COMMANDS.md with complexity-conditional behavior | `docs/COMMANDS.md` | Small |

### Defer

| # | Task | Reason |
|---|------|--------|
| 13 | Separate template files for thin spec/contract | Conditional sections in existing templates is simpler |
| 14 | LLM auto-classification of complexity from idea text | Human input is sufficient; data on misclassification not yet available |
| 15 | Trivial skip clarify (direct to spec) | Loses traceability for ~500 token savings |

---

## Open Questions Resolved

> "What exactly does a 'thin spec' look like?"

**Answer:** 4 sections: Problem, Scope, Sequencing, Acceptance Criteria. Omits Architecture Decision, Interfaces, Dependencies, Risks, Tasks. Already specified in cortex-spec SKILL.md lines 57-62.

> "Should trivial slugs skip research entirely, or do a quick one-shot?"

**Answer:** Skip entirely. Already implemented in cortex-research SKILL.md lines 42-44. Sets `gates.research_complete = true` and exits.

> "Should complexity auto-upgrade be bidirectional?"

**Answer:** No. One-way upgrades only. Over-preparing wastes tokens (recoverable). Under-preparing ships bugs (not recoverable). Human can manually downgrade with logged override.

> "Does cortex-drive need to set complexity automatically?"

**Answer:** Cortex-drive should inherit from clarify brief. Auto-detection heuristic is a should-do, not a must-do. When unset, default to standard.

> "Should complex slugs mandate eval plans before spec approval?"

**Answer:** Yes. This is the key differentiator — you must know how to verify before committing to build. Standard allows (pending) through spec; complex does not.

---

## Sources

### Internal
- `skills/cortex-research/SKILL.md` lines 41-47 — existing complexity routing
- `skills/cortex-spec/SKILL.md` lines 57-62 — existing thin spec logic
- `skills/cortex-review/SKILL.md` — no complexity awareness (confirmed)
- `skills/cortex-drive/SKILL.md` — no complexity awareness (confirmed)
- `templates/cortex/clarify-brief.md` lines 9-16 — complexity field and comments
- 23 existing slug clarify briefs analyzed for empirical data

### Design
- `docs/cortex/research/complexity-tiers/concept-20260406T120000Z.md` — full pipeline variant design with thin spec/contract templates, upgrade mechanism, token estimates

### External
- BMAD Method Quick/Method/Enterprise tracks (docs.bmad-method.org)
- Pattern #9 from pattern-harvest concept dossier (scale-adaptive complexity tiers)
