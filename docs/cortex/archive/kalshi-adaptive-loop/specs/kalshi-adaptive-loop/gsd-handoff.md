# GSD Handoff: kalshi-adaptive-loop

**Slug:** kalshi-adaptive-loop
**Timestamp:** 20260407T063000Z
**Status:** draft

---

## Objective

Build the adaptation infrastructure that closes the feedback loop in the kalshi prediction pipeline — statistical monitoring (CUSUM, mSPRT), batch analysis triggers, pipeline version tracking, surface expansion gating, and the weather domain module — so that failure patterns from post-mortems drive measurable pipeline improvements over successive 50-prediction batches.

---

## Deliverables

- `scripts/kalshi/stats.py` — statistical monitoring: CUSUM, mSPRT, Diebold-Mariano, calibration curves
- `scripts/kalshi/adapt.py` — adaptation protocol: batch triggers, failure clustering, proposal templates, adaptation log
- `scripts/kalshi/surfaces.py` — surface expansion: domain registry, readiness gates, module loader
- `scripts/kalshi/domains/__init__.py` — domain module abstract interface
- `scripts/kalshi/domains/weather.py` — weather-specific retrieval and reference classes
- `config/surfaces.yaml` — surface registry configuration
- `config/prompts/v001/` — initial versioned prompt templates
- `test/test_stats.py` — statistical monitoring tests
- `test/test_adapt.py` — adaptation protocol tests
- `test/test_surfaces.py` — surface expansion tests

---

## Requirements

- None formalized

---

## Tasks

- [ ] Implement `scripts/kalshi/stats.py` — CUSUM chart computation, mSPRT with always-valid p-values, Diebold-Mariano forecast comparison test, calibration curve binning (5-bin for <200 predictions, 10-bin for 200+)
- [ ] Implement `scripts/kalshi/adapt.py` — batch analysis trigger every 50 predictions, F1-F10 failure code clustering to identify dominant failure phase, structured adaptation proposal with explicit hypothesis, adaptation log JSONL writer/reader
- [ ] Implement `scripts/kalshi/surfaces.py` — YAML-based surface registry, 50-prediction readiness gate, dynamic domain module loader
- [ ] Implement `scripts/kalshi/domains/__init__.py` — abstract base class defining domain module interface (get_retrieval_sources, get_reference_classes, get_fewshot_examples)
- [ ] Implement `scripts/kalshi/domains/weather.py` — NWS/GFS/ECMWF data source pointers, temperature reference classes for NYC/Chicago, weather-specific few-shot examples
- [ ] Create `config/surfaces.yaml` — weather (active, tier 1), economics (staged, tier 2), crypto (staged, tier 3), finance (staged, tier 4), politics (staged, tier 5)
- [ ] Create `config/prompts/v001/` — initial research prompt template, initial calibration prompt template
- [ ] Implement adaptation log schema: adaptation_id, batch_number, timestamp, trigger_pattern, hypothesis, modification_description, prompt_version_before, prompt_version_after, brier_before, brier_after
- [ ] Write `test/test_stats.py` — CUSUM known-answer tests, mSPRT boundary tests, Diebold-Mariano vs scipy
- [ ] Write `test/test_adapt.py` — batch trigger at 50/100/150, failure clustering, adaptation log round-trip
- [ ] Write `test/test_surfaces.py` — readiness gate blocks <50, allows >=50, module loading, registry CRUD

---

## Acceptance Criteria

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

## Contract Link

docs/cortex/contracts/kalshi-adaptive-loop/contract-001.md
