# Eval Proposal: kalshi-adaptive-loop

**Slug:** kalshi-adaptive-loop
**Timestamp:** 20260407T064000Z
**Status:** draft

---

## Proposed Dimensions

### 1. Functional Correctness
**Applies because:** Always included. Contract has 12 done criteria covering statistical computation, batch triggers, failure clustering, adaptation log, surface gating, and domain modules.
**approval_required:** false

### 2. Regression
**Applies because:** EXCLUDED. Contract 001 is greenfield — all deliverables are net-new files.

### 3. Integration
**Applies because:** INCLUDED. stats.py consumes bet records from existing records.py. surfaces.py loads domain modules dynamically. adapt.py reads failure distribution data. Multiple modules interact.
**approval_required:** false

### 4. Safety/Security
**Applies because:** EXCLUDED. No auth, no secrets, no external API calls, no credential handling. This contract is pure computation and configuration.

### 5. Performance
**Applies because:** EXCLUDED. No performance thresholds specified. Statistical computations run on small datasets (<500 records).

### 6. Resilience
**Applies because:** EXCLUDED. No network calls, no external dependencies at runtime. Pure local computation.

### 7. Style
**Applies because:** INCLUDED. All code and config deliverables should follow consistent patterns with existing kalshi modules.
**approval_required:** false

### 8. UX/Taste
**Applies because:** EXCLUDED. No user-facing output or generated content in this contract. Batch reports and adaptation proposals are structured data, not prose.

---

## Fixtures

### Fixtures: Functional Correctness
- Test suite: `test/test_stats.py` (20 tests), `test/test_adapt.py` (15 tests), `test/test_surfaces.py` (14 tests)
- Known-answer CUSUM test cases
- Synthetic data for mSPRT boundary testing
- scipy reference for Diebold-Mariano cross-validation
- F1-F10 failure code samples for clustering

### Fixtures: Integration
- Round-trip: surface registry YAML → load → query → activate
- Domain module dynamic loading from registry
- Adaptation log JSONL write/read round-trip

### Fixtures: Style
- All Python files: `scripts/kalshi/stats.py`, `scripts/kalshi/adapt.py`, `scripts/kalshi/surfaces.py`, `scripts/kalshi/domains/*.py`
- Config: `config/surfaces.yaml`

---

## Rubrics

### Rubric: Functional Correctness
- All 49 tests pass with no skips
- All 6 external validators pass
- All 12 done criteria met

### Rubric: Integration
- Surface registry loads from YAML and dynamic module loading works
- Adaptation log round-trips through JSONL
- Domain module interface is implemented by WeatherDomain

### Rubric: Style
- Public functions and classes have docstrings
- Consistent naming with existing kalshi modules
- Config has inline comments

---

## Thresholds

### Threshold: Functional Correctness
**Pass:** All 49 tests pass. All 6 validators pass. All 12 done criteria met.
**Fail:** Any test failure, any validator failure, any done criterion unmet.

### Threshold: Integration
**Pass:** All round-trip tests pass. Dynamic loading works. Interface compliance verified.
**Fail:** Any integration failure.

### Threshold: Style
**Pass:** All public APIs documented. Consistent with existing module style.
**Fail:** Public function without docstring.

---

## Failure Taxonomy

| Failure Category | Severity | Description | Repair Path |
|-----------------|----------|-------------|-------------|
| Test failure | P0 | Any test fails | Fix code, re-run |
| Import failure | P0 | Module fails to import | Fix import chain |
| Statistical incorrectness | P1 | CUSUM/mSPRT/DM produces wrong results | Fix math, verify against reference |
| Schema mismatch | P1 | Adaptation log missing fields | Add fields |
| Gate logic error | P1 | Readiness gate allows/blocks incorrectly | Fix threshold logic |
| Missing docstring | P2 | Public function undocumented | Add docstring |

---

## Document-Level Approval Flag

**approval_required:** false

**Reviewer:** project lead

**Approval Status:** approved
