# docs/cortex/contracts/

**Artifact type:** Execution contract — the approval gate before any product code is written

---

## Naming Pattern

```
docs/cortex/contracts/<slug>/contract-001.md
docs/cortex/contracts/<slug>/contract-002.md  (repair contracts increment)
```

- `<slug>` matches the slug from the corresponding clarify brief and spec
- The first contract is always `contract-001.md`
- Repair contracts produced by `/cortex-investigate` increment the counter: `contract-002.md`, `contract-003.md`, etc.

**Examples:**
```
docs/cortex/contracts/smart-retry-logic/contract-001.md
docs/cortex/contracts/smart-retry-logic/contract-002.md
```

---

## Required Fields

Every contract must contain all of the following fields:

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique contract identifier (e.g., `smart-retry-logic-001`) |
| `slug` | string | The active slug this contract governs |
| `phase` | string | Lifecycle phase: `clarify`, `research`, `spec`, `execute`, `validate`, `repair`, `assure`, `done` |
| `objective` | string | Single-sentence statement of what this contract delivers |
| `deliverables` | list | Concrete outputs the executor must produce |
| `scope.in` | list | What is in scope for execution |
| `scope.out` | list | What is explicitly out of scope |
| `write_roots` | list | File paths or directories the executor is permitted to write to — no writes outside this list |
| `done_criteria` | list | Conditions that must all be true for this contract to be considered fulfilled |
| `validators` | list | Commands or checks that verify done criteria |
| `eval_plan` | string | **MANDATORY** — path to the eval plan for this contract (e.g., `docs/cortex/evals/<slug>/eval-plan.md`). Contracts without this field are incomplete. |
| `approvals` | object | Approval status per gate: `{ contract: pending\|approved\|rejected, evals: pending\|approved\|rejected }` |
| `rollback_hints` | list | Steps to undo this contract's changes if needed |

---

## Status Values

| Status | Meaning |
|--------|---------|
| `draft` | Contract has been written but not yet reviewed by the human |
| `approved` | Human has reviewed and approved — execution may begin |
| `closed` | Contract is fulfilled — all done criteria met and validators passed |

Execution **must not begin** until the contract status is `approved`. The human approval gate is hard — no automation bypasses it.

---

## eval_plan Field (Mandatory)

The `eval_plan` field is mandatory on every contract. It references the eval plan that governs how this contract's outputs will be validated. A contract without `eval_plan` is incomplete and must not be approved.

- Before the eval plan exists: set `eval_plan` to the expected path and mark it as `pending`
- After `/cortex-research --phase evals` produces an eval proposal and the human approves it: the eval plan is written and the path is confirmed

See `docs/EVALS.md` for the eval artifact lifecycle and the 8-dimension candidate matrix.

---

## Creating Command

- **First contract** (`contract-001.md`): created by `/cortex-spec`
- **Repair contracts** (`contract-002.md` and above): created by `/cortex-investigate` when investigation determines a repair loop is needed

```bash
/cortex-spec           # creates contract-001.md
/cortex-investigate    # may create contract-NNN.md for repair
```

---

## Notes

- Contracts are append-only during execution — do not edit a contract after it is approved
- The `write_roots` field is the source of truth for `/cortex-review` and the `cortex-phase-guard` hook (Phase 4)
- See `docs/COMMANDS.md` for the full `/cortex-spec` and `/cortex-investigate` references
- See `docs/EVALS.md` for eval plan requirements
