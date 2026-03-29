# Eval Status

<!-- Template: current eval pass/fail state for the active contract -->
<!-- Copy to docs/cortex/handoffs/eval-status.md and fill in values -->
<!-- Updated after each validation run during repair/assure loops -->

**slug:** {SLUG}
<!-- string — current active slug -->

**timestamp_updated:** {TIMESTAMP_UPDATED}
<!-- ISO 8601 timestamp of last eval run -->

**contract_path:** {CONTRACT_PATH}
<!-- string — relative path to the contract this eval status tracks -->

## Eval Dimensions

<!-- Each entry: one eval dimension with its current result -->

- **dimension:** {DIMENSION}
  <!-- string — name of the eval dimension, e.g., correctness, security, performance -->
  **status:** {STATUS}
  <!-- enum — passing | failing | not-run -->
  **last_run:** {LAST_RUN}
  <!-- ISO 8601 timestamp of when this dimension was last evaluated -->
  **threshold:** {THRESHOLD}
  <!-- string — pass/fail criterion for this dimension -->
  **result:** {RESULT}
  <!-- string — notes on the last result: what passed, what failed, specific errors -->
