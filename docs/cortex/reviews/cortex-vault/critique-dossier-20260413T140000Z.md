# Critique: dossier — cortex-vault

**Gate:** dossier
**Slug:** cortex-vault
**Timestamp:** 2026-04-13T14:00:00Z
**Artifact:** docs/cortex/research/cortex-vault/concept-20260413T140000Z.md
**Engine:** codex
**Overall Severity:** STOP

---

## Summary

This dossier is not decision-ready. It overstates certainty, leaves core implementation assumptions unresolved, and supports key architecture claims with weak or missing evidence.

---

## Findings (4 total — STOP: 2, CAUTION: 2, GO: 0)

### [STOP] assumption backing

**Finding:** The dossier makes a core architectural recommendation that directly contradicts its own unresolved implementation risks. It declares the write path decided and 'fully audited' while leaving basic viability questions unanswered: importability of `fact_store.py`, uniqueness/idempotency behavior, and whether the project filter actually works. That is not an answered design; it is an unvalidated assumption stack.

**Quote from artifact:**
> All seven open questions are answered. The vault read/write round-trip is fully audited. The right integration pattern for this slug is:
> 
> 2. **Write (gate transitions):** call `fact_store.add_fact()` directly ...
> ...
> ## Open Questions
> 
> - **How does idempotency work for direct `add_fact()` calls?** If a dossier is revised and re-extracted, duplicate facts may accumulate.
> ...
> - **Does `recall_query.py` accept `--project cortex` or does project_scope need to match exactly?**
> ...
> - **Can `fact_store.py` be imported from the cortex repo scripts directory, or does it require being run from `~/memory/vault/`?**

**Impact:** Downstream execution will build against a write path that may not import cleanly, may duplicate facts indefinitely, and may not be retrievable with the claimed scope filter. That turns the supposed 'plumbing job' into a rework cycle during implementation.

---

### [STOP] evidence adequacy

**Finding:** The dossier presents concrete operational numbers and file-specific assertions as established facts without showing any supporting evidence, measurements, or excerpts. The budget arithmetic, exact injection point, and output size claims are asserted as if verified, but the artifact provides no traceable proof from the cited files or runs.

**Quote from artifact:**
> The existing `cortex-session-start.sh` hook already has the right injection point — after line 40, before the health check — with ~5000–8000 chars of budget remaining after current state injection. The 10K cap is real. Top-5 vault facts using `recall_query.py` with `--project cortex` and a slug-relevant query produces well under 1500 chars.

**Impact:** Implementation will anchor on brittle, unverified numbers. If the line offsets, cap behavior, or output sizes differ in reality, the hook integration will fail or silently degrade context injection, wasting work on a false precision plan.

---

### [CAUTION] source authority

**Finding:** The dossier relies on low-authority aggregation for several of its most general claims about memory-system patterns, then uses those claims to justify architecture decisions. 'Perplexity research' is not a primary source, and 'general industry patterns (2024-2026)' are presented without citations to official docs, papers, or reproducible benchmarks.

**Quote from artifact:**
> - Perplexity research: Letta/MemGPT tiered memory patterns, budget-aware injection, token arithmetic
> ...
> **General industry patterns (2024-2026):**
> - Lazy loading: fetch only task-relevant data at session start; reduces irrelevant data from 60-70% to <10%
> - Budget zones: reserve system prompt + tools + output space first; inject memory in the remaining budget
> - RAG top-k: 3–8 chunks, ~1K–10K tokens per request; more chunks degrades quality

**Impact:** The architecture rationale is built partly on hearsay and unattributed trend claims. That weakens confidence in the chosen retrieval strategy and makes the dossier unsuitable as a durable design reference.

---

### [CAUTION] traceability

**Finding:** The dossier claims every question is answered, but several 'durable findings' do not map cleanly to answered questions and instead introduce new claims that were not established. The strongest example is the extraction schema summary, which says all facts use `memory_type=semantic` while the dossier's own mapping table assigns `failed-approach` to `procedural`.

**Quote from artifact:**
> 4. **Extraction schema is clear:** 9 fact categories from 3 artifact types, all using `memory_type=semantic`, `project_scope=cortex`, `scope=learning`.
> ...
> | Spec Alt Considered + Rejected | "Rejected X for slug Y because Z. Not just preference — [evidence]" | "failed-approach" | procedural | cortex | 0.85 | 0.75 |

**Impact:** The implementation team will not know which schema to honor. That creates inconsistent writes, retrieval mismatches, and schema drift between the extractor and the vault store.

---
