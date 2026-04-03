# Milestones

## v1.4 adaptive-autonomy (Shipped: 2026-04-02)

**Phases completed:** 16 phases, 34 plans, 66 tasks

**Key accomplishments:**

- CORTEX.md rewritten with 4-layer architecture and 7-command surface; docs/INTELLIGENCE_FLOW.md created with ASCII spine, gate conditions, repair loop back to validate, and GSD handoff boundary
- 7-command operator reference and compaction-proof continuity strategy written with vNext flag conventions, field-level schemas, and explicit Phase 4 forward-looking callouts
- docs/EVALS.md and docs/AGENTS.md created as Phase 5/4 architectural specs; README.md rewritten with lifecycle intelligence framing, 7-command surface, and updated source tree replacing stale harmonisation wrapper content
- 9 docs/cortex/ subdirectory READMEs establishing naming patterns, required fields, and creating commands for all Cortex artifact types
- 7 Markdown artifact schema templates in `templates/cortex/` covering the full Cortex artifact lifecycle from clarify brief through eval plan, with `{FIELD_NAME}` placeholder convention and inline field documentation.
- 6 continuity templates with CONTINUITY.md-matched schema, 6 seeded handoff files, and .cortex/ machine state directory with state.json seeded to null/clarify/all-gates-false
- Idempotent `scripts/cortex/scaffold_runtime.sh` that creates the full docs/cortex/ + .cortex/ substrate in any target project, seeding 6 continuity files from templates and writing state.json with null slug, clarify mode, all gates false
- cortex-clarify SKILL.md (net-new, 5-phase problem framing) and cortex-research SKILL.md (vNext interface with --phase/--depth flags, docs/cortex/ output routing, and --phase evals branch)
- cortex-spec skill (net-new) converts clarify brief + research dossiers into spec.md, gsd-handoff.md, and contract-001.md; cortex-status skill (full replacement) reconstructs continuity context from repo-local artifacts without reading chat history or .planning/
- All three post-execution skills (investigate, review, audit) extended with repo-local artifact writing, slug resolution, and state update — existing protocols 100% preserved.
- Four Cortex sub-agent definitions with mechanical write-path enforcement via shared PreToolUse guard hook
- Four bash hooks registered in .claude/settings.json deliver automated continuity: session-start injects current-state.md as additionalContext, Stop writes updated state after each turn (async), PreCompact snapshots to .cortex/compaction/, PostCompact refreshes last-compact-summary.md and next-prompt.md.
- Five enforcement hooks wired into .claude/settings.json: phase-guard (PreToolUse deny), validator-trigger (PostToolUse dirty-file tracking), task-created/completed (lifecycle blocking), and teammate-idle (agent worker feedback)
- cortex-research --phase evals now enumerates all 8 eval dimensions with INCLUDE/EXCLUDE decisions, and Phase 3b blocks eval-plan.md writes until Approval Status is approved
- One-liner:
- MANIFEST-driven bin/install.js rewrite: 7 skills, 4 agents, 11 hooks symlinked idempotently, 9 settings events wired, --dry-run exits 0 without repo access
- dotfiles-setup.sh CWD-independent shell entry point + test/installer.test.sh with 7 assertions covering dry-run, symlinks, idempotency, settings dedup, and credential audit
- /cortex-stash skill delivering 6 subcommands with three-way context capture, 90-day staleness flagging, promote-to-clarify flow, and confirm-before-discard guard
- Authoritative design reference (DISCOVERY_LOOP.md) and two artifact templates (learning-contract, experiment-result) written — all DISC requirements satisfied, all validators passing
- Experiments write root wired: scaffold_runtime.sh, cortex-phase-guard.sh, and open-questions.md patched to enable the discovery loop's experiment mode
- reclarify_required backtrack write and three spec-readiness gate blockers added to cortex-research and cortex-spec SKILL.md files
- CORTEX.md promoted to 8-command surface; INTELLIGENCE_FLOW.md spine annotated with research→clarify backtrack and spec-readiness gate; COMMANDS.md gained full /cortex-experiment entry with open/run/close lifecycle
- Autonomy config template (3 presets, 13 named gates) and 4-layer resolver with mandatory gate enforcement — config substrate for gate-patching phases 14-16
- 1. [Rule 1 - Bug] Fixed ((PASS++)) false-exit under set -e
- /cortex-bridge SKILL.md generating all 6 GSD artifacts from Cortex spec/contract/gsd-handoff with verbatim done_criteria → ROADMAP success criteria mapping (AUTON-06) and autonomy flag sync to config.json
- Patched `drive-workflow.md` discuss action with Cortex-aware two-branch logic: Cortex-enriched CONTEXT.md when `skip_discuss_cortex` is true and artifacts exist, minimal "Claude's Discretion" fallback otherwise (AUTON-10 backward compatibility).
- Autonomy dry-run mode with per-gate source annotation plus AUTON-09 decision logging across all 5 gate-patched Cortex skills
- Autonomy posture display added to /cortex-status SKILL.md and 30-assertion integration test suite validates all Phase 16 deliverables (dry-run, source tracking, decision logging, status display)

---

## v1.4 adaptive-autonomy (Shipped: 2026-04-02)

**Phases completed:** 16 phases, 34 plans, 66 tasks

**Key accomplishments:**

- CORTEX.md rewritten with 4-layer architecture and 7-command surface; docs/INTELLIGENCE_FLOW.md created with ASCII spine, gate conditions, repair loop back to validate, and GSD handoff boundary
- 7-command operator reference and compaction-proof continuity strategy written with vNext flag conventions, field-level schemas, and explicit Phase 4 forward-looking callouts
- docs/EVALS.md and docs/AGENTS.md created as Phase 5/4 architectural specs; README.md rewritten with lifecycle intelligence framing, 7-command surface, and updated source tree replacing stale harmonisation wrapper content
- 9 docs/cortex/ subdirectory READMEs establishing naming patterns, required fields, and creating commands for all Cortex artifact types
- 7 Markdown artifact schema templates in `templates/cortex/` covering the full Cortex artifact lifecycle from clarify brief through eval plan, with `{FIELD_NAME}` placeholder convention and inline field documentation.
- 6 continuity templates with CONTINUITY.md-matched schema, 6 seeded handoff files, and .cortex/ machine state directory with state.json seeded to null/clarify/all-gates-false
- Idempotent `scripts/cortex/scaffold_runtime.sh` that creates the full docs/cortex/ + .cortex/ substrate in any target project, seeding 6 continuity files from templates and writing state.json with null slug, clarify mode, all gates false
- cortex-clarify SKILL.md (net-new, 5-phase problem framing) and cortex-research SKILL.md (vNext interface with --phase/--depth flags, docs/cortex/ output routing, and --phase evals branch)
- cortex-spec skill (net-new) converts clarify brief + research dossiers into spec.md, gsd-handoff.md, and contract-001.md; cortex-status skill (full replacement) reconstructs continuity context from repo-local artifacts without reading chat history or .planning/
- All three post-execution skills (investigate, review, audit) extended with repo-local artifact writing, slug resolution, and state update — existing protocols 100% preserved.
- Four Cortex sub-agent definitions with mechanical write-path enforcement via shared PreToolUse guard hook
- Four bash hooks registered in .claude/settings.json deliver automated continuity: session-start injects current-state.md as additionalContext, Stop writes updated state after each turn (async), PreCompact snapshots to .cortex/compaction/, PostCompact refreshes last-compact-summary.md and next-prompt.md.
- Five enforcement hooks wired into .claude/settings.json: phase-guard (PreToolUse deny), validator-trigger (PostToolUse dirty-file tracking), task-created/completed (lifecycle blocking), and teammate-idle (agent worker feedback)
- cortex-research --phase evals now enumerates all 8 eval dimensions with INCLUDE/EXCLUDE decisions, and Phase 3b blocks eval-plan.md writes until Approval Status is approved
- One-liner:
- MANIFEST-driven bin/install.js rewrite: 7 skills, 4 agents, 11 hooks symlinked idempotently, 9 settings events wired, --dry-run exits 0 without repo access
- dotfiles-setup.sh CWD-independent shell entry point + test/installer.test.sh with 7 assertions covering dry-run, symlinks, idempotency, settings dedup, and credential audit
- /cortex-stash skill delivering 6 subcommands with three-way context capture, 90-day staleness flagging, promote-to-clarify flow, and confirm-before-discard guard
- Authoritative design reference (DISCOVERY_LOOP.md) and two artifact templates (learning-contract, experiment-result) written — all DISC requirements satisfied, all validators passing
- Experiments write root wired: scaffold_runtime.sh, cortex-phase-guard.sh, and open-questions.md patched to enable the discovery loop's experiment mode
- reclarify_required backtrack write and three spec-readiness gate blockers added to cortex-research and cortex-spec SKILL.md files
- CORTEX.md promoted to 8-command surface; INTELLIGENCE_FLOW.md spine annotated with research→clarify backtrack and spec-readiness gate; COMMANDS.md gained full /cortex-experiment entry with open/run/close lifecycle
- Autonomy config template (3 presets, 13 named gates) and 4-layer resolver with mandatory gate enforcement — config substrate for gate-patching phases 14-16
- 1. [Rule 1 - Bug] Fixed ((PASS++)) false-exit under set -e
- /cortex-bridge SKILL.md generating all 6 GSD artifacts from Cortex spec/contract/gsd-handoff with verbatim done_criteria → ROADMAP success criteria mapping (AUTON-06) and autonomy flag sync to config.json
- Patched `drive-workflow.md` discuss action with Cortex-aware two-branch logic: Cortex-enriched CONTEXT.md when `skip_discuss_cortex` is true and artifacts exist, minimal "Claude's Discretion" fallback otherwise (AUTON-10 backward compatibility).
- Autonomy dry-run mode with per-gate source annotation plus AUTON-09 decision logging across all 5 gate-patched Cortex skills
- Autonomy posture display added to /cortex-status SKILL.md and 30-assertion integration test suite validates all Phase 16 deliverables (dry-run, source tracking, decision logging, status display)

---
