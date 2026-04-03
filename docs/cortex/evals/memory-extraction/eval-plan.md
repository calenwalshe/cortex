# Eval Plan: memory-extraction

**Slug:** memory-extraction
**Timestamp:** 20260403T230000Z
**Approved By:** auto-approved (full-auto, approval_required: false)
**Approved At:** 20260403T230000Z

---

## Approved Dimensions

- Functional Correctness
- Regression
- Integration
- Style

---

## Thresholds Per Dimension

### Threshold: Functional Correctness
**Pass:** 9/9 done criteria satisfied, 8/8 validators exit 0
**Fail:** Any done criterion unsatisfied or validator non-zero

### Threshold: Regression
**Pass:** last-compact-summary.md and next-prompt.md output identical in structure to pre-change behavior
**Fail:** Any existing output missing or structurally different

### Threshold: Integration
**Pass:** PreCompact enriched snapshot available when PostCompact runs; hook registration consistent across manifest and settings
**Fail:** PostCompact cannot find enriched snapshot, or hook not registered

### Threshold: Style
**Pass:** Node.js hook follows token-ledger.js conventions; bash changes follow existing precompact patterns
**Fail:** Inconsistent conventions

---

## Run Instructions

1. Run all 8 contract validators (grep/test commands from contract-001.md)
2. Simulate a compaction by running precompact then postcompact hooks manually with test data
3. Verify facts.jsonl contains valid JSON per line with required fields
4. Verify dedup by running postcompact twice — second run should not duplicate facts
5. Verify existing outputs (last-compact-summary.md, next-prompt.md) are still generated correctly
6. Check runtime-manifest.json and settings.json reference cortex-postcompact.js

---

## Results

- [ ] Functional Correctness —
- [ ] Regression —
- [ ] Integration —
- [ ] Style —
