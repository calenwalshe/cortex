# Eval Status: {SLUG}

<!-- Template for composite quality scoring across eval dimensions -->
<!-- Written by /cortex-review after eval plan execution -->
<!-- Each dimension gets a 0-1 score. Composite is a weighted average. -->

**Slug:** {SLUG}
**Timestamp:** {TIMESTAMP}
**Contract:** {CONTRACT_PATH}
**Eval Plan:** {EVAL_PLAN_PATH}

---

## Dimension Scores

| Dimension | Score | Weight | Weighted | Status | Notes |
|-----------|-------|--------|----------|--------|-------|
| Functional correctness | {0.0-1.0} | {weight} | {score*weight} | {PASS/FAIL} | {notes} |
| Regression | {0.0-1.0} | {weight} | {score*weight} | {PASS/FAIL} | {notes} |
| Integration | {0.0-1.0} | {weight} | {score*weight} | {PASS/FAIL} | {notes} |
| Safety/security | {0.0-1.0} | {weight} | {score*weight} | {PASS/FAIL} | {notes} |
| Performance | {0.0-1.0} | {weight} | {score*weight} | {PASS/FAIL} | {notes} |
| Resilience | {0.0-1.0} | {weight} | {score*weight} | {PASS/FAIL} | {notes} |
| Style | {0.0-1.0} | {weight} | {score*weight} | {PASS/FAIL} | {notes} |
| UX/taste | {0.0-1.0} | {weight} | {score*weight} | {PASS/FAIL} | {notes} |

<!-- Only include dimensions that are in the approved eval plan -->
<!-- Excluded dimensions should be removed from the table, not scored 0 -->
<!-- Weights must sum to 1.0 across included dimensions -->

---

## Composite Score

**Composite:** {0.0-1.0} (weighted average of included dimensions)

<!-- Interpretation:
     1.0:       Perfect — all dimensions at maximum
     0.8-0.99:  Strong — minor gaps in non-critical dimensions
     0.6-0.79:  Acceptable — passes but has notable gaps
     0.4-0.59:  Weak — significant gaps, repair likely needed
     < 0.4:     Failing — major issues across multiple dimensions
-->

---

## Dimension Details

<!-- For each scored dimension, provide specifics: -->
<!-- ### {Dimension Name} -->
<!-- **Score:** {0.0-1.0} -->
<!-- **Evidence:** {what was checked and what was found} -->
<!-- **Gaps:** {any issues found, or "None"} -->
