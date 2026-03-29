# AGENTS.md

Repository-wide instructions for Codex agents working in `/workspace/cortex`.

## 1) Repo-specific execution rules

- Keep changes small and scoped to the request.
- Prefer `rg` for search and avoid recursive `ls`/`grep` scans.
- If a command fails, report the exact command and key error in the final summary.
- Do not edit generated artifacts unless the task explicitly asks for it.

## 2) Build, lint, and validation commands

Use these commands in this order unless the user asks otherwise.

### Fast checks (run during implementation)

1. Unified fast verifier (recommended after each edit):
   - `bash scripts/verify-fast.sh`
2. Installer dry-run smoke test:
   - `node bin/install.js --dry-run`
3. Installer shell test suite:
   - `bash test/installer.test.sh`

### Full checks (run before commit/PR)

1. Re-run installer shell test suite from a clean working tree state:
   - `bash test/installer.test.sh`
2. Verify repository has no obvious credential URLs in executable/config surfaces:
   - `grep -rn 'https://.*:.*@' bin/ hooks/ .claude/ scripts/ --include='*.sh' --include='*.js' || true`

## 3) Test execution policy

Always follow this sequence:

1. **Post-edit auto-verify**: after each meaningful edit, run `bash scripts/verify-fast.sh`.
2. **Fail fast first**: run the dry-run installer smoke check before making broad changes.
3. **Targeted validation**: run the installer test suite when touching install logic, hooks, agents, skills, or settings wiring.
4. **Broader validation before handoff**: re-run the test suite after edits are complete.
5. **Actionable failures**: if tests fail, include likely root cause and a concrete next fix step.

## 4) Definition of done

Before concluding work:

- Relevant checks above have been run (or explicitly explained if skipped).
- Documentation is updated when behavior or workflow changes.
- Final summary includes commands executed and pass/fail status.
