# Last Compact Summary

<!-- Template: written by cortex-postcompact hook after each /compact run -->
<!-- Copy to docs/cortex/handoffs/last-compact-summary.md and fill in values -->
<!-- This file answers: what happened before the last /compact? -->

**slug:** {SLUG}
<!-- string — active slug at the time of compaction -->

**compact_timestamp:** {COMPACT_TIMESTAMP}
<!-- ISO 8601 timestamp of when /compact ran -->

**what_was_accomplished:** {WHAT_WAS_ACCOMPLISHED}
<!-- string — summary of all work done before this compaction; free text -->

**artifacts_written:**
<!-- list — paths of artifacts written during the session before compaction -->
{ARTIFACTS_WRITTEN}

**decisions_made:**
<!-- list — key decisions made during the session before compaction -->
{DECISIONS_MADE}

**open_items:**
<!-- list — carry-forward items that were not resolved before compaction -->
{OPEN_ITEMS}

**next_action:** {NEXT_ACTION}
<!-- string — single recommended next step after resuming -->
