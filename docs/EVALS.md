# Evals

> **Status:** Architectural specification for the eval subsystem — a Phase 5 deliverable. This document defines what first-class evals look like so Phase 5 has a documented target.

---

## Why Evals Are First-Class

Every active contract must reference an eval plan. Evals are not a post-delivery nicety — they are the gate between `assure` and `done`. The contract lifecycle does not advance to `done` without a passing eval record. A spec without an eval plan is incomplete; it makes the definition of done ambiguous and unmeasurable.

Silent failures are not allowed. A failed eval must produce a repair recommendation or open a repair contract. The system never advances past a failing eval by ignoring it. If an eval fails and no repair path is defined, the contract stalls at `validate` until one is written.

---

## Eval Lifecycle

### 1. Proposal

`/cortex-research --phase evals` produces an eval proposal. The proposal covers: which dimensions apply, fixture descriptions, rubrics for each dimension, pass/fail thresholds, and a failure taxonomy (what each failure mode implies for repair). The eval proposal is written to `docs/cortex/evals/<slug>/eval-proposal.md` in the target project repo.

### 2. Human Approval

When an eval is subjective, high-stakes, or ambiguous, an explicit human approval is required before the eval plan is written. The system blocks progression until the human responds. The eval-designer agent marks `approval_required: true` in the proposal when this gate applies. Approval cannot be bypassed — the contract stays in `spec` state until the human confirms.

### 3. Plan

After human approval (or immediately if no approval gate applies), `eval-plan.md` is written to `docs/cortex/evals/<slug>/eval-plan.md`. The eval plan is the authoritative record of which evals will run, what fixtures will be used, and what thresholds must be met.

### 4. Execution

Evals run against the contract's deliverables. Execution is triggered by the `cortex-validator-trigger` hook (Phase 4 deliverable) or manually. Each eval dimension listed in the eval plan is checked independently.

### 5. Results

Results are written to `docs/cortex/evals/<slug>/results-<timestamp>.md`. If all evals pass, the contract advances to `assure`. If any eval fails, the system produces a repair recommendation or opens a repair contract — progression to `assure` is blocked.

### 6. Repair and Assure

The repair loop re-runs evals after each repair iteration. All evals passed is the gate to `assure`. Only after all evals pass and the contract's done criteria are met does the state advance to `done`.

---

## Candidate Eval Matrix

All 8 dimensions below are candidates for any contract. The eval-designer agent selects which dimensions apply based on the contract's scope.

| Dimension | What It Covers | When Mandatory |
|-----------|----------------|----------------|
| **Functional correctness** | Does the implementation do what the spec says? | Always |
| **Regression** | Did this change break existing behavior? | Whenever existing code is modified |
| **Integration** | Do the components work together correctly? | When multiple components interact |
| **Safety/security** | Does the implementation introduce security vulnerabilities? | Auth, data handling, input validation, secrets |
| **Performance** | Does it meet the performance requirements in the contract? | When contract specifies perf thresholds |
| **Resilience** | Does it handle failure modes correctly? | Networked systems, external dependencies |
| **Style** | Does it follow the project's coding and documentation conventions? | All code and doc deliverables |
| **UX/taste** | Does the output feel right to a human? (subjective — always requires human approval) | User-facing output, generated content |

---

## When Human Approval Is Mandatory

- Any eval dimension marked as subjective in the eval proposal
- Any eval where the success threshold is ambiguous (cannot be mechanically verified)
- Any eval for a high-stakes or irreversible operation (data migrations, auth changes, security boundaries)
- UX/taste dimension always requires human approval
- When the eval-designer agent marks `approval_required: true` in the eval proposal

---

## Repair Loop

A failed eval is never a dead end — it always produces a path forward.

When an eval fails: a repair recommendation is written to `docs/cortex/` in the target repo. If the repair is complex or involves significant re-scoping, a new repair contract is opened. The repair is implemented under the repair contract. After repair, evals re-run from the beginning of the eval list. Silent failure is never acceptable — a stale `validate` state with no repair document is a process violation.

---

## Invocation

| Operation | How to invoke |
|-----------|--------------|
| Eval proposal | `/cortex-research --phase evals` |
| Eval plan | Written by eval-designer after human approves the proposal |
| Eval execution | Triggered by `cortex-validator-trigger` hook (Phase 4) or run manually |

---

## Artifact Paths

All eval artifacts are written to the **target project repo**, not the Cortex framework repo.

| Artifact | Path (in target repo) |
|----------|-----------------------|
| Eval proposal | `docs/cortex/evals/<slug>/eval-proposal.md` |
| Eval plan | `docs/cortex/evals/<slug>/eval-plan.md` |
| Eval results | `docs/cortex/evals/<slug>/results-<timestamp>.md` |

---

## Contract Reference Requirement

Every active contract (`docs/cortex/contracts/<slug>/contract-001.md`) must include an `eval_plan` field pointing to the eval plan path. Contracts without an eval plan reference are incomplete and must not advance past `spec` state. The contract's `eval_plan` field is a hard requirement, not an optional annotation.
