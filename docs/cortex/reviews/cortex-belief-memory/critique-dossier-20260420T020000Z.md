# Critique: dossier — cortex-belief-memory

**Gate:** dossier
**Slug:** cortex-belief-memory
**Timestamp:** 2026-04-20T03:29:00Z
**Artifact:** docs/cortex/research/cortex-belief-memory/concept-20260420T020000Z.md
**Engine:** codex
**Overall Severity:** STOP

---

## Summary

This dossier has a structural evidence problem: it makes hard implementation recommendations from low-authority chatbot synthesis and unsupported audit claims. The result is not a reliable basis for execution because key architecture changes are asserted, not proven.

---

## Findings (4 total — STOP: 2, CAUTION: 2)

### [STOP] source authority

**Finding:** The dossier elevates unverified chatbot output into the primary basis for architecture decisions. It explicitly treats ChatGPT and Gemini as the decisive evidence for schema design, promotion policy, dependency tracking, and retrieval strategy, even though the artifact itself admits those responses are only supplementary and not primary evidence.

**Quote from artifact:**
> The ChatGPT recommendation is stronger — filtering-only scoping creates fragile implicit ownership that breaks on rebuild.

**Impact:** Downstream implementation will hard-code schema migrations and belief-system behavior based on low-authority synthesis instead of primary sources or validated experiments, creating expensive rework when those recommendations fail in the real codebase.

---

### [STOP] evidence adequacy

**Finding:** Major findings are presented as facts without the evidence needed to verify them. The dossier claims exact insertion points, missing code paths, and engine non-use from a codebase audit, but it provides no file paths, line references, excerpts, or command output tying those assertions to the repository.

**Quote from artifact:**
> - Source: codebase audit, line-level analysis of SKILL.md files

**Impact:** Execution will be driven by assertions that cannot be checked, so engineers can easily modify the wrong skill phases, miss the real call sites, or chase nonexistent gaps.

---

### [CAUTION] traceability

**Finding:** The dossier injects at least one major recommendation that does not trace cleanly to the stated research questions or source map. 'Build CortexModule' appears in the recommendations, but no finding establishes that module as a researched requirement or ties it to a specific open question in the source table.

**Quote from artifact:**
> 6. **Build CortexModule** — L3 module with namespace 'cortex', form_types specialized for discovery artifacts (plan, design_rule, open_question), rules specialized for the research loop (plan_tracking, research_gap_detection).

**Impact:** This creates orphan work that can expand scope without justification, pulling implementation effort into a module invention that the dossier never proved necessary.

---

### [CAUTION] assumption backing

**Finding:** The core schema recommendation is asserted as obviously correct without any measured comparison, migration analysis, or failure evidence. The dossier assumes explicit scope columns are the right answer and declares namespace filtering fragile, but supplies no test results, workload data, or authoritative design source to support that conclusion.

**Quote from artifact:**
> Add `scope_type` (global|project) and `scope_id` (nullable, slug for project-scoped) to logical_forms table. This is preferred over namespace-only filtering because:

**Impact:** The team may lock itself into a disruptive schema change with unclear payoff, when a lighter-weight ownership model might satisfy the same requirements with less migration risk.
