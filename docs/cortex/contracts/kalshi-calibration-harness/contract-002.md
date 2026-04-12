# Contract: kalshi-calibration-harness — pipeline-core

**ID:** kalshi-calibration-harness-002
**Slug:** kalshi-calibration-harness
**Phase:** execute
**Created:** 20260407T070000Z
**Status:** draft
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Build the prediction pipeline core — price-blind research, probability calibration, edge computation, and pipeline orchestrator — so that the system can take a weather market question, produce an independent probability estimate without seeing the market price, compare against the market, and output a bet/pass decision with full artifact trail.

---

## Deliverables

- `scripts/kalshi/research.py` — price-blind research phase
- `scripts/kalshi/calibrate.py` — probability estimation from research output
- `scripts/kalshi/compare.py` — edge computation (reveal price, compute spread)
- `scripts/kalshi/pipeline.py` — pipeline orchestrator
- `test/test_research.py` — research phase tests
- `test/test_calibrate.py` — calibration tests
- `test/test_compare.py` — compare phase tests
- `test/test_pipeline.py` — pipeline integration tests

---

## Scope

### In Scope

- Price-blind research function: accepts market question and ticker, retrieves weather data context, calls LLM for analysis, outputs research summary and raw probability. Function signature explicitly excludes price fields.
- Calibration function: takes raw probability and research summary, applies calibration checks (base rate anchoring, extremity, overconfidence), outputs adjusted probability.
- Compare function: takes calibrated probability and market price, computes edge (your_prob - market_price), applies edge threshold from config, outputs bet/pass decision with order parameters.
- Pipeline orchestrator: chains research → calibrate → compare → decide, persists artifacts at each stage to `data/research/{ticker}/` and `data/bets/bets.jsonl`.
- Integration test: verify market price is absent from research phase function signature and prompt.
- All LLM calls use the prompt templates from `config/prompts/v001/`.
- Tests use mocked LLM responses — no real API calls in test suite.

### Out of Scope

- Actual bet placement via Kalshi API (manual placement for now)
- Settlement checking, post-mortem, scoring (Contract 003)
- Monitoring phase (Contract 004)
- Real money operations (this contract tests against mocked data only)
- DSPy optimization (kalshi-adaptive-loop contract 002)

---

## Write Roots

- `scripts/kalshi/research.py`
- `scripts/kalshi/calibrate.py`
- `scripts/kalshi/compare.py`
- `scripts/kalshi/pipeline.py`
- `test/test_research.py`
- `test/test_calibrate.py`
- `test/test_compare.py`
- `test/test_pipeline.py`

---

## Done Criteria

- [ ] `research.py` function signature does not accept any price-related parameters
- [ ] `research.py` produces a research summary and raw probability from a market question
- [ ] `calibrate.py` adjusts raw probability using base rate anchoring and overconfidence checks
- [ ] `calibrate.py` flags extreme probabilities (>0.95 or <0.05) for justification
- [ ] `compare.py` computes edge as (calibrated_probability - market_price)
- [ ] `compare.py` returns bet decision when edge exceeds threshold, pass when below
- [ ] `compare.py` generates order parameters (side, stake, price) for bet decisions
- [ ] `pipeline.py` chains all phases and persists research artifact to data/research/{ticker}/
- [ ] `pipeline.py` writes bet record to bets.jsonl on bet decisions
- [ ] Integration test verifies market price is absent from research function inputs
- [ ] All tests pass

---

## Validators

- [ ] [external] `python3 -c "from scripts.kalshi.research import research_market; print('import OK')"`
- [ ] [external] `python3 -c "from scripts.kalshi.calibrate import calibrate_probability; print('import OK')"`
- [ ] [external] `python3 -c "from scripts.kalshi.compare import compute_edge, decide; print('import OK')"`
- [ ] [external] `python3 -c "from scripts.kalshi.pipeline import run_pipeline; print('import OK')"`
- [ ] [external] `python3 -m pytest test/test_research.py test/test_calibrate.py test/test_compare.py test/test_pipeline.py -v`
- [ ] [judgment] Review that research.py function signature excludes all price fields
- [ ] [judgment] Review that calibration logic matches spec AD-1 (price-blind separation)
- [ ] [judgment] Review that pipeline persists artifacts at each stage

---

## Eval Plan

docs/cortex/evals/kalshi-calibration-harness/eval-plan.md (pending)

---

## Approvals

- [ ] Contract approval
- [ ] Evals approval

---

## Completion Promise

<!-- CORTEX_PROMISE: kalshi-calibration-harness-002 COMPLETE -->

---

## Failed Approaches

<!-- Initial contract for this phase -->

---

## Why Previous Approach Failed

N/A — initial contract for pipeline core phase

---

## Rollback Hints

- Delete `scripts/kalshi/research.py`
- Delete `scripts/kalshi/calibrate.py`
- Delete `scripts/kalshi/compare.py`
- Delete `scripts/kalshi/pipeline.py`
- Delete `test/test_research.py`, `test/test_calibrate.py`, `test/test_compare.py`, `test/test_pipeline.py`

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
