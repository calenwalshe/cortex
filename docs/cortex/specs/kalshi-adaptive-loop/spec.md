# Spec: kalshi-adaptive-loop

**Slug:** kalshi-adaptive-loop
**Timestamp:** 20260407T063000Z
**Status:** draft

---

## 1. Problem

The kalshi-calibration-harness pipeline (contracts 001-004) produces predictions, scores them, and runs post-mortems — but it never changes its own behavior based on what it learns. The F1-F10 failure taxonomy identifies *which* pipeline phase failed, but nothing closes the loop by modifying research prompts, calibration heuristics, or market selection strategies. Without an adaptation mechanism, the system collects data about its failures but repeats them indefinitely. The system also operates on a single prediction surface (weather), limiting the diversity of calibration signal. This spec defines the closed-loop adaptation system that makes the pipeline self-improving and progressively expands to harder prediction domains.

---

## 2. Scope

### In Scope

- Adaptation log: structured record of every pipeline modification (what changed, why, triggering failure pattern, batch number, before/after metrics)
- Batch analysis triggers: automated analysis every 50 predictions computing failure code distribution, Brier score trend, and calibration curve shift
- Statistical monitoring: CUSUM charts for cumulative Brier score difference tracking, mSPRT for continuous improvement detection
- Pipeline version tracking: git-tagged snapshots of prompt templates and strategy configs, linked to batch boundaries
- Surface expansion config: YAML-based domain registry with readiness gates (50-prediction baseline per surface before expansion)
- Manual adaptation protocol: structured template for human-guided pipeline modifications during bootstrap phase (predictions 1-200)
- Adaptation effectiveness scoring: before/after comparison for each modification using Diebold-Mariano test
- Domain-specific retrieval module interface: pluggable knowledge sources per prediction surface (weather data sources, economic indicators, etc.)
- DSPy-style automated prompt optimization infrastructure for post-bootstrap phase (predictions 200+)

### Out of Scope

- The prediction pipeline itself (built by kalshi-calibration-harness contracts 002-004)
- Model fine-tuning or weight modification — adaptations happen at prompt/strategy level only
- Automated bet execution — manual placement continues
- Position sizing optimization (Kelly criterion) — deferred to post-500 predictions
- Building prediction pipelines for non-Kalshi platforms (Polymarket, Metaculus)
- Real-time adaptation (changes apply at batch boundaries, not per-prediction)

---

## 3. Architecture Decision

### AD-1: Two-phase adaptation — bootstrap then automate

**Chosen approach:** Manual adaptation from post-mortem analysis for predictions 1-200 (bootstrap phase), then DSPy MIPROv2 automated optimization for predictions 200+ (optimization phase).

**Rationale:** DSPy requires hundreds of labeled examples to optimize meaningfully. Before 200 resolved predictions, the dataset is too small for reliable automated optimization. Manual adaptation during bootstrap is faster to implement, produces interpretable changes, and builds the labeled dataset that automated optimization needs. The transition is a hard cutover at prediction 200.

### Alternatives Considered
- **Fully automated from day 1 (PromptBreeder):** Rejected — compute-heavy, unproven for forecasting, insufficient data at start.
- **Manual only, no automation:** Rejected — doesn't scale, human bottleneck, can't A/B test effectively.
- **Gradual blend (50% manual, 50% auto):** Rejected — adds complexity without benefit. Clean cutover is simpler.

### AD-2: Sequential comparison with CUSUM, not A/B testing

**Chosen approach:** Track cumulative Brier score difference (CUSUM charts) across pipeline versions. Use mSPRT for continuous monitoring with always-valid p-values. Reserve A/B testing for periodic spot-checks only.

**Rationale:** A/B testing requires 2x predictions per question (running old and new pipeline), which halves the effective sample size at $10/day. Sequential comparison uses full budget on the production pipeline. CUSUM charts detect drift points when improvement begins. mSPRT provides early stopping for large effects.

### Alternatives Considered
- **Full A/B testing:** Rejected — doubles cost per question, halves learning rate.
- **Fixed-batch comparison (every 50):** Rejected — loses temporal resolution. CUSUM is continuous.

### AD-3: Hybrid pipeline — universal core + domain modules

**Chosen approach:** One calibration/update pipeline core that works across all domains. Per-domain pluggable modules for retrieval sources, reference class databases, and domain-specific few-shot examples.

**Rationale:** Research shows calibration skills transfer almost perfectly across domains (~60% of forecasting skill is domain-general). Resolution accuracy depends on domain knowledge. The universal core captures transferable skills; domain modules capture non-transferable knowledge. Adding a new surface means writing one domain module, not forking the entire pipeline.

### Alternatives Considered
- **Fully universal (one pipeline, no domain modules):** Rejected — can't capture domain-specific reference classes or data sources.
- **Fully per-domain (separate pipeline per surface):** Rejected — N pipelines to maintain, cold-start on each, no skill transfer.

### AD-4: Surface expansion ladder with readiness gates

**Chosen approach:** Fixed expansion order: weather daily → econ monthlies → crypto daily → finance weekly → politics. Gate: 50-prediction baseline on current surface before expanding. Never abandon a surface — maintain parallel streams.

**Rationale:** Ordered by feedback speed × resolution clarity × market efficiency. Weather is fastest feedback, clearest resolution, least efficient. Politics is slowest, most ambiguous, hardest. 50-prediction gate ensures enough data to evaluate the domain module before moving on. Parallel streams prevent forgetting.

---

## 4. Interfaces

### External
- **Kalshi API** — read market categories, volumes, and available surfaces for expansion decisions
- **Claude API** — LLM reasoning for research prompts (the thing being optimized)
- **DSPy framework** — prompt optimization engine (post-bootstrap phase)

### Internal (new files in cortex-kalshi)
- **`data/adaptation/adaptation-log.jsonl`** — append-only log of every pipeline modification
- **`data/adaptation/cusum.jsonl`** — cumulative Brier score difference data per pipeline version
- **`data/adaptation/batch-reports/batch-{N}.md`** — analysis report generated every 50 predictions
- **`config/surfaces.yaml`** — domain registry: surface definitions, readiness state, domain module paths
- **`config/prompts/`** — versioned prompt templates (research, calibration, post-mortem)
- **`scripts/kalshi/adapt.py`** — adaptation protocol: batch trigger, failure analysis, modification proposal
- **`scripts/kalshi/stats.py`** — statistical monitoring: CUSUM, mSPRT, Diebold-Mariano, calibration curves
- **`scripts/kalshi/surfaces.py`** — surface expansion: readiness check, domain module registry, expansion gating
- **`scripts/kalshi/optimize.py`** — DSPy integration: MIPROv2 wrapper for prompt optimization (post-bootstrap)
- **`scripts/kalshi/domains/`** — per-domain retrieval modules (weather.py, economics.py, crypto.py, etc.)
- **`test/test_adapt.py`** — adaptation protocol tests
- **`test/test_stats.py`** — statistical monitoring tests
- **`test/test_surfaces.py`** — surface expansion tests

### Existing interfaces consumed
- **`data/bets/bets.jsonl`** — reads resolved bet records for batch analysis
- **`data/calibration/scores.jsonl`** — reads Brier/log loss scores
- **`data/calibration/failure_distribution.json`** — reads F1-F10 failure code counts
- **`scripts/kalshi/scoring.py`** — calls scoring functions for per-version Brier computation

---

## 5. Dependencies

- **kalshi-calibration-harness contracts 002-004** — the prediction pipeline this system adapts. Must be built first.
- **DSPy** (`pip install dspy-ai`) — prompt optimization framework. Used in post-bootstrap phase only.
- **scipy** (`pip install scipy`) — statistical tests (Diebold-Mariano, Wilcoxon signed-rank)
- **numpy** (`pip install numpy`) — CUSUM computation, calibration curve binning
- **scripts/kalshi/scoring.py** — existing scoring module from contract 001/003
- **scripts/kalshi/records.py** — existing bet record reader from contract 001
- **config/kalshi.yaml** — existing config (extended with surface expansion settings)

---

## 6. Risks

- **Insufficient data for detecting improvement at $10/day** — Mitigation: mSPRT enables early detection of large effects. CUSUM catches drift. Accept that subtle improvements (Brier Δ < 0.03) won't be detectable until ~200 predictions.
- **Overfitting adaptations to weather-specific patterns** — Mitigation: universal pipeline core ensures calibration skills transfer. Domain modules isolate weather-specific knowledge. Monitor cross-surface Brier when multiple surfaces active.
- **DSPy optimization compute costs exceed budget** — Mitigation: run optimization monthly, not per-batch. Cap at $15/run. If too expensive, continue manual adaptation.
- **Calibration improvement plateaus** — Mitigation: build graduation criterion. When Brier improvement < 0.005 over 3 consecutive batches, shift focus from calibration to resolution (domain knowledge depth) or expand to harder surfaces.
- **Pipeline modifications break existing performance** — Mitigation: every adaptation is a git commit with rollback hints. CUSUM detects regressions within 20-30 predictions. Auto-rollback if Brier degrades by >0.03 from previous version.
- **Bootstrap manual adaptation is subjective** — Mitigation: structured adaptation template forces explicit hypotheses ("I believe changing X will fix F{N} failures because Y"). Post-hoc verification required.

---

## 7. Sequencing

### Phase 1: Adaptation Infrastructure (Contract 001)
1. Build statistical monitoring module (`stats.py`): CUSUM, mSPRT, Diebold-Mariano, calibration curve computation
2. Build adaptation protocol (`adapt.py`): batch trigger, failure pattern analysis, modification proposal template, adaptation log
3. Build surface expansion system (`surfaces.py`): domain registry, readiness gating, domain module interface
4. Build weather domain module (`domains/weather.py`): retrieval sources, reference classes, domain-specific few-shot examples
5. Create prompt versioning system: `config/prompts/` with version-tagged templates
6. Tests for all modules

### Phase 2: Automated Optimization (Contract 002)
7. DSPy integration (`optimize.py`): MIPROv2 wrapper, Brier score metric function, backtesting harness
8. Automated adaptation pipeline: trigger optimization at batch boundaries, propose prompt changes, run backtests, commit if improved
9. A/B spot-check infrastructure for periodic validation

### Phase 3: Surface Expansion Execution (Contract 003)
10. Economics domain module (`domains/economics.py`): CPI/NFP/Fed data sources, rate model reference classes
11. Crypto domain module (`domains/crypto.py`): price feeds, round-number threshold patterns
12. Cross-surface analysis: compare calibration across active surfaces, detect transfer effects

---

## 8. Tasks

### Contract 001 (Adaptation Infrastructure)
- [ ] Implement `scripts/kalshi/stats.py` — CUSUM chart computation, mSPRT, Diebold-Mariano test, calibration curve binning
- [ ] Implement `scripts/kalshi/adapt.py` — batch analysis trigger (every 50 predictions), failure pattern clustering, adaptation proposal template, adaptation log writer/reader
- [ ] Implement `scripts/kalshi/surfaces.py` — surface registry, readiness gate (50-prediction check), domain module loader
- [ ] Implement `scripts/kalshi/domains/__init__.py` — domain module interface (abstract base)
- [ ] Implement `scripts/kalshi/domains/weather.py` — weather-specific retrieval sources and reference classes
- [ ] Create `config/surfaces.yaml` — initial surface registry (weather active, econ/crypto/finance/politics staged)
- [ ] Create `config/prompts/v001/` — initial versioned prompt templates for research and calibration phases
- [ ] Implement adaptation log schema and writer (`data/adaptation/adaptation-log.jsonl`)
- [ ] Write `test/test_stats.py` — CUSUM known-answer tests, mSPRT boundary tests, Diebold-Mariano against scipy reference
- [ ] Write `test/test_adapt.py` — batch trigger logic, failure pattern clustering, adaptation log round-trip
- [ ] Write `test/test_surfaces.py` — readiness gate logic, domain module loading, surface registry CRUD

### Contract 002 (Automated Optimization)
- [ ] Implement `scripts/kalshi/optimize.py` — DSPy MIPROv2 integration
- [ ] Build backtesting harness for prompt variant evaluation
- [ ] Implement automated adaptation pipeline with commit-on-improve

### Contract 003 (Surface Expansion)
- [ ] Implement economics domain module
- [ ] Implement crypto domain module
- [ ] Build cross-surface calibration analysis

---

## 9. Acceptance Criteria

### System-level (all contracts complete)
- [ ] Batch analysis runs automatically every 50 predictions, producing a structured report with failure distribution and Brier trend
- [ ] CUSUM chart correctly detects pipeline version boundaries and improvement/regression trends
- [ ] mSPRT produces always-valid p-values for ongoing calibration monitoring
- [ ] Every pipeline modification is logged with: what changed, why, triggering failure pattern, batch number
- [ ] Prompt templates are version-tracked in `config/prompts/` with git tags at batch boundaries
- [ ] Surface expansion is gated: new surface only activates after 50 predictions on current surface
- [ ] Domain modules are pluggable: adding a new surface requires only a new module in `scripts/kalshi/domains/`
- [ ] DSPy optimization runs post-200 predictions, proposing prompt changes that measurably improve Brier score
- [ ] Auto-rollback triggers if Brier degrades by >0.03 from previous pipeline version

### Contract 001 (Adaptation Infrastructure)
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
