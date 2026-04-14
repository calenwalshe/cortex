# Critique: spec — operational-map-layer

**Gate:** spec
**Slug:** operational-map-layer
**Timestamp:** 2026-04-13T19:40:00Z
**Artifact:** docs/cortex/specs/operational-map-layer/spec.md
**Engine:** codex
**Overall Severity:** STOP

---

## Summary

This spec uses unverifiable acceptance criteria and pushes completion onto future production usage, so it cannot be cleanly implemented or signed off. It also leaks scope into global skill files and relies on vague risk mitigations that do not actually control failure.

---

## Findings (4 total — STOP: 2, CAUTION: 2, GO: 0)

### [STOP] ac_testability

**Finding:** AC7 and AC8 are not mechanically verifiable. They require a vague documentation change in external skill files and use the undefined requirement to "soft-fail silently," which has no objective pass/fail signal and no executable verification procedure.

**Quote from artifact:**
> - [ ] AC7: `~/.claude/skills/cortex-clarify/SKILL.md` includes a step that reads `--summary` output (or falls back to raw ledger) before clarify brief population; step soft-fails silently if `.cortex/edit-ledger.jsonl` is absent
> - [ ] AC8: `~/.claude/skills/cortex-spec/SKILL.md` includes a step that reads `--summary` output before spec synthesis; step soft-fails silently if ledger is absent

**Impact:** Implementation teams cannot tell when these criteria are satisfied, which guarantees inconsistent behavior across environments and invites false claims of completion without proving the integration actually runs.

---

### [STOP] ac_testability

**Finding:** AC10 is not an acceptance criterion for build completion because it depends on future production behavior outside the implementation boundary. A spec cannot use "after 5 real editing sessions" as a gate and simultaneously call the work complete.

**Quote from artifact:**
> - [ ] AC10 (live): After 5 real editing sessions (production use, not test fixtures), `--summary` output contains at least one file with `edit_count ≥ 2` and at least one `co_change_pair` with `session_count ≥ 2` — this criterion can only be satisfied after actual use; mark deferred-to-production in the contract

**Impact:** Execution stalls at handoff because nobody can close the spec in development, and downstream planning cannot distinguish between an unfinished implementation and an implemented feature waiting on incidental user activity.

---

### [CAUTION] scope_coherence

**Finding:** The spec describes project-local operational indexing but mutates global home-directory skill files outside the project. This turns a local spec into a cross-environment rollout with unclear ownership and blast radius.

**Quote from artifact:**
> ### In Scope
> - Injection step in `~/.claude/skills/cortex-clarify/SKILL.md` — reads operational context before brief population
> - Injection step in `~/.claude/skills/cortex-spec/SKILL.md` — reads operational context before spec synthesis

**Impact:** Work will sprawl beyond the repo, break portability between machines, and create version skew where one project's spec silently changes global behavior for every other project using the same skills.

---

### [CAUTION] risk_completeness

**Finding:** Several mitigations are non-actions disguised as mitigations. "Document as a known limitation" and "revert if brief fails to generate" do not prevent or detect the failure mode in any reliable way.

**Quote from artifact:**
> - **`/clear` fragments session_id** — Mitigation: document as a known limitation; treat session-level co-change as approximate signal
> - **SKILL.md injection breaks existing skill flow** — Mitigation: soft-fail everywhere; run `/cortex-clarify` on a throwaway slug after each SKILL.md edit; revert if brief fails to generate

**Impact:** Known data corruption and workflow breakage remain uncontained, so downstream consumers will trust degraded co-change signals without any concrete safeguard or automated detection.

---
