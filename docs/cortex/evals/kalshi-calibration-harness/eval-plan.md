# Eval Plan: kalshi-calibration-harness

**Slug:** kalshi-calibration-harness
**Timestamp:** 20260407T060100Z
**Approved By:** auto-approved (no approval_required dimensions)
**Approved At:** 20260407T060100Z

---

## Approved Dimensions

- Functional correctness
- Integration
- Safety/security
- Style

---

## Fixtures Per Dimension

### Fixtures: Functional Correctness
- Test suite: `test/test_kalshi_client.py` (13 tests) and `test/test_kalshi_records.py` (27 tests)
- Mocked kalshi-python SDK responses for market listing, order placement, position, settlement
- Sample bet records with valid and invalid field values
- YAML config files with full keys, partial keys, and empty files

### Fixtures: Integration
- Mock SDK configuration with demo base URL
- `KalshiClient.from_config_file()` round-trip: config loaded -> SDK initialized
- `BetRecord` -> `write_record()` -> `read_records()` -> identical `BetRecord`
- `config/kalshi.yaml` with known values -> `load_config()` -> merged defaults

### Fixtures: Safety/Security
- Full repo grep for PEM headers, API key patterns, credential strings
- `config/kalshi.yaml` content inspection
- `kalshi_client.py` constructor signature inspection
- `.gitignore` content check

### Fixtures: Style
- All Python files: `scripts/kalshi/*.py` and `test/test_kalshi_*.py`
- Config file: `config/kalshi.yaml`

---

## Thresholds Per Dimension

### Threshold: Functional Correctness
**Pass:** All 40 tests pass. All 4 external validators from contract succeed. All 10 done criteria met.
**Fail:** Any test failure, any external validator failure, or any done criterion unmet.

### Threshold: Integration
**Pass:** `from_config_file` round-trip works. Records round-trip preserves all 21 fields. No SDK types in public interface.
**Fail:** Any SDK type leaks through public API. Any data loss in round-trip serialization.

### Threshold: Safety/Security
**Pass:** Zero credential material in tracked files. Config contains no secrets. Private key path is runtime-only.
**Fail:** Any credential material found in tracked files. Any hardcoded key or secret.

### Threshold: Style
**Pass:** All public APIs documented. SDK isolation verified. Config commented. Tests organized by concern.
**Fail:** Public function without docstring. SDK type in public return signature.

---

## Run Instructions

1. Run import validators:
   ```bash
   python3 -c "from scripts.kalshi.kalshi_client import KalshiClient; print('import OK')"
   python3 -c "from scripts.kalshi.records import BetRecord, write_record, read_records; print('import OK')"
   ```

2. Run config validator:
   ```bash
   python3 -c "import yaml; c = yaml.safe_load(open('config/kalshi.yaml')); assert 'api' in c; print('config OK')"
   ```

3. Run full test suite:
   ```bash
   python3 -m pytest test/test_kalshi_client.py test/test_kalshi_records.py -v
   ```

4. Safety/security scan — grep for credential material:
   ```bash
   grep -rn "BEGIN.*PRIVATE KEY\|BEGIN.*RSA\|KALSHI_API_KEY.*=\|api_key.*=" scripts/kalshi/ config/kalshi.yaml --include="*.py" --include="*.yaml"
   ```
   Expected: no matches.

5. Check .gitignore covers key file patterns:
   ```bash
   grep -E "\\.pem|\\.key|private" .gitignore
   ```

6. Style review — verify public API docstrings:
   ```bash
   python3 -c "
   from scripts.kalshi.kalshi_client import KalshiClient, load_config
   from scripts.kalshi.records import BetRecord, write_record, read_records, validate_record
   for obj in [KalshiClient, load_config, BetRecord, write_record, read_records, validate_record]:
       assert obj.__doc__, f'{obj.__name__} missing docstring'
   print('all docstrings OK')
   "
   ```

7. Integration — verify no SDK types in public returns:
   ```bash
   grep -n "kalshi_python" scripts/kalshi/kalshi_client.py | grep -v "import\|Configuration\|KalshiClient\|MarketsApi\|PortfolioApi\|CreateOrderRequest"
   ```
   Expected: no matches (SDK types only used internally, never returned).

---

## Results

<!-- Results are written to a separate artifact: docs/cortex/evals/kalshi-calibration-harness/results-<timestamp>.md -->
<!-- All dimensions must show "passed" in the results artifact before the contract can advance to assure state. -->
