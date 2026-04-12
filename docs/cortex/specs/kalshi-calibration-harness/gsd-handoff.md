# GSD Handoff: kalshi-calibration-harness

**Slug:** kalshi-calibration-harness
**Timestamp:** 20260407T040000Z
**Status:** ready
**Target repo:** cortex-kalshi (fork)

---

## Objective

Build a prediction market calibration harness on a Cortex fork that uses Kalshi weather market outcomes as ground-truth feedback to identify and fix systematic reasoning failures in the pipeline. The system runs price-blind research, forms independent probability estimates, places real-money bets, and conducts structured post-mortems with a 10-code failure taxonomy mapped to pipeline phases. Target: 500 resolved predictions producing a reliable calibration curve and failure-attribution distribution.

---

## Deliverables

- `cortex-kalshi` fork repo with bidirectional remotes to mainline cortex
- `scripts/kalshi/kalshi_client.py` — Kalshi API client (RSA-PSS auth, market queries, orders)
- `scripts/kalshi/pipeline.py` — orchestrator (research -> calibrate -> compare -> decide -> resolve -> postmortem)
- `scripts/kalshi/research.py` — price-blind research phase
- `scripts/kalshi/calibrate.py` — probability estimation
- `scripts/kalshi/compare.py` — edge computation
- `scripts/kalshi/monitor.py` — monitoring phase for position updates
- `scripts/kalshi/postmortem.py` — AAR post-mortem with F1-F10 taxonomy
- `scripts/kalshi/scoring.py` — Brier score, log loss, calibration curves
- `scripts/kalshi/records.py` — JSONL bet record writer/reader
- `scripts/kalshi/report.py` — batch analysis and calibration reports
- `config/kalshi.yaml` — configuration
- `test/test_kalshi_*.py` — test suite

---

## Requirements

- Kalshi account (KYC-verified, funded $500-1000)
- RSA key pair for API auth (stored outside repo)
- Environment variables: KALSHI_API_KEY, KALSHI_PRIVATE_KEY_PATH, ANTHROPIC_API_KEY
- Python 3.10+, kalshi-python SDK, PyYAML

---

## Tasks

### Contract 001 (Foundation)
- [ ] Create cortex-kalshi fork with upstream remote
- [ ] Implement Kalshi API client (auth, market discovery, orders, settlements)
- [ ] Verify API auth against demo sandbox
- [ ] Implement bet record JSONL schema with validation
- [ ] Create config system (YAML)
- [ ] Write tests (client mocked, records validation)

### Contract 002 (Pipeline Core)
- [ ] Implement price-blind research phase
- [ ] Implement calibration/probability estimation
- [ ] Implement edge computation (compare phase)
- [ ] Implement pipeline orchestrator
- [ ] Integration test: market price absent from research prompt
- [ ] End-to-end dry run on demo sandbox

### Contract 003 (Resolution and Post-Mortem)
- [ ] Settlement checker
- [ ] Post-mortem engine (AAR + F1-F10 + resulting guard)
- [ ] Scoring engine (Brier, log loss, calibration curves)
- [ ] Batch analysis and reporting

### Contract 004 (Monitoring and Hybrid)
- [ ] Monitoring phase (evidence check, update recommendations)
- [ ] Human-AI hybrid mode
- [ ] Markdown reporting dashboard

---

## Acceptance Criteria

- [ ] Pipeline runs end-to-end: research (price-blind) -> calibrate -> compare -> decide -> resolve -> post-mortem
- [ ] Market price provably absent from research phase
- [ ] Bet records persist as valid JSONL
- [ ] Post-mortems use AAR format with F1-F10 taxonomy
- [ ] Brier and log loss computed correctly (known-answer tests)
- [ ] Calibration curve computed (10-bin reliability diagram)
- [ ] Batch report generated every 50 predictions
- [ ] Monitoring phase produces update recommendations
- [ ] Human-AI hybrid logs both estimates
- [ ] All tests pass
- [ ] Operates against real Kalshi API with real money

---

## Key Constraints

- Price-blind research is architecturally enforced (function signature, not just prompt)
- Flat stakes ($5-10) during calibration phase — no Kelly until 500 predictions
- Weather markets only in v1 (Tier 2/3 deferred)
- Fork does not merge back to mainline — cherry-pick individual improvements
- Post-mortem must classify F10 (outcome variance) before root cause analysis

---

## Contract Link

docs/cortex/contracts/kalshi-calibration-harness/contract-001.md
