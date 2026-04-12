# Spec: kalshi-calibration-harness

**Slug:** kalshi-calibration-harness
**Timestamp:** 20260407T040000Z
**Status:** draft
**Target repo:** cortex-kalshi (fork of cortex, separate branch/repo)

---

## 1. Problem

Cortex has no empirical feedback loop. The reasoning pipeline (clarify-research-spec-review) produces outputs whose quality is judged subjectively or via proxy metrics. There is no ground-truth signal that says "this analysis was wrong" in a way that traces back to which pipeline phase failed and why.

Prediction markets provide unambiguous, timestamped, binary resolution outcomes. By running the Cortex pipeline against Kalshi markets — forming independent probability estimates, comparing them to market prices, placing real-money bets, and conducting structured post-mortems on resolved outcomes — the system generates a calibration dataset that identifies systematic reasoning failures by pipeline phase.

The goal is not profit. The goal is 500+ resolved predictions with full provenance (reasoning artifacts, confidence levels, failure codes) that produce a reliable calibration curve and a failure-attribution distribution across pipeline phases. Profit is a trailing indicator of calibration quality.

---

## 2. Scope

### In Scope

- Fork setup: `cortex-kalshi` repo with bidirectional remotes to mainline Cortex
- Kalshi API integration: authentication (RSA-PSS), market discovery, order placement, position tracking, settlement verification via official Python SDK
- Price-blind research pipeline: research phase operates without seeing market prices to prevent LLM anchoring (documented 0.994 correlation)
- Probability calibration layer: converts qualitative research outputs into numerical probability estimates
- Edge computation: reveals market price post-research, computes spread, applies bet/pass threshold
- Bet record schema: JSONL format tracking full lifecycle from market selection through post-mortem
- Post-mortem engine: F1-F10 failure taxonomy with Army AAR template, "resulting" guard
- Monitoring phase: net-new Cortex phase for updating positions when new evidence arrives between bet placement and resolution
- Scoring: Brier score (primary), log loss (secondary), calibration curves (10-bin reliability diagrams)
- Batch analysis: after every 50 predictions, compute failure code distribution to identify weakest pipeline phase
- Human-AI hybrid mode: human review/adjustment of AI probability estimate before bet placement
- Weather market focus: daily resolution across 2-3 cities (NYC, Chicago) as Tier 1 instrument
- Dashboard/reporting: markdown-based calibration reports with running Brier score, calibration curve data, failure distribution

### Out of Scope

- High-frequency or algorithmic trading (latency-sensitive execution)
- Market-making or liquidity provision
- Automated bet execution in v1 (manual placement acceptable while pipeline calibrates)
- Position sizing optimization (flat stakes during calibration phase; fractional Kelly deferred to post-500 predictions)
- Tier 2/3 market categories (entertainment, economics) in first contract — added after calibration baseline
- Portfolio correlation management across simultaneous positions
- Custom Kalshi API wrapper (use official SDK)
- Mobile or web UI
- Merging back to mainline Cortex (long-lived fork; cherry-pick individual improvements)
- Fine-tuning or training models (pipeline-level improvements only)

---

## 3. Architecture Decisions

### AD-1: Price-blind research phase

**Chosen approach:** The research phase never sees market prices. Market price is revealed only at the "compare" stage after an independent probability estimate is locked.

**Rationale:** GPT-4.5 predictions correlate 0.994 with provided market forecasts (ForecastBench, ICLR 2025). Showing prices during research produces anchored estimates that track the market rather than independently assessing the question. The delta between the independent estimate and market price is the edge signal — if the system sees the price first, that signal is destroyed.

**Implementation:** Market ticker and question text are passed to the research phase. Market price, order book depth, and volume are stored separately and injected only at the compare stage. A code-level separation (not just prompt-level) enforces this — the research function signature does not accept price fields.

### AD-2: JSONL bet records (not SQLite, not markdown)

**Chosen approach:** Bet records stored as append-only JSONL in `data/bets/bets.jsonl`.

**Rationale:** Consistent with Cortex event log format. Append-only is crash-safe. JSONL is trivially parseable in Python, greppable from shell, and diffable in git. SQLite adds a binary blob to the repo. Markdown tables are fragile to parse and don't support programmatic queries.

**Schema:**
```json
{
  "bet_id": "uuid",
  "market_ticker": "KXHIGHNY-26APR07-T50",
  "market_question": "Will the high temperature in NYC exceed 50F on April 7?",
  "entry_timestamp": "2026-04-06T14:30:00Z",
  "research_artifact": "data/research/KXHIGHNY-26APR07-T50/research.md",
  "your_probability": 0.72,
  "market_price_at_entry": 0.65,
  "edge": 0.07,
  "position_side": "yes",
  "stake_cents": 500,
  "order_type": "limit",
  "fill_price": 0.66,
  "fill_timestamp": "2026-04-06T14:35:00Z",
  "resolution_outcome": "yes",
  "resolution_timestamp": "2026-04-08T00:00:00Z",
  "pnl_cents": 170,
  "brier_contribution": 0.0784,
  "log_loss_contribution": 0.3285,
  "failure_codes": [],
  "postmortem_path": "data/postmortems/KXHIGHNY-26APR07-T50/aar.md",
  "monitoring_updates": []
}
```

### AD-3: F1-F10 failure taxonomy

**Chosen approach:** Fixed 10-code taxonomy mapped to pipeline phases.

| Code | Name | Pipeline Phase |
|------|------|---------------|
| F1 | Framing Error | Clarify |
| F2 | Information Gap | Research |
| F3 | Source Quality | Research |
| F4 | Base Rate Neglect | Analysis |
| F5 | Weighting Error | Analysis |
| F6 | Model Error | Analysis |
| F7 | Update Failure | Monitoring |
| F8 | Calibration Error | Calibration |
| F9 | Challenge Failure | Critic |
| F10 | Outcome Variance | None (correct process, tail outcome) |

**Rationale:** Maps cleanly to Cortex pipeline phases, enabling targeted improvement. F10 (outcome variance) is critical — it prevents "resulting" (judging decisions by outcomes). The post-mortem must classify F10 before doing root cause analysis.

### AD-4: Monitoring as net-new pipeline phase

**Chosen approach:** Add a "monitoring" phase between bet placement and resolution that checks for new evidence and can trigger position updates.

**Rationale:** Cortex currently has no equivalent of "new evidence arrived, should I update my position?" Weather markets resolve daily, so the window is short, but for longer-duration markets this becomes essential. F7 (Update Failure) cannot be attributed without a monitoring mechanism.

**Implementation:** A monitoring check runs at a configurable interval (default: once between placement and resolution for daily markets). It receives the original research artifact and checks for material new information. If found, it produces an update recommendation (hold/close/reverse) with reasoning. The bet record's `monitoring_updates` array captures these.

### AD-5: Demo sandbox for integration testing only

**Chosen approach:** Use Kalshi demo environment for API integration testing (1-2 days max), then switch to real money.

**Rationale:** Paper trading defeats the core thesis. Real money produces genuine cognitive engagement and honest post-mortems. Even $5/trade generates authentic signal. The demo sandbox is for verifying API auth, order flow, and settlement parsing — not for pipeline calibration.

### AD-6: Flat stakes during calibration phase

**Chosen approach:** $5-10 per trade for the first 500 predictions. No position sizing optimization.

**Rationale:** The system does not know its edge yet — that is what the calibration phase discovers. Kelly criterion requires accurate edge estimation, which is circular when the whole point is learning edge. Flat stakes isolate signal quality from position sizing noise. Fractional Kelly introduced after 500 predictions when calibration curve is reliable.

**Budget:** $500-1000 total "tuition" for the calibration phase. Expected negative P&L during learning.

---

## 4. Interfaces

### External

- **Kalshi REST API** (`trading-api.kalshi.com`) — market discovery, order placement, position tracking, settlement. Auth: RSA-PSS with API key.
- **Kalshi Demo API** (`demo-trading-api.kalshi.com`) — integration testing only.
- **kalshi-python SDK** (`pip install kalshi-python`) — official Python client.
- **NWS/weather data** — public forecast data (api.weather.gov, GFS/ECMWF model outputs) for weather market research.
- **Claude API** (`api.anthropic.com`) — LLM reasoning for research, calibration, and post-mortem phases.

### Internal (new files/paths in cortex-kalshi)

- **`data/bets/bets.jsonl`** — append-only bet record log.
- **`data/research/{market_ticker}/research.md`** — price-blind research artifact per market.
- **`data/postmortems/{market_ticker}/aar.md`** — Army AAR post-mortem per resolved bet.
- **`data/calibration/scores.jsonl`** — running Brier/log loss scores and calibration curve data.
- **`data/calibration/failure_distribution.json`** — F1-F10 code counts, updated every 50 predictions.
- **`data/reports/calibration-report-{n}.md`** — periodic calibration reports (every 50 predictions).
- **`scripts/kalshi/pipeline.py`** — main pipeline orchestrator (research -> calibrate -> compare -> decide -> resolve -> postmortem).
- **`scripts/kalshi/kalshi_client.py`** — thin wrapper over kalshi-python for auth setup and common queries.
- **`scripts/kalshi/research.py`** — price-blind research phase. Function signature excludes price fields.
- **`scripts/kalshi/calibrate.py`** — probability estimation from research output.
- **`scripts/kalshi/compare.py`** — edge computation (reveal market price, compute spread).
- **`scripts/kalshi/monitor.py`** — monitoring phase for position updates.
- **`scripts/kalshi/postmortem.py`** — AAR generation with F1-F10 classification.
- **`scripts/kalshi/scoring.py`** — Brier score, log loss, calibration curve computation.
- **`scripts/kalshi/report.py`** — batch analysis and report generation.
- **`config/kalshi.yaml`** — configuration (API endpoints, cities, stake amount, monitoring interval).
- **`test/test_kalshi_*.py`** — test suite.

### Cortex integration points

- **SKILL.md files** — new/modified skills for prediction market workflow (research-market, calibrate, postmortem).
- **Pipeline phases** — reuses clarify/research/critic patterns from mainline Cortex; adds monitoring and calibration as new phases.

---

## 5. Dependencies

- **kalshi-python** — official Kalshi Python SDK. pip install.
- **anthropic** — Claude API for LLM reasoning (already in Cortex).
- **RSA key pair** — for Kalshi API auth. Generated once, stored outside repo.
- **Kalshi account** — KYC-verified, funded ($500-1000 initial deposit).
- **KALSHI_API_KEY** — environment variable for API key ID.
- **KALSHI_PRIVATE_KEY_PATH** — environment variable pointing to RSA private key file.
- **ANTHROPIC_API_KEY** — environment variable (already present).
- **Python 3.10+** — for type hints and match statements used in pipeline code.
- **PyYAML** — for config file parsing.

---

## 6. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| LLM anchors on market prices despite architectural separation | High | Code-level enforcement: research function signature excludes price fields. Integration test verifies price is absent from research prompt. |
| Kalshi API rate limits block pipeline | Low | 20 reads/sec is generous for 20-30 trades/week. Exponential backoff on 429s. |
| Kalshi API or SDK breaking changes | Medium | Pin SDK version. Wrap SDK calls in thin client layer (`kalshi_client.py`) for isolation. |
| KYC/regulatory issues block account setup | Medium | Apply early. Have backup plan (Polymarket for non-US-regulated markets, though less clean resolution). |
| Early P&L losses exceed budget | Medium | Hard stop at $1000 cumulative loss. Flat stakes cap per-trade exposure. Weekly P&L review. |
| Weather markets delisted or liquidity dries up | Low | Kalshi has 100+ weather markets/day across 17 cities. If a city is illiquid, switch cities. |
| Calibration data too domain-specific (weather) to generalize | Medium | Accepted for v1. Tier 2/3 categories added after baseline. The failure taxonomy (F1-F10) is domain-agnostic — process improvements transfer. |
| "Resulting" contaminates post-mortems | High | Post-mortem template forces F10 (outcome variance) classification gate before root cause analysis. Template includes explicit "Was this a process failure or an unlikely outcome?" question. |
| Fork diverges too far from mainline Cortex | Medium | Quarterly review of cherry-pick candidates. Keep Cortex-generic improvements (monitoring phase, calibration patterns) in cleanly separated commits. |
| Insufficient predictions per probability bucket | Medium | Track bucket fill rates. Deliberately seek markets where your estimate falls in under-represented buckets to accelerate calibration curve construction. |

---

## 7. Sequencing

This spec covers the full system. Implementation is broken into contracts that build incrementally.

### Phase 1: Foundation (Contract 001)
1. **Fork setup** — Create cortex-kalshi repo, configure remotes, establish branch strategy.
2. **Kalshi API integration** — Auth, market discovery, order book queries. Verify against demo sandbox.
3. **Bet record schema** — JSONL writer/reader with schema validation.
4. **Config system** — YAML config for API endpoints, cities, stakes, intervals.
5. **Tests** — API client tests (mocked), schema validation tests.

### Phase 2: Pipeline Core (Contract 002)
6. **Price-blind research phase** — Market question input, weather data retrieval, LLM research, probability estimate output. No price in function signature.
7. **Compare phase** — Reveal market price, compute edge, apply bet/pass threshold.
8. **Decision phase** — Generate order parameters (side, price, quantity).
9. **Pipeline orchestrator** — Chain phases together, persist artifacts at each stage.
10. **End-to-end dry run** — Run pipeline on a real weather market, verify all artifacts generated.

### Phase 3: Resolution and Post-Mortem (Contract 003)
11. **Settlement checker** — Poll resolved markets, match to bet records, compute P&L.
12. **Post-mortem engine** — AAR template, F1-F10 classification, "resulting" guard.
13. **Scoring engine** — Brier score, log loss, per-prediction and running aggregates.
14. **Calibration curve** — 10-bin reliability diagram computation from bet records.
15. **Batch analysis** — Every 50 predictions, compute failure distribution and calibration report.

### Phase 4: Monitoring and Hybrid Mode (Contract 004)
16. **Monitoring phase** — Evidence check between placement and resolution, update recommendations.
17. **Human-AI hybrid mode** — Present AI estimate for human review/adjustment before bet placement.
18. **Reporting dashboard** — Markdown reports with calibration curves, failure distributions, P&L summary.

---

## 8. Tasks

### Contract 001 (Foundation)
- [ ] Create cortex-kalshi fork with upstream remote to mainline cortex
- [ ] Implement `scripts/kalshi/kalshi_client.py` — RSA-PSS auth, market list, market detail, order placement, position query, settlement query
- [ ] Verify API auth against Kalshi demo sandbox
- [ ] Implement bet record JSONL schema with writer/reader/validator in `scripts/kalshi/records.py`
- [ ] Create `config/kalshi.yaml` with API endpoints, target cities, stake amount, edge threshold
- [ ] Write `test/test_kalshi_client.py` (mocked API responses)
- [ ] Write `test/test_kalshi_records.py` (schema validation, round-trip serialization)

### Contract 002 (Pipeline Core)
- [ ] Implement `scripts/kalshi/research.py` — price-blind research phase (weather data + LLM analysis)
- [ ] Implement `scripts/kalshi/calibrate.py` — convert research output to probability estimate
- [ ] Implement `scripts/kalshi/compare.py` — reveal price, compute edge, bet/pass decision
- [ ] Implement `scripts/kalshi/pipeline.py` — orchestrate research -> calibrate -> compare -> decide
- [ ] Write integration test: verify market price absent from research phase prompt
- [ ] End-to-end dry run on real weather market (demo sandbox)

### Contract 003 (Resolution and Post-Mortem)
- [ ] Implement settlement checker in `scripts/kalshi/resolve.py`
- [ ] Implement `scripts/kalshi/postmortem.py` — AAR template with F1-F10 taxonomy and resulting guard
- [ ] Implement `scripts/kalshi/scoring.py` — Brier score, log loss, calibration curve binning
- [ ] Implement batch analysis in `scripts/kalshi/report.py` — failure distribution every 50 predictions
- [ ] Write tests for scoring math (known-answer Brier/log loss computations)

### Contract 004 (Monitoring and Hybrid)
- [ ] Implement `scripts/kalshi/monitor.py` — evidence check, update recommendation
- [ ] Implement human-AI hybrid mode — present estimate, accept human override, log both
- [ ] Implement markdown reporting dashboard
- [ ] Write monitoring phase tests

---

## 9. Acceptance Criteria

### System-level (all contracts complete)
- [ ] Pipeline runs end-to-end: market selection -> price-blind research -> calibrate -> compare -> decide -> place bet -> resolve -> post-mortem
- [ ] Market price is provably absent from research phase (integration test passes)
- [ ] Bet records persist as valid JSONL with all schema fields populated
- [ ] Post-mortems use AAR format with F1-F10 classification and resulting guard
- [ ] Brier score and log loss computed correctly (verified against known-answer test cases)
- [ ] Calibration curve computed with 10-bin reliability diagram data
- [ ] Batch analysis report generated every 50 predictions with failure code distribution
- [ ] Monitoring phase detects new evidence and produces update recommendations
- [ ] Human-AI hybrid mode logs both AI and human estimates for calibration comparison
- [ ] All tests pass
- [ ] System operates against real Kalshi API with real money ($5-10/trade)

### Contract 001 (Foundation)
- [ ] Kalshi API auth succeeds against demo sandbox
- [ ] Market discovery returns weather markets for configured cities
- [ ] Bet record round-trips through JSONL write/read without data loss
- [ ] Config loads from YAML with sensible defaults
- [ ] All Contract 001 tests pass

### Calibration milestones (operational, not code)
- [ ] 50 predictions: rough directional Brier score computed
- [ ] 200 predictions: basic 5-bin calibration curve generated
- [ ] 500 predictions: reliable 10-bin calibration curve; failure distribution stabilized; decision point on fractional Kelly introduction
