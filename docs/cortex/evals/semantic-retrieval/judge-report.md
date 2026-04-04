# Judge Report: semantic-retrieval

**Generated:** 20260404T074513Z
**Contract:** /home/agent/projects/cortex/docs/cortex/contracts/semantic-retrieval/contract-001.md
**Model:** claude-haiku-4-5-20251001
**Total cost:** $0.0016

---

## Results

### [1] PASS: Review that retrieval returns semantically relevant facts (not just random top-K) for a known query

- **Scores:** {"relevance": 2, "ranking": 1, "no_garbage": 1}
- **Total:** 4 / pass threshold
- **Pass:** True
- **Confidence:** 0.72
- **Status:** PASS
- **Reasoning:** Two of three results directly address 'budget' (repair budget, step-count budget) and one mentions 'hook', showing partial semantic relevance with weak ranking order and no obvious garbage, but results lack clear topical cohesion around 'hook performance' specifically.
- **Latency:** 1560ms | **Cost:** $0.0009

### [2] PASS: Review that graceful degradation produces a clear, actionable stderr warning

- **Scores:** {"warning_present": 1, "clarity": 1, "actionable": 0, "non_breaking": 1}
- **Total:** 3 / pass threshold
- **Pass:** True
- **Confidence:** 0.85
- **Status:** PASS
- **Reasoning:** Warning is present and explains the failure (ollama unreachable) with graceful degradation (returning unranked facts), but lacks actionable guidance on how to resolve the underlying issue.
- **Latency:** 1069ms | **Cost:** $0.0008

---

## Summary

- **PASS:** 2
- **FAIL:** 0
- **FLAG (needs human review):** 0
- **Total cost:** $0.0016
