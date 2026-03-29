---
phase: 1
slug: core-docs-and-architecture-alignment
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-29
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — documentation phase only |
| **Config file** | N/A |
| **Quick run command** | `test -f docs/INTELLIGENCE_FLOW.md && test -f docs/COMMANDS.md && test -f docs/CONTINUITY.md && test -f docs/EVALS.md && test -f docs/AGENTS.md && echo "ALL_DOCS_EXIST"` |
| **Full suite command** | See per-task verification map below |
| **Estimated runtime** | ~5 seconds (grep/test only) |

---

## Sampling Rate

- **After every task commit:** Run the file-existence + content-grep for that task's output
- **After every plan wave:** Run all automated commands in this table
- **Before `/gsd:verify-work`:** All 7 automated checks must return ✓
- **Max feedback latency:** N/A (manual review)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| T1 | 01-01 | 1 | DOCS-01 | automated | `grep -cE "cortex-clarify\|cortex-spec" CORTEX.md` (expect ≥1) | ❌ | pending |
| T2 | 01-01 | 1 | DOCS-02 | automated | `test -f docs/INTELLIGENCE_FLOW.md && grep -c "clarify" docs/INTELLIGENCE_FLOW.md` (expect ≥1) | ❌ | pending |
| T3 | 01-02 | 1 | DOCS-03 | automated | `grep -cE "cortex-clarify\|cortex-research\|cortex-spec\|cortex-investigate\|cortex-review\|cortex-audit\|cortex-status" docs/COMMANDS.md` (expect ≥7) | ❌ | pending |
| T4 | 01-02 | 1 | DOCS-04 | automated | `test -f docs/CONTINUITY.md && grep -c "current-state" docs/CONTINUITY.md` (expect ≥1) | ❌ | pending |
| T5 | 01-03 | 1 | DOCS-05 | automated | `test -f docs/EVALS.md && grep -cE "Functional correctness\|Regression\|Integration\|Safety\|Performance\|Resilience\|Style\|UX" docs/EVALS.md` (expect ≥8) | ❌ | pending |
| T6 | 01-03 | 1 | DOCS-06 | automated | `test -f docs/AGENTS.md && grep -cE "cortex-specifier\|cortex-critic\|cortex-scribe\|cortex-eval-designer" docs/AGENTS.md` (expect ≥4) | ❌ | pending |
| T7 | 01-03 | 1 | DOCS-07 | automated | `grep -cE "cortex-clarify\|cortex-spec" README.md` (expect ≥1) | ❌ | pending |

---

## Wave 0 Gaps

All 7 docs are net-new or full rewrites — no existing infrastructure to validate against before execution. This is expected for a documentation phase. The "File Exists" column above represents the Wave 0 state (all ❌). After Wave 1 executes, all should be ✓.

**Stale reference check (post-wave):**
```bash
# Confirm old architecture language is gone
grep -r "5 skills\|old command\|4 skills" docs/ README.md CORTEX.md 2>/dev/null | grep -v ".planning"
# Should return empty
```

---

## Phase Gate

All of the following must be true before phase is considered complete:

- [ ] `grep -cE "cortex-clarify|cortex-spec" CORTEX.md` → ≥ 1
- [ ] `test -f docs/INTELLIGENCE_FLOW.md` → OK
- [ ] `grep -cE "cortex-clarify|cortex-research|cortex-spec|cortex-investigate|cortex-review|cortex-audit|cortex-status" docs/COMMANDS.md` → ≥ 7
- [ ] `test -f docs/CONTINUITY.md` → OK
- [ ] `grep -cE "Functional correctness|Regression|Integration|Safety|Performance|Resilience|Style|UX" docs/EVALS.md` → ≥ 8
- [ ] `grep -cE "cortex-specifier|cortex-critic|cortex-scribe|cortex-eval-designer" docs/AGENTS.md` → ≥ 4
- [ ] `grep -cE "cortex-clarify|cortex-spec" README.md` → ≥ 1
- [ ] No stale references to old 5-command surface in any doc
