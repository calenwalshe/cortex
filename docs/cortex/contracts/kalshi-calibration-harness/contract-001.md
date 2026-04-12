# Contract: kalshi-calibration-harness — foundation

**ID:** kalshi-calibration-harness-001
**Slug:** kalshi-calibration-harness
**Phase:** execute
**Created:** 20260407T040000Z
**Status:** closed
**Repair Budget:** max_repair_contracts: 3, cooldown_between_repairs: 1

---

## Objective

Set up the cortex-kalshi fork, implement Kalshi API integration (RSA-PSS auth, market discovery, order flow), build the bet record JSONL schema, and create the configuration system. This is the foundation layer — no pipeline logic, no LLM calls, just the plumbing that everything else builds on.

---

## Deliverables

- `cortex-kalshi` fork repo with upstream remote to mainline cortex
- `scripts/kalshi/kalshi_client.py` — Kalshi API client
- `scripts/kalshi/records.py` — JSONL bet record writer/reader/validator
- `config/kalshi.yaml` — configuration file
- `test/test_kalshi_client.py` — API client tests (mocked responses)
- `test/test_kalshi_records.py` — bet record schema tests

---

## Scope

### In Scope

- Fork creation with bidirectional remotes (upstream = cortex, origin = cortex-kalshi)
- Kalshi API client: RSA-PSS authentication, market listing with category filter (weather), market detail, order placement (limit orders), position query, settlement/result query
- Demo sandbox verification of auth flow
- Bet record JSONL schema: all fields from spec AD-2 (bet_id, market_ticker, market_question, entry_timestamp, research_artifact, your_probability, market_price_at_entry, edge, position_side, stake_cents, order_type, fill_price, fill_timestamp, resolution_outcome, resolution_timestamp, pnl_cents, brier_contribution, log_loss_contribution, failure_codes, postmortem_path, monitoring_updates)
- Record writer (append), reader (full load + filtered queries), validator (schema check)
- YAML config: API endpoints (prod/demo), target cities, default stake, edge threshold, monitoring interval
- Tests with mocked API responses (no real API calls in test suite)

### Out of Scope

- Research phase, calibration, compare phase (Contract 002)
- Post-mortem engine, scoring, reporting (Contract 003)
- Monitoring phase, hybrid mode (Contract 004)
- Real money trading (this contract verifies against demo sandbox only)
- LLM integration (no Claude calls in this contract)

---

## Write Roots

- `scripts/kalshi/kalshi_client.py`
- `scripts/kalshi/records.py`
- `scripts/kalshi/__init__.py`
- `config/kalshi.yaml`
- `test/test_kalshi_client.py`
- `test/test_kalshi_records.py`

---

## Done Criteria

- [ ] cortex-kalshi fork exists with upstream remote pointing to mainline cortex
- [ ] `kalshi_client.py` authenticates against Kalshi demo sandbox without error
- [ ] Market discovery returns weather markets for NYC and Chicago
- [ ] Order placement function constructs valid limit order payloads (verified against API schema)
- [ ] Settlement query parses resolved market outcomes correctly
- [ ] Bet record writes valid JSONL and reads back identically (round-trip)
- [ ] Bet record validator rejects records with missing required fields
- [ ] Bet record validator rejects records with out-of-range values (probability not in [0,1], negative stake)
- [ ] Config loads from YAML with sensible defaults when keys are omitted
- [ ] All tests pass

---

## Validators

- [ ] [external] `python3 -c "from scripts.kalshi.kalshi_client import KalshiClient; print('import OK')"` — client module imports
- [ ] [external] `python3 -c "from scripts.kalshi.records import BetRecord, write_record, read_records; print('import OK')"` — records module imports
- [ ] [external] `python3 -m pytest test/test_kalshi_client.py test/test_kalshi_records.py -v` — all tests pass
- [ ] [external] `python3 -c "import yaml; c = yaml.safe_load(open('config/kalshi.yaml')); assert 'api' in c; print('config OK')"` — config loads
- [ ] [judgment] Review that kalshi_client.py isolates SDK calls behind a clean interface (not leaking SDK types)
- [ ] [judgment] Review that bet record schema matches spec AD-2 exactly
- [ ] [judgment] Review that RSA-PSS auth setup does not store private key material in repo

---

## Eval Plan

docs/cortex/evals/kalshi-calibration-harness/eval-plan.md

---

## Approvals

- [ ] Contract approval
- [ ] Evals approval

---

## Completion Promise

<!-- CORTEX_PROMISE: kalshi-calibration-harness-001 COMPLETE -->

---

## Failed Approaches

<!-- Initial contract -->

---

## Why Previous Approach Failed

N/A — initial contract

---

## Rollback Hints

- Delete `scripts/kalshi/` directory
- Delete `config/kalshi.yaml`
- Delete `test/test_kalshi_client.py` and `test/test_kalshi_records.py`
- Fork repo can be deleted independently without affecting mainline cortex

---

## Repair Budget

**max_repair_contracts:** 3
**cooldown_between_repairs:** 1
