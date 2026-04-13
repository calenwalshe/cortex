# Eval Plan: kalshi-adaptive-loop

**Slug:** kalshi-adaptive-loop
**Timestamp:** 20260407T064000Z
**Approved By:** auto-approved (no approval_required dimensions)
**Approved At:** 20260407T064000Z

---

## Approved Dimensions

- Functional correctness
- Integration
- Style

---

## Fixtures Per Dimension

### Fixtures: Functional Correctness
- Test suite: `test/test_stats.py`, `test/test_adapt.py`, `test/test_surfaces.py` (49 tests total)
- Known-answer CUSUM and mSPRT test cases
- scipy cross-validation for Diebold-Mariano
- F1-F10 failure code clustering samples

### Fixtures: Integration
- Surface registry YAML → load → query → activate round-trip
- Adaptation log JSONL write/read round-trip
- Dynamic domain module loading

### Fixtures: Style
- All Python source files under `scripts/kalshi/`
- Config files under `config/`

---

## Thresholds Per Dimension

### Threshold: Functional Correctness
**Pass:** All 49 tests pass. All 6 external validators pass. All 12 done criteria met.
**Fail:** Any test failure, validator failure, or done criterion unmet.

### Threshold: Integration
**Pass:** All round-trip and integration tests pass. Dynamic module loading works.
**Fail:** Any integration failure.

### Threshold: Style
**Pass:** All public APIs documented. Consistent naming with existing modules.
**Fail:** Public function without docstring.

---

## Run Instructions

1. Run import validators:
   ```bash
   python3 -c "from scripts.kalshi.stats import cusum, msprt, diebold_mariano, calibration_curve; print('import OK')"
   python3 -c "from scripts.kalshi.adapt import BatchAnalyzer, AdaptationLog; print('import OK')"
   python3 -c "from scripts.kalshi.surfaces import SurfaceRegistry; print('import OK')"
   python3 -c "from scripts.kalshi.domains.weather import WeatherDomain; print('import OK')"
   ```

2. Run config validator:
   ```bash
   python3 -c "import yaml; c = yaml.safe_load(open('config/surfaces.yaml')); assert 'surfaces' in c; print('config OK')"
   ```

3. Run full test suite:
   ```bash
   python3 -m pytest test/test_stats.py test/test_adapt.py test/test_surfaces.py -v
   ```

4. Style check — verify docstrings:
   ```bash
   python3 -c "
   from scripts.kalshi.stats import cusum, msprt, diebold_mariano, calibration_curve
   from scripts.kalshi.adapt import BatchAnalyzer, AdaptationLog, AdaptationEntry
   from scripts.kalshi.surfaces import SurfaceRegistry
   from scripts.kalshi.domains.weather import WeatherDomain
   for obj in [cusum, msprt, diebold_mariano, calibration_curve, BatchAnalyzer, AdaptationLog, AdaptationEntry, SurfaceRegistry, WeatherDomain]:
       assert obj.__doc__, f'{obj.__name__} missing docstring'
   print('all docstrings OK')
   "
   ```

---

## Results

<!-- Results written to docs/cortex/evals/kalshi-adaptive-loop/results-<timestamp>.md -->
