# Contract: kalshi-adaptive-loop — execute

**ID:** kalshi-adaptive-loop-001
**Slug:** kalshi-adaptive-loop
**Phase:** execute
**Created:** 20260407T063000Z
**Status:** draft
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Build the adaptation infrastructure — statistical monitoring, batch analysis triggers, pipeline version tracking, surface expansion gating, and the weather domain module — so that the kalshi prediction pipeline can close the feedback loop and drive measurable improvements from post-mortem failure patterns.

---

## Deliverables

- `scripts/kalshi/stats.py` — statistical monitoring module
- `scripts/kalshi/adapt.py` — adaptation protocol module
- `scripts/kalshi/surfaces.py` — surface expansion module
- `scripts/kalshi/domains/__init__.py` — domain module interface
- `scripts/kalshi/domains/weather.py` — weather domain module
- `config/surfaces.yaml` — surface registry configuration
- `config/prompts/v001/research.txt` — initial research prompt template
- `config/prompts/v001/calibration.txt` — initial calibration prompt template
- `test/test_stats.py` — statistical monitoring tests
- `test/test_adapt.py` — adaptation protocol tests
- `test/test_surfaces.py` — surface expansion tests

---

## Scope

### In Scope

- CUSUM chart computation for tracking cumulative Brier score differences across pipeline versions
- mSPRT (mixture Sequential Probability Ratio Test) for continuous improvement detection with always-valid p-values
- Diebold-Mariano test for pairwise forecast accuracy comparison
- Calibration curve binning (5-bin for <200 predictions, 10-bin for 200+)
- Batch analysis trigger: automated analysis every 50 predictions
- F1-F10 failure code clustering to identify dominant failure phase per batch
- Structured adaptation proposal template with explicit hypothesis
- Adaptation log: JSONL append-only record of every pipeline modification
- Pipeline version tracking via `config/prompts/` directory with version tags
- Surface registry in YAML with readiness gates (50-prediction threshold)
- Dynamic domain module loader
- Weather domain module: NWS/GFS/ECMWF source pointers, temperature reference classes, few-shot examples
- Tests with known-answer cases and scipy cross-validation

### Out of Scope

- DSPy automated optimization (Contract 002)
- Non-weather domain modules — economics, crypto, finance, politics (Contract 003)
- The prediction pipeline itself (kalshi-calibration-harness contracts 002-004)
- Actually running predictions or placing bets
- Cross-surface calibration analysis (Contract 003)
- Position sizing or Kelly criterion

---

## Write Roots

- `scripts/kalshi/stats.py`
- `scripts/kalshi/adapt.py`
- `scripts/kalshi/surfaces.py`
- `scripts/kalshi/domains/__init__.py`
- `scripts/kalshi/domains/weather.py`
- `config/surfaces.yaml`
- `config/prompts/v001/research.txt`
- `config/prompts/v001/calibration.txt`
- `test/test_stats.py`
- `test/test_adapt.py`
- `test/test_surfaces.py`

---

## Done Criteria

- [ ] `stats.py` CUSUM computation matches known-answer test cases
- [ ] `stats.py` mSPRT produces correct boundary decisions on synthetic data
- [ ] `stats.py` Diebold-Mariano test agrees with scipy reference implementation
- [ ] `adapt.py` triggers batch analysis at prediction counts 50, 100, 150, etc.
- [ ] `adapt.py` clusters F1-F10 failure codes and identifies the dominant failure phase
- [ ] `adapt.py` produces structured adaptation proposals with explicit hypothesis
- [ ] Adaptation log round-trips through JSONL write/read without data loss
- [ ] `surfaces.py` readiness gate blocks expansion when prediction count < 50
- [ ] `surfaces.py` loads domain modules dynamically from registry
- [ ] Weather domain module provides retrieval source interface and reference class data
- [ ] Config loads `surfaces.yaml` with correct defaults
- [ ] All tests pass

---

## Validators

- [ ] [external] `python3 -c "from scripts.kalshi.stats import cusum, msprt, diebold_mariano, calibration_curve; print('import OK')"`
- [ ] [external] `python3 -c "from scripts.kalshi.adapt import BatchAnalyzer, AdaptationLog; print('import OK')"`
- [ ] [external] `python3 -c "from scripts.kalshi.surfaces import SurfaceRegistry; print('import OK')"`
- [ ] [external] `python3 -c "from scripts.kalshi.domains.weather import WeatherDomain; print('import OK')"`
- [ ] [external] `python3 -c "import yaml; c = yaml.safe_load(open('config/surfaces.yaml')); assert 'surfaces' in c; print('config OK')"`
- [ ] [external] `python3 -m pytest test/test_stats.py test/test_adapt.py test/test_surfaces.py -v`
- [ ] [judgment] Review that CUSUM and mSPRT implementations match the statistical definitions (not just passing tests)
- [ ] [judgment] Review that domain module interface is clean and extensible without modifying core code
- [ ] [judgment] Review that adaptation log schema captures all fields needed for post-hoc analysis

---

## Eval Plan

docs/cortex/evals/kalshi-adaptive-loop/eval-plan.md

---

## Approvals

- [ ] Contract approval
- [ ] Evals approval

---

## Completion Promise

<!-- CORTEX_PROMISE: kalshi-adaptive-loop-001 COMPLETE -->

---

## Failed Approaches

<!-- Initial contract -->

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Delete `scripts/kalshi/stats.py`
- Delete `scripts/kalshi/adapt.py`
- Delete `scripts/kalshi/surfaces.py`
- Delete `scripts/kalshi/domains/` directory
- Delete `config/surfaces.yaml`
- Delete `config/prompts/` directory
- Delete `test/test_stats.py`, `test/test_adapt.py`, `test/test_surfaces.py`

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
