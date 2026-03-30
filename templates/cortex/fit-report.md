# Fit Report: {SLUG}

<!-- ART-FIT: Fit Report Template — produced by /cortex-fit -->
<!-- SC2 forced-separation: each section must not repeat content from any other section -->

**Slug:** {SLUG}
**Timestamp:** {TIMESTAMP}
**Evaluated against:** {ECOSYSTEM}
**Confidence:** {high | low — high when dossier exists, low when description-only}
**Status:** pending-human-decision

---

## Tech Radar Ring

**Ring:** {Hold | Assess | Trial | Adopt}

**Justification:** {One sentence, ≤25 words, referencing a specific finding below}

---

## Gap

<!-- What does {SLUG} fill that the ecosystem lacks entirely?
     Do NOT include: things that already exist in partial form (→ Overlap), incompatibilities (→ Conflict) -->

{Gap analysis}

---

## Overlap

<!-- Where does {SLUG} duplicate or significantly overlap with something already present?
     Do NOT include: things the ecosystem fully lacks (→ Gap), incompatibilities (→ Conflict) -->

{Overlap analysis}

---

## Unique Contribution

<!-- What does {SLUG} bring that is genuinely novel — not a gap-fill, not an overlap?
     If nothing: state "None identified" — do not pad with rephrased Gap items.
     Do NOT repeat content from Gap or Overlap. -->

{Unique contribution analysis}

---

## Conflict

<!-- Where would {SLUG} actively clash with the ecosystem's principles, architecture, or assumptions?
     Distinguish: hard blockers vs. tensions requiring mitigation.
     Do NOT include: duplications that don't conflict (→ Overlap), gap-fills (→ Gap) -->

{Conflict analysis}

---

## Strategic Direction

<!-- Is {SLUG} pointing the same direction the ecosystem is heading?
     State explicitly: aligned / partially aligned / misaligned + one-sentence reason.
     Do NOT repeat findings from other sections — assess trajectory, not current state. -->

**Alignment:** {aligned | partially aligned | misaligned}

{Strategic direction analysis}

---

## Pre-Populated Clarify Brief Fields

<!-- Derived mechanically from Gap and Conflict sections above — ready to paste into /cortex-clarify if approved -->

**Proposed goal:** {One sentence: what integration success looks like, from the Gap section}

**Constraints:**
{- Each conflict becomes a constraint or a question to resolve}

**Open questions:**
{- Unresolved items from all five dimensions that would change the ring signal if answered}

---

## Human Decision

**Status:** pending-human-decision

To advance: change status to `approved` or `rejected` and add a one-line note.

- [ ] Approved — proceed to `/cortex-clarify {SLUG}`
- [ ] Rejected — archive this report, no further action

**Decision note:** _(fill in when deciding)_
