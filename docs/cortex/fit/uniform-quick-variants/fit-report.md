# Fit Report: uniform-quick-variants

<!-- ART-FIT: Fit Report Template — produced by /cortex-fit -->
<!-- SC2 forced-separation: each section must not repeat content from any other section -->

**Slug:** uniform-quick-variants
**Timestamp:** 20260330T183000Z
**Evaluated against:** Cortex v1.0 — all 8 skills (cortex-{audit,clarify,investigate,research,review,spec,status,fit}/SKILL.md), runtime-manifest.json skills list
**Confidence:** high — skill signature reads across full command surface + research dossier at docs/cortex/research/cortex-ak-integration/concept-20260330T180000Z.md
**Status:** pending-human-decision

---

## Tech Radar Ring

**Ring:** Adopt

**Justification:** Pure instruction standardisation across existing skills; the only backward-compat risk (cortex-audit --quick) is solved with a one-line alias.

---

## Gap

Five of eight skills have no depth/effort tier: cortex-clarify, cortex-spec, cortex-review, cortex-investigate, cortex-status. Users cannot trade quality for speed on these commands. For rapid iteration (e.g., a quick spec to validate a direction before committing to a full one) there is no supported shorthand. The command surface is inconsistent — research and audit behave differently from everything else, with no principled reason.

---

## Overlap

`--depth quick|standard|deep` already exists on `/cortex-research`. `--quick` already exists on `/cortex-audit`. The depth-tier pattern is established and validated. This proposal standardises what already works across the two commands that have it.

---

## Unique Contribution

None identified. This is pattern standardisation, not a new concept. Its value is consistency and discoverability — a user who knows `--depth quick` works on research can reasonably expect it on spec, clarify, and review.

---

## Conflict

**cortex-audit --quick backward compatibility (hard constraint):** `--quick` on cortex-audit is a documented flag. Renaming it to `--depth quick` without a backward-compat alias breaks existing usage. The alias `--quick` → `--depth quick` must be permanent (not time-limited deprecated) since cortex-audit's SKILL.md is used by installed users who won't see a deprecation notice.

**Quick spec quality risk (soft tension, requires explicit mitigation):** A spec produced at `--depth quick` that omits the Risks section and Alternatives Considered is meaningfully less safe for high-stakes contracts. If this risk is not surfaced at generation time, users may ship quick specs into contexts that warrant standard ones. Mitigation: `--depth quick` on cortex-spec must emit a visible warning at output time — not buried in the artifact, but as the first line of the terminal summary.

No other conflicts. All other skills' quick variants drop non-critical sections (open-questions expansion, security lens, pattern-analysis phase) where the trade-off is acceptable.

---

## Strategic Direction

**Alignment:** aligned

A consistent, learnable command surface is a stated cortex design goal. Uniform depth tiers reduce cognitive load and make the skill system feel like a coherent tool rather than a collection of independently-designed commands. The proposal advances this without adding new commands, new concepts, or new infrastructure.

---

## Pre-Populated Clarify Brief Fields

**Proposed goal:** Add `--depth quick|standard|deep` to cortex-clarify, cortex-spec, cortex-review, and cortex-investigate; add `--quick` as a permanent alias on cortex-audit; and define a per-command "what quick drops" table with explicit quality warnings where the trade-off is non-trivial.

**Constraints:**
- `--quick` on cortex-audit must remain as a permanent alias for `--depth quick` — no deprecation
- `--depth quick` on cortex-spec must emit a visible quality warning at generation time (first line of terminal summary)
- Quick variants may only drop non-blocking sections — they must never drop Acceptance Criteria from spec or done_criteria from contracts

**Open questions:**
- For cortex-clarify `--depth quick`: should open-questions expansion be dropped, or should the questions still be generated but not expanded with follow-ups?
- For cortex-review `--depth quick`: is engineering-lens-only acceptable, or should a minimal security check (secrets scan only) always run regardless of depth?
- Should `--depth deep` add anything to commands that currently have no deep tier — e.g., cortex-spec + convergence pass, cortex-clarify + extra Q&A round?
- Is cortex-status in scope for depth tiers, or is it always a fixed-cost reconstruction command?

---

## Human Decision

**Status:** pending-human-decision

To advance: change status to `approved` or `rejected` and add a one-line note.

- [ ] Approved — proceed to `/cortex-clarify uniform-quick-variants`
- [ ] Rejected — archive this report, no further action

**Decision note:** _(fill in when deciding)_
