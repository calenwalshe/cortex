# docs/cortex/evals/

**Artifact type:** Eval proposals and plans — written by `/cortex-research --phase evals` and promoted after human approval

---

## Naming Pattern

```
docs/cortex/evals/<slug>/eval-proposal.md
docs/cortex/evals/<slug>/eval-plan.md
```

- `<slug>` matches the slug from the corresponding clarify brief
- `eval-proposal.md` is written first by `/cortex-research --phase evals`
- `eval-plan.md` is written only after the human has approved the proposal

**Example:**
```
docs/cortex/evals/smart-retry-logic/eval-proposal.md
docs/cortex/evals/smart-retry-logic/eval-plan.md
```

---

## Lifecycle

1. `/cortex-research --phase evals` produces `eval-proposal.md`
2. Human reviews and approves the proposal
3. `eval-plan.md` is written (by Cortex or the human) from the approved proposal
4. The eval plan path is recorded in the contract's `eval_plan` field
5. After execution, validators in the plan are run and results inform repair or assure decisions

The human approval gate between proposal and plan is mandatory. No automation bypasses it.

---

## Required Fields: eval-proposal.md

| Field | Description |
|-------|-------------|
| `dimensions` | Selected evaluation dimensions from the 8-candidate matrix (list with rationale for inclusion/exclusion of each) |
| `fixtures` | Test inputs, scenarios, or datasets needed to run each dimension |
| `rubrics` | Scoring criteria for each dimension — what constitutes pass/fail |
| `thresholds` | Numeric or qualitative pass thresholds per dimension |
| `failure_taxonomy` | Classification of failure types: what categories of failure are possible |
| `approval_required` | Boolean flag — always `true` for UX/taste dimension; true for any high-stakes or ambiguous dimension |

---

## Required Fields: eval-plan.md

| Field | Description |
|-------|-------------|
| `approved_dimensions` | The dimensions approved by the human (subset of proposal dimensions) |
| `fixtures_per_dimension` | Specific fixtures for each approved dimension |
| `thresholds_per_dimension` | Pass thresholds per approved dimension |
| `run_instructions` | Step-by-step instructions for running each dimension's evals |

---

## The 8-Dimension Candidate Matrix

Every eval proposal must address all 8 dimensions — either including them with justification or explicitly excluding them with explanation:

| # | Dimension | When typically included |
|---|-----------|------------------------|
| 1 | Functional correctness | Always |
| 2 | Regression | When modifying existing behavior |
| 3 | Integration | When multiple components interact |
| 4 | Safety / security | When handling user data, auth, or external inputs |
| 5 | Performance | When latency or throughput matters |
| 6 | Resilience | When failure modes and retries are relevant |
| 7 | Style | When output formatting or code quality matters |
| 8 | UX / taste | When human judgment of output quality is required — **always requires human approval gate** |

See `docs/EVALS.md` for the full dimension descriptions, fixtures guidance, and rubric examples.

---

## Creating Command

```bash
/cortex-research --phase evals
```

- Requires the clarify brief to exist
- Reads prior concept/implementation dossiers if available
- Produces `eval-proposal.md` — the human must approve before `eval-plan.md` is written

---

## Notes

- The UX/taste dimension (dimension 8) **always** requires a human approval gate, regardless of other settings
- A contract referencing an eval plan that doesn't exist yet should set `eval_plan` to the expected path with status `pending`
- See `docs/EVALS.md` for the complete eval artifact lifecycle
- See `docs/cortex/contracts/README.md` for how contracts reference eval plans
