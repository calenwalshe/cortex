---
name: gsd:execute-plan
description: Execute a PLAN.md file
argument-hint: "[path-to-PLAN.md]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Task
  - TodoWrite
  - AskUserQuestion
---

<objective>
Execute a single PLAN.md file by spawning the `gsd-executor` subagent.

Orchestrator stays lean: validate plan, spawn subagent, handle checkpoints, report completion. The `gsd-executor` has all execution logic baked in.

Context budget: ~15% orchestrator, 100% fresh for subagent.
</objective>

<execution_context>
@~/.claude/get-shit-done/references/principles.md
</execution_context>

<context>
Plan path: $ARGUMENTS

@.planning/STATE.md
@.planning/config.json (if exists)
</context>

<process>
1. **Validate plan exists**
   - Confirm file at $ARGUMENTS exists
   - Error if not found: "Plan not found: {path}"

2. **Check if already executed**
   - Derive SUMMARY path from plan path (replace PLAN.md with SUMMARY.md)
   - If SUMMARY exists: "Plan already executed. SUMMARY: {path}"
   - Offer: re-execute or exit

3. **Parse plan identifiers**
   Extract from path like `.planning/phases/03-auth/03-02-PLAN.md`:
   - phase_number: `03`
   - phase_name: `auth`
   - plan_number: `02`
   - plan_path: full path

4. **Pre-execution summary (interactive mode only)**
   Check config.json for mode. Skip this step if mode=yolo.

   Parse PLAN.md to extract:
   - objective: First sentence or line from `<objective>` element
   - task_count: Count of `<task` elements
   - files: Collect unique file paths from `<files>` elements within tasks

   Display friendly summary before spawning:
   ```
   ════════════════════════════════════════
   EXECUTING: {phase_number}-{plan_number} {phase_name}
   ════════════════════════════════════════

   Building: {objective one-liner}
   Tasks: {task_count}
   Files: {comma-separated file list}

   Full plan: {plan_path}
   ════════════════════════════════════════
   ```

   No confirmation needed. Proceed to spawn after displaying.

   In yolo mode, display abbreviated version:
   ```
   ⚡ Executing {phase_number}-{plan_number}: {objective one-liner}
   ```

4.5. **Classify tasks for Codex routing (optional)**

   Read `.planning/config.json`. Check for `codex.enabled`.

   **If `codex.enabled` is `false` or absent:** Skip this step and Step 5a entirely. Go straight to Step 5b. This preserves existing behavior — all tasks route to the Claude executor.

   **If `codex.enabled` is `true`:**

   a. Parse plan tasks from PLAN.md (extract `<task>` elements with id, name, type, files)

   b. Run `task-router.js` to classify each task:
   ```bash
   node scripts/cortex/task-router.js --plan {plan_path} --config .planning/config.json
   ```

   Output is JSON:
   ```json
   {
     "codex_tasks": [{ "id": 1, "name": "...", "reason": "..." }],
     "claude_tasks": [{ "id": 2, "name": "...", "reason": "..." }]
   }
   ```

   c. Store `codex_tasks[]` and `claude_tasks[]` for Steps 5a and 5b.

   **Routing criteria** (implemented in task-router.js):
   - Tasks with `type="checkpoint:*"` always route to Claude
   - Tasks touching more than `codex.max_file_count` (default 8) files route to Claude
   - Tasks with `tdd="true"` route to Claude (Codex lacks test-run-fix loop)
   - Remaining `type="auto"` tasks route to Codex

5a. **Execute Codex tasks (if any)**

   Skip if `codex_tasks[]` is empty or if `codex` CLI is not available (`which codex` fails).

   For each task in `codex_tasks[]`:
   ```bash
   scripts/cortex/codex-exec-wrapper.sh \
     --plan {plan_path} \
     --task-id {task_id} \
     --timeout {codex.timeout_seconds || 300}
   ```

   Collect results per task:
   - On success: record commit hash and mark task complete
   - On failure: if `codex.fallback_on_failure` is `true` (default), move task to `claude_tasks[]` for Step 5b; otherwise mark task failed

   Build `<completed_tasks>` context from successful Codex results:
   ```
   | Task | Name | Commit | Executor |
   |------|------|--------|----------|
   | 1 | {name} | {hash} | codex |
   ```

5b. **Spawn gsd-executor subagent**

   ```
   Task(
     prompt="Execute plan at {plan_path}

Plan: @{plan_path}
Project state: @.planning/STATE.md
Config: @.planning/config.json (if exists)

<completed_tasks>
{completed_tasks_table from Step 5a, if any}
</completed_tasks>",
     subagent_type="gsd-executor",
     description="Execute {phase}-{plan}"
   )
   ```

   When `<completed_tasks>` is present, the executor skips those tasks and resumes from the first incomplete task. When absent (codex.enabled=false or no Codex tasks), the executor runs all tasks as before.

   The `gsd-executor` subagent has all execution logic baked in:
   - Deviation rules (auto-fix bugs, critical gaps, blockers; ask for architectural)
   - Checkpoint protocols (human-verify, decision, human-action)
   - Commit formatting (per-task atomic commits)
   - Summary creation
   - State updates

6. **Handle subagent return**
   - If contains "## CHECKPOINT REACHED": Execute checkpoint_handling
   - If contains "## PLAN COMPLETE": Verify SUMMARY exists, report success

7. **Report completion and offer next steps**
   - Show SUMMARY path
   - Show commits from subagent return
   - Route to next action (see `<offer_next>`)
</process>

<offer_next>
**MANDATORY: Present copy/paste-ready next command.**

After plan completes, determine what's next:

**Step 1: Count plans vs summaries in current phase**
```bash
ls -1 .planning/phases/[phase-dir]/*-PLAN.md 2>/dev/null | wc -l
ls -1 .planning/phases/[phase-dir]/*-SUMMARY.md 2>/dev/null | wc -l
```

**Step 2: Route based on counts**

| Condition | Action |
|-----------|--------|
| summaries < plans | More plans remain → Route A |
| summaries = plans | Phase complete → Step 2.5 (verify phase goal) |

**Step 2.5: Verify phase goal (only when phase complete)**

When summaries = plans, verify the phase achieved its GOAL before proceeding:

```
Task(
  prompt="Verify phase {phase_number} goal achievement

Phase: {phase_number} - {phase_name}
Phase goal: {phase_goal_from_roadmap}
Phase directory: @.planning/phases/{phase_dir}/

Project context:
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md (if exists)",
  subagent_type="gsd-verifier",
  description="Verify phase {phase_number}"
)
```

Handle verification result:
- **If passed:** Continue to Step 2.6 (update requirements)
- **If gaps_found:** Create fix plans, execute them, re-verify (max 3 cycles)
- **If human_needed:** Present items to user, collect response

**Step 2.6: Update requirements (only when verification passes)**

When summaries = plans, update REQUIREMENTS.md before presenting completion:

1. Get phase number from completed plan path
2. Read ROADMAP.md, find the phase's `Requirements:` line (e.g., "AUTH-01, AUTH-02")
3. Read REQUIREMENTS.md traceability table
4. For each REQ-ID in this phase: change Status from "Pending" to "Complete"
5. Write updated REQUIREMENTS.md
6. Stage for commit: `git add .planning/REQUIREMENTS.md`

**Skip if:** REQUIREMENTS.md doesn't exist, or phase has no Requirements line in ROADMAP.md.

---

**Route A: More plans remain in phase**

Find next PLAN.md without matching SUMMARY.md. Present:

```
Plan {phase}-{plan} complete.
Summary: .planning/phases/{phase-dir}/{phase}-{plan}-SUMMARY.md

{Y} of {X} plans complete for Phase {Z}.

---

## ▶ Next Up

**{phase}-{next-plan}: [Plan Name]** — [objective from PLAN.md]

`/gsd:execute-plan .planning/phases/{phase-dir}/{phase}-{next-plan}-PLAN.md`

<sub>`/clear` first → fresh context window</sub>

---
```

---

**Step 3: Check milestone status (only when phase complete)**

Read ROADMAP.md. Find current phase number and highest phase in milestone.

| Condition | Action |
|-----------|--------|
| current < highest | More phases → Route B |
| current = highest | Milestone complete → Route C |

---

**Route B: Phase complete, more phases remain**

```
## ✓ Phase {Z}: {Name} Complete

All {Y} plans finished.

---

## ▶ Next Up

**Phase {Z+1}: {Name}** — {Goal from ROADMAP.md}

`/gsd:plan-phase {Z+1}`

<sub>`/clear` first → fresh context window</sub>

---
```

---

**Route C: Milestone complete**

```
🎉 MILESTONE COMPLETE!

## ✓ Phase {Z}: {Name} Complete

All {N} phases finished.

---

## ▶ Next Up

`/gsd:complete-milestone`

<sub>`/clear` first → fresh context window</sub>

---
```
</offer_next>

<checkpoint_handling>
When `gsd-executor` returns with checkpoint:

**1. Parse return:**

The subagent returns a structured checkpoint:
```
## CHECKPOINT REACHED

**Type:** [human-verify | decision | human-action]
**Plan:** {phase}-{plan}
**Progress:** {completed}/{total} tasks complete

### Completed Tasks
| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | [task name] | [hash] | [files] |

### Current Task
**Task {N}:** [name]
**Status:** [blocked | awaiting verification | awaiting decision]
**Blocked by:** [specific blocker]

### Checkpoint Details
[Type-specific content for user]

### Awaiting
[What user needs to provide]
```

**2. Present checkpoint to user:**

Display rich formatted checkpoint based on type:

**For human-verify:**
```
╔═══════════════════════════════════════════════════════╗
║  CHECKPOINT: Verification Required                    ║
╚═══════════════════════════════════════════════════════╝

Progress: {X}/{Y} tasks complete
Task: {task name}

Built: {what-built from checkpoint details}

How to verify:
  {numbered verification steps}

────────────────────────────────────────────────────────
→ YOUR ACTION: Type "approved" or describe issues
────────────────────────────────────────────────────────
```

**For human-action (auth gate):**
```
╔═══════════════════════════════════════════════════════╗
║  CHECKPOINT: Action Required                          ║
╚═══════════════════════════════════════════════════════╝

Progress: {X}/{Y} tasks complete
Task: {task name}

Attempted: {automation attempted}
Error: {error encountered}

What you need to do:
  {numbered instructions}

I'll verify: {verification}

────────────────────────────────────────────────────────
→ YOUR ACTION: Type "done" when complete
────────────────────────────────────────────────────────
```

**For decision:**
```
╔═══════════════════════════════════════════════════════╗
║  CHECKPOINT: Decision Required                        ║
╚═══════════════════════════════════════════════════════╝

Progress: {X}/{Y} tasks complete
Task: {task name}

Decision: {what's being decided}

Context: {why this matters}

Options:
  1. {option-a} - {name}
     Pros: {benefits}
     Cons: {tradeoffs}

  2. {option-b} - {name}
     Pros: {benefits}
     Cons: {tradeoffs}

────────────────────────────────────────────────────────
→ YOUR ACTION: Select option-a or option-b
────────────────────────────────────────────────────────
```

**3. Collect response:**
Wait for user input:
- human-verify: "approved" or description of issues
- decision: option selection
- human-action: "done" when complete

**4. Spawn fresh continuation agent:**

Spawn fresh `gsd-executor` with continuation context:

```
Task(
  prompt="Continue executing plan at {plan_path}

<completed_tasks>
{completed_tasks_table from checkpoint return}
</completed_tasks>

<resume_point>
Resume from: Task {N} - {task_name}
User response: {user_response}
{resume_instructions based on checkpoint type}
</resume_point>

Plan: @{plan_path}
Project state: @.planning/STATE.md",
  subagent_type="gsd-executor",
  description="Continue {phase}-{plan}"
)
```

The `gsd-executor` has continuation handling baked in — it will verify previous commits and resume correctly.

**Why fresh agent, not resume:**
Task tool resume fails after multiple tool calls (presenting to user, waiting for response). Fresh agent with state handoff is the correct pattern.

**5. Repeat:**
Continue handling returns until "## PLAN COMPLETE" or user stops.
</checkpoint_handling>

<success_criteria>
- [ ] Plan executed (SUMMARY.md created)
- [ ] All checkpoints handled
- [ ] If phase complete: Phase goal verified (gsd-verifier spawned, VERIFICATION.md created)
- [ ] If phase complete: REQUIREMENTS.md updated (phase requirements marked Complete)
- [ ] User informed of completion and next steps
</success_criteria>
