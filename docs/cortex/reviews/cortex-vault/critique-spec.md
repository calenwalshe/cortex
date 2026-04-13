# Critique: spec — cortex-vault

**Gate:** spec
**Slug:** cortex-vault
**Timestamp:** 2026-04-13T14:30:00Z
**Artifact:** docs/cortex/specs/cortex-vault/spec.md
**Engine:** codex
**Overall Severity:** STOP

---

## Summary

This spec is not executable as written because core acceptance criteria use undefined notions of correctness instead of measurable inputs and outputs. It also leaves a known integration failure with an ambiguous mitigation, which invites inconsistent implementations and wasted validation effort.

---

## Findings (3 total — STOP: 2, CAUTION: 1, GO: 0)

### [STOP] ac_testability

**Finding:** The spec demands 'correct' artifact-type detection but never defines the actual path patterns or a truth table for ambiguous paths. That makes the acceptance criterion impossible to verify mechanically because there is no objective mapping from input path to expected artifact type.

**Quote from artifact:**
> - [ ] Extractor correctly identifies artifact type from path pattern (clarify brief, research dossier, spec)

**Impact:** Implementers will guess the routing logic, tests will be arbitrary, and different contributors can ship incompatible detectors while still claiming the criterion passed.

---

### [STOP] ac_testability

**Finding:** The write-path criterion requires 'correct fields' for `valid_from`, `confidence`, and `importance` but never specifies how those values are derived, what valid ranges are, or what each artifact section should map to. 'Correct' is undefined, so the criterion cannot be objectively tested.

**Quote from artifact:**
> - [ ] Extractor calls `add_fact()` for each extracted typed fact with correct fields: `content`, `topic`, `memory_type`, `project_scope="cortex"`, `session_id="cortex-{slug}"`, `valid_from`, `confidence`, `importance`

**Impact:** The extractor can emit arbitrary metadata, downstream retrieval quality will drift, and reviewers will have no deterministic basis for rejecting bad mappings.

---

### [CAUTION] risk_completeness

**Finding:** The mitigation for import failures is non-decisive and partially hand-wavy. It offers mutually exclusive options instead of one required fallback path, and one of those options is merely logging the failure rather than preventing the write-path from breaking functionally.

**Quote from artifact:**
> - **`fact_store.py` import fails from cortex repo** — The vault scripts may have relative imports that fail when `sys.path.insert` is used from a different working directory. Mitigation: use `subprocess.run(["python3", "~/memory/vault/scripts/fact_store_cli.py", ...])` as fallback if direct import fails; or test import at extractor startup and log clearly.

**Impact:** The implementation will ship without a single enforced recovery path, so a predictable integration failure can devolve into silent data loss or inconsistent behavior across environments.

---
