---
phase: "22"
plan: "01"
subsystem: codex-handoff
tags: [template, schema, codex, capsule, execution-handoff]
dependency_graph:
  requires: [task-router]
  provides: [task-capsule-template, task-result-schema]
  affects: [codex-exec-wrapper, execute-plan]
tech_stack:
  added: [json-schema-2020-12]
  patterns: [context-capsule, structured-result]
key_files:
  created:
    - templates/cortex/task-capsule.md
    - schemas/task-result.schema.json
  modified: []
decisions:
  - "Capsule includes condensed deviation rules (not full GSD executor copy) — keeps template under 2KB"
  - "Schema uses conditional validation (if status=complete then commit_hash required) — catches malformed results early"
  - "Deviation pattern regex enforces [Rule N format in schema — structured parsing by executor"
  - "additionalProperties: false on schema — strict contract, no undocumented fields"
metrics:
  duration: "2min"
  completed: "2026-04-03"
  tasks: 2
  files: 2
---

# Phase 22 Plan 01: Context Capsule Template and Result Schema Summary

Context capsule template and JSON result schema for structured Codex execution handoff with 6 capsule sections and 8 schema properties including conditional validation.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create task-capsule.md template | d2a7c40 | templates/cortex/task-capsule.md |
| 2 | Create task-result.schema.json | b192e0a | schemas/task-result.schema.json |

## What Was Built

### task-capsule.md (130 lines)

Context capsule template with 6 sections that the task router populates per-task before piping to Codex:

1. **Identity** — phase, plan, task number, workspace path, project slug, branch
2. **Task Definition** — name, action, files, verify command, done criteria (extracted from PLAN.md XML)
3. **Deviation Rules** — condensed Rules 1-4 from GSD executor with scope boundary and fix attempt limit
4. **Commit Instructions** — message format, type selection table, staging rules
5. **File Context** — placeholder for existing file contents (200-line/12KB cap documented)
6. **Result Format** — JSON example conforming to task-result.schema.json with field rules

Uses `{PLACEHOLDER}` convention consistent with all other `templates/cortex/` files.

### task-result.schema.json (102 lines)

JSON Schema (draft 2020-12) defining the structured result Codex returns after task execution:

- `status`: enum `complete | failed | checkpoint`
- `files_changed`: string array of relative paths
- `tests_passed`: boolean (verify command exit code)
- `test_output_summary`: optional string
- `deviations`: string array with `[Rule N` pattern validation
- `commit_hash`: string (7-40 hex chars) or null, with regex pattern
- `error_message`: string or null
- `checkpoint_detail`: string or null

Conditional validation: when status is "complete", commit_hash must be a string (not null), and error_message/checkpoint_detail must be null. Three examples covering all three status values included.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — both files are complete templates/schemas with no placeholder data that flows to runtime.

## Decisions Made

1. **Condensed deviation rules** — capsule includes a compact version of Rules 1-4 rather than copying the full GSD executor text. Keeps template under 2KB while preserving all decision logic.
2. **Conditional schema validation** — `if/then` block enforces that "complete" status requires a commit_hash and null error/checkpoint fields. Catches malformed results before the executor processes them.
3. **Strict additionalProperties: false** — no undocumented fields allowed in results. Forces Codex to conform to the exact contract.
4. **Deviation pattern regex** — `^\\[Rule [1-4]` pattern in schema items validates that deviations follow the structured format, enabling automated parsing by the executor.

## Self-Check: PASSED

- FOUND: templates/cortex/task-capsule.md
- FOUND: schemas/task-result.schema.json
- FOUND: commit d2a7c40
- FOUND: commit b192e0a
