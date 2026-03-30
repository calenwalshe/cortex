# Cortex Fit — Composition-Stage Compatibility Check

Evaluates whether an incoming thing (tool, framework, agent, plugin, pattern, concept) fits within the current Cortex ecosystem. Produces a structured fit report artifact with SC2 forced-separation reasoning, a Tech Radar ring signal, and pre-populated fields for the downstream `/cortex-clarify` integration brief. Human gates the decision.

Formally defined as `S=(C, π, T, R)` following the SoK Agentic Skills lifecycle model (arXiv 2602.20867), positioned at the composition stage: the compatibility check that runs before a new thing is integrated.

## User-invocable

When the user types `/cortex-fit`, run this skill.

Also trigger when:
- "does X fit in our ecosystem"
- "evaluate X against what we have"
- "should we adopt X"
- "fit check on X"
- "compare X to our stack"

## Arguments

- `/cortex-fit <X>` — evaluate X against the current Cortex context (Y inferred from active slug and ecosystem description)
- `/cortex-fit <X> against <Y>` — evaluate X explicitly against Y (use when Y is not the active Cortex project or needs to be stated precisely)

`<X>` may be a slug (e.g., `karpathy-autoresearch`), a proper noun (e.g., `DSPy`), or a short description.

---

## S=(C, π, T, R) Formalisation

### C — Applicability Conditions

Run `/cortex-fit` when ALL of the following are true:
1. A new entity (tool, framework, agent, plugin, pattern, or concept) has surfaced — in research output, a conversation, a clarify brief, or externally
2. The entity potentially overlaps with, fills a gap in, or conflicts with the current ecosystem
3. A fit evaluation has not already been produced for this slug under `docs/cortex/fit/{slug}/`

Do NOT run `/cortex-fit` when:
- The entity is already fully integrated (the decision is made)
- The goal is a security audit — use `/cortex-audit` instead
- The goal is evaluating agent output quality — use `/cortex-review` instead
- The entity was already evaluated and the fit report is on disk

### π — Execution Policy

SC2 forced-separation reasoning across five dimensions. Each dimension is populated independently. **No section may repeat content from any other section.** This is the core invariant — collapsing sections into vague prose is the failure mode this skill is designed to prevent.

### T — Termination Criteria

The skill terminates when:
1. `docs/cortex/fit/{slug}/fit-report.md` is written to disk
2. The fit report contains all five dimensions, a Tech Radar ring signal, a human decision field, and pre-populated clarify brief fields
3. Continuity state is updated

The skill does NOT invoke `/cortex-clarify`. It stops at the recommendation. The human decides.

### R — Reusable Interface

```
Input:  (incoming: slug | description, existing: ecosystem context | description)
Output: fit-report.md at docs/cortex/fit/{slug}/fit-report.md
```

The fit report's gap and conflict fields map directly to the open questions and constraints of a new `/cortex-clarify` brief, making the handoff mechanical.

---

## Instructions

### Phase 1: Resolve slug and gather inputs

1. Slugify `<X>`:
   - Lowercase, replace spaces/non-alphanumeric with hyphens, collapse consecutive hyphens, strip leading/trailing hyphens
   - Example: `"Karpathy AutoResearch"` → `karpathy-autoresearch`

2. Check for existing fit report:
   - If `docs/cortex/fit/{slug}/fit-report.md` exists: read it, report to the user that a fit report already exists, and ask whether to overwrite or append. Do not proceed silently.

3. Resolve Y (existing ecosystem):
   - If `against <Y>` was provided: use Y as stated
   - Otherwise: read `.cortex/state.json` for active slug and context; infer ecosystem from the active Cortex project

4. Gather primary input for X:
   - Check `docs/cortex/research/{slug}/` — read all dossiers if present. Set `confidence: high`.
   - Check `docs/cortex/clarify/{slug}/` — read clarify brief if present.
   - If no dossiers or briefs exist: reason from the description alone. Set `confidence: low`. Note this prominently in the fit report.

### Phase 2: SC2 forced-separation reasoning

Populate each of the five dimensions **independently**. Before writing each section, read back the prior sections and confirm you are not repeating content already stated.

**Section 1 — Gap**
What does X fill that the current ecosystem lacks entirely?
- Identify capabilities, patterns, or workflows that the existing ecosystem cannot perform without X
- Do not include items that already exist in diminished or partial form (those belong in Overlap)
- Do not include conflicts (those belong in Conflict)

**Section 2 — Overlap**
Where does X duplicate or significantly overlap with something already present?
- Identify specific existing components, skills, or patterns that X would partially or fully replace
- Note the degree of overlap (full replacement vs. partial duplication)
- Do not include gaps (things X fills that don't exist yet) — those belong in Gap
- Do not include conflicts (incompatibilities) — those belong in Conflict

**Section 3 — Unique Contribution**
What does X bring that is genuinely novel — not a gap-fill and not an overlap?
- This is the hardest dimension to populate. Most things don't have a unique contribution beyond their gap-fill.
- If nothing here, state "None identified" — do not pad this section with rephrased Gap items
- Do not repeat content from Gap or Overlap

**Section 4 — Conflict**
Where would X actively clash with the existing ecosystem's principles, architecture, or assumptions?
- Identify specific technical incompatibilities, process conflicts, or philosophical tensions
- Distinguish between conflicts that block adoption and tensions that require mitigation
- Do not include overlaps (duplications that don't necessarily conflict) — those belong in Overlap
- Do not include gaps (things X fills) — those belong in Gap

**Section 5 — Strategic Direction**
Is X pointing in the same direction the ecosystem is heading?
- Assess directional alignment, not just current-state compatibility
- Note whether X's trajectory (roadmap, community, evolution) matches or diverges from the ecosystem's direction
- State explicitly: aligned / partially aligned / misaligned, with a one-sentence reason

### Phase 3: Write Tech Radar ring signal

Assign one of: **Hold / Assess / Trial / Adopt**

| Ring | Meaning |
|------|---------|
| Hold | Do not use — conflicts, maturity issues, or strategic misalignment outweigh the gap-fill |
| Assess | Worth understanding more deeply — promising but unvalidated in this context |
| Trial | Use in a bounded experiment — enough evidence to test, not enough to commit |
| Adopt | Integrate — evidence is strong, conflicts are manageable, direction is aligned |

Write a single justification sentence (≤25 words). The justification must reference at least one specific finding from the five dimensions above.

### Phase 4: Pre-populate clarify brief fields

Derive the following fields directly from the Gap and Conflict sections (no synthesis — map the content mechanically):

- **Proposed goal:** One sentence: what integration success looks like, derived from the Gap section
- **Constraints:** Bullet list from the Conflict section — each conflict becomes a constraint or a question to resolve
- **Open questions:** Bullet list of unresolved items from all five dimensions — things that would change the ring signal if answered

These fields are ready-to-paste into `/cortex-clarify` if the human approves.

### Phase 5: Write fit report

Read the template at `templates/cortex/fit-report.md`. Fill all fields from Phases 1–4. Write to:

```
docs/cortex/fit/{slug}/fit-report.md
```

Create the directory if needed:
```bash
mkdir -p docs/cortex/fit/{slug}/
```

The `status` field must be `pending-human-decision`. Do not set it to anything else.

### Phase 6: Update continuity state

**Update `.cortex/state.json`:**
- Append `docs/cortex/fit/{slug}/fit-report.md` to `artifacts`

**Update `docs/cortex/handoffs/current-state.md`:**
- Append `docs/cortex/fit/{slug}/fit-report.md` to `recent_artifacts`
- Set `next_action`: `Human must review fit-report.md and set status to approved or rejected`

### Phase 7: Output terminal summary

```
FIT REPORT WRITTEN
════════════════════════════════════════
Slug:       {slug}
Confidence: {high | low}
Ring:       {Hold | Assess | Trial | Adopt}
Status:     pending-human-decision
Path:       docs/cortex/fit/{slug}/fit-report.md

Ring justification:
  {one-line justification}

Pre-populated clarify brief fields:
  Goal:        {proposed goal}
  Constraints: {N} items
  Questions:   {N} items

Next: Human reviews fit-report.md and approves or rejects
════════════════════════════════════════
```

---

## Rules

- **Does not invoke `/cortex-clarify`** — terminates at the recommendation. Human gates the transition.
- **Does not modify GSD planning state** — `.planning/`, `STATE.md`, phase plans are untouched.
- **SC2 forced-separation is the invariant** — if any section repeats content from another, the report is invalid. Re-run the section.
- **Confidence field is mandatory** — `high` when a dossier exists, `low` when reasoning from description alone.
- **Status field is always `pending-human-decision`** — the skill never approves its own recommendation.
- **Output is always a repo-local artifact** — chat-only responses do not satisfy this command.
