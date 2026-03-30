# Fit Report: ak-lite-reasoning-kernel

<!-- ART-FIT: Fit Report Template — produced by /cortex-fit -->
<!-- SC2 forced-separation: each section must not repeat content from any other section -->

**Slug:** ak-lite-reasoning-kernel
**Timestamp:** 20260330T183000Z
**Evaluated against:** Cortex v1.0 — layers/, CLAUDE.md.snippet, skills/cortex-{clarify,research,spec,review}/SKILL.md
**Confidence:** high — full codebase read + research dossier at docs/cortex/research/cortex-ak-integration/concept-20260330T180000Z.md
**Status:** pending-human-decision

---

## Tech Radar Ring

**Ring:** Trial

**Justification:** Fills a real reasoning-consistency gap but requires careful scoping of the "make" boundary to avoid blurring the GSD/Cortex layer separation.

---

## Gap

The current thinking layer (`layers/thinking/`) contains behavioral rules — anti-sycophancy, forcing questions, investigation protocol, security posture — but no sequential per-skill reasoning kernel. Each skill (clarify, research, spec, review) defines its own independent multi-phase instruction set. There is no shared parent loop that each skill inherits or references. The result is that the reasoning posture varies by skill rather than expressing a consistent pipeline.

Specifically absent:
- A named 4-phase kernel (attune → shape → make → refine) that all skills follow as a preamble
- A shared vocabulary for which cortex phase maps to which reasoning mode
- An explicit handoff signal marking where cortex's work ends and GSD's begins (the make boundary)

---

## Overlap

`layers/thinking/anti-sycophancy.md` and `layers/thinking/forcing-questions.md` already partially implement "attune" behavior — they push the model to understand the problem deeply before responding. `CLAUDE.md.snippet` already describes Layer 3 (Thinking) as always-active. The cortex-clarify skill's clarifying-question phase functionally enacts attune. cortex-review's engineering + security lens structure functionally enacts refine.

These are not the kernel — they are behavioral fragments that the kernel would organise into a named sequence. The overlap means the kernel does not need to rewrite these; it needs to name and reference them.

---

## Unique Contribution

A cross-skill contract expressed as a named phase sequence. Currently each skill is legible as an independent tool; the kernel makes the full cortex pipeline legible as a single reasoning system. The phase names (attune → shape → make → refine) create a vocabulary that appears in CLAUDE.md.snippet, each SKILL.md preamble, and in the thinking layer — allowing the user to reason about where in the pipeline a given command sits and what reasoning mode it should activate.

This is not just a gap-fill. It is a structural framing that did not exist before and that gives the system a principled shape even if all the underlying behaviors were already partially present.

---

## Conflict

**Make boundary (hard tension, requires mitigation):** The "make" phase maps to GSD execution. Cortex explicitly does not own execution — that is Layer 1 (Workflow/GSD). If "make" is included in the kernel without a precise boundary definition, it invites scope creep where cortex skills start issuing execution instructions. The kernel must define "make" as an output-handoff action, not an execution action: "produce the GSD handoff artifact and terminate."

**Prompt inflation (soft tension, manageable):** Inlining the kernel in each SKILL.md multiplies prompt weight by the number of skills that reference it. Mitigation: keep the kernel to ≤250 words in `layers/thinking/reasoning-kernel.md` and reference it by path in skill preambles rather than duplicating.

**Activation gap (hard blocker if not addressed):** Files in `layers/` are not automatically loaded by Claude Code — they only activate if referenced in CLAUDE.md.snippet or the session's global config. Wiring the kernel through CLAUDE.md.snippet (not just layers/) is required for it to be always-active. If this is missed, the kernel exists on disk but has no effect.

---

## Strategic Direction

**Alignment:** aligned

Cortex's trajectory is toward stronger reasoning guarantees and more principled, auditable command behavior. The kernel advances that trajectory by naming the phases explicitly and making them testable (a failing attune step is now identifiable). The risk of the make boundary conflict is structural but solvable by definition, not by architectural rework.

---

## Pre-Populated Clarify Brief Fields

**Proposed goal:** Embed a ≤250-word attune→shape→make→refine kernel into `layers/thinking/reasoning-kernel.md`, wire it through `CLAUDE.md.snippet` as always-active, and reference it in the preamble of cortex-clarify, cortex-research, cortex-spec, and cortex-review SKILL.md files.

**Constraints:**
- "make" must be defined as a handoff-termination action, not execution — preserves the GSD/Cortex layer boundary
- Kernel must be wired through CLAUDE.md.snippet (not layers/ alone) to guarantee always-on activation
- Kernel body must stay ≤250 words to avoid prompt inflation across all referencing skills

**Open questions:**
- Should the kernel be a standalone file in `layers/thinking/` or inlined directly into CLAUDE.md.snippet?
- Which skills get preamble references in phase 1 vs. a later phase — does cortex-audit and cortex-investigate also need wiring?
- How do we test that the kernel is active — is there a forcing-question or eval dimension that validates it?

---

## Human Decision

**Status:** pending-human-decision

To advance: change status to `approved` or `rejected` and add a one-line note.

- [ ] Approved — proceed to `/cortex-clarify ak-lite-reasoning-kernel`
- [ ] Rejected — archive this report, no further action

**Decision note:** _(fill in when deciding)_
