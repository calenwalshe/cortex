# Eval Proposal: kalshi-calibration-harness

**Slug:** kalshi-calibration-harness
**Timestamp:** 20260407T060000Z
**Status:** draft

---

## Proposed Dimensions

### 1. Functional Correctness
**Applies because:** Always included. Contract 001 has 10 done criteria covering API client, records, config, and validation logic.
**approval_required:** false

### 2. Regression
**Applies because:** EXCLUDED. Contract 001 is greenfield — no existing code is modified. All deliverables are net-new files under `scripts/kalshi/`, `config/`, and `test/`.

### 3. Integration
**Applies because:** INCLUDED. The API client integrates with the kalshi-python SDK and Kalshi's REST API. The records module integrates with the config system for `bets_path`. The client's `from_config_file` constructor chains config loading with SDK initialization.
**approval_required:** false

### 4. Safety/Security
**Applies because:** INCLUDED. RSA-PSS private key handling is a secrets management concern. The client accepts `private_key_path` and `api_key_id` as runtime parameters — these must never be stored in the repo. Config file must not contain credentials. The system handles real money via a CFTC-regulated exchange.
**approval_required:** false

### 5. Performance
**Applies because:** EXCLUDED. Contract 001 specifies no latency, throughput, or resource usage thresholds. The API client is a thin wrapper — performance is bounded by network I/O to Kalshi's API, not by this code.

### 6. Resilience
**Applies because:** EXCLUDED. Contract 001 scope is foundation-layer plumbing (client, records, config). No retry logic, no network failure handling, no external dependency recovery paths are specified in this contract. These concerns belong to Contract 002+ when the pipeline orchestrator is built.

### 7. Style
**Applies because:** INCLUDED. All code and config deliverables should follow consistent conventions — clean interface isolation (SDK types behind dicts), proper docstrings on public API, YAML config readability.
**approval_required:** false

### 8. UX/Taste
**Applies because:** EXCLUDED. Contract 001 has no user-facing output or generated content. All deliverables are programmatic interfaces (Python modules, YAML config, JSONL schema). UX/taste becomes relevant in Contract 003 (post-mortem reports) and Contract 004 (dashboard/reporting).

---

## Fixtures

### Fixtures: Functional Correctness
- Existing test suite: `test/test_kalshi_client.py` (13 tests) and `test/test_kalshi_records.py` (27 tests)
- Mocked kalshi-python SDK responses for market listing, order placement, position, settlement
- Sample bet records with valid and invalid field values (out-of-range probabilities, negative stakes, missing required fields)
- YAML config files with full keys, partial keys (defaults tested), and empty files

### Fixtures: Integration
- Mock SDK configuration with demo base URL
- Round-trip test: `KalshiClient.from_config_file()` -> config loaded -> SDK initialized
- Round-trip test: `BetRecord` -> `write_record()` -> `read_records()` -> identical `BetRecord`
- Config file at `config/kalshi.yaml` with known values -> `load_config()` -> merged defaults

### Fixtures: Safety/Security
- Grep scan of entire repo for private key material patterns (PEM headers, key IDs)
- Verify `config/kalshi.yaml` contains no credential fields
- Verify `kalshi_client.py` constructor requires runtime `api_key_id` and `private_key_path` args (not defaults, not env vars read at module level)
- Check `.gitignore` for key file patterns

### Fixtures: Style
- All Python files under `scripts/kalshi/` and `test/test_kalshi_*.py`
- `config/kalshi.yaml`

---

## Rubrics

### Rubric: Functional Correctness
- All 40 tests pass with no skips or xfails
- Import validators succeed for both modules
- Config loads and contains expected top-level keys
- Contract done criteria 1-10 are verifiable via test output and manual check

### Rubric: Integration
- `KalshiClient` constructor accepts config dict + credentials, produces a working client object
- SDK types never leak through the public interface — all return types are `dict` or `list[dict]`
- `from_config_file` loads YAML, merges defaults, and initializes SDK in a single call
- Records write/read round-trip preserves all 21 schema fields exactly

### Rubric: Safety/Security
- No private key material (PEM content, API keys) anywhere in the repo
- `config/kalshi.yaml` contains only configuration, no secrets
- Constructor signature requires credentials as explicit arguments — no hardcoded defaults
- `.gitignore` includes patterns for `*.pem`, `*.key`, and common credential filenames

### Rubric: Style
- Public functions and classes have docstrings
- SDK isolation is clean — no `kalshi_python` types in public return signatures
- Config has inline comments explaining each field
- Test organization uses descriptive class names grouping related tests

---

## Thresholds

### Threshold: Functional Correctness
**Pass:** All 40 tests pass. All 4 external validators from contract succeed. All 10 done criteria met.
**Fail:** Any test failure, any external validator failure, or any done criterion unmet.

### Threshold: Integration
**Pass:** `from_config_file` round-trip works. Records round-trip preserves all fields. No SDK types in public interface (verified by inspection).
**Fail:** Any SDK type leaks through public API. Any data loss in round-trip serialization.

### Threshold: Safety/Security
**Pass:** Zero credential material found in repo. Config contains no secrets. Private key path is runtime-only. `.gitignore` covers key patterns.
**Fail:** Any credential material found in tracked files. Any hardcoded key or secret in source.

### Threshold: Style
**Pass:** All public APIs documented. SDK isolation verified. Config commented. Tests organized by concern.
**Fail:** Public function without docstring. SDK type in public return signature.

---

## Failure Taxonomy

| Failure Category | Severity | Description | Repair Path |
|-----------------|----------|-------------|-------------|
| Test failure | P0 | Any test in the suite fails | Fix the failing code, re-run tests |
| Import failure | P0 | Module fails to import cleanly | Fix import chain, verify dependencies |
| Credential leak | P0 | Private key or API key found in repo | Remove immediately, rotate key, add to .gitignore |
| Schema mismatch | P1 | Bet record schema doesn't match spec AD-2 | Add/fix fields to match spec exactly |
| SDK type leak | P1 | kalshi_python types returned through public interface | Add conversion in client methods |
| Config load failure | P1 | Config doesn't load or defaults don't merge | Fix load_config/deep_merge logic |
| Missing docstring | P2 | Public function lacks documentation | Add docstring |
| Test coverage gap | P2 | Done criterion not covered by any test | Add targeted test |
| Inconsistent naming | P3 | Style inconsistency across modules | Rename for consistency |

---

## Document-Level Approval Flag

**approval_required:** false

**Reviewer:** project lead

**Approval Status:** approved
