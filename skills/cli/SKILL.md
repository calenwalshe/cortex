# CLI — Context-Aware Shell Execution

Context-aware shell execution with LLM safety classification. Understands project context, auto-executes read-only commands, requires confirmation for destructive commands, and hard-blocks dangerous operations. Complements `cli-anything` — does not replace it.

## User-invocable

When the user types `/cli`, run this skill.

Also trigger — WITHOUT requiring the slash command — when the user says any of:
- "run this command", "execute this", "run in shell", "bash this", "shell command" (→ classify then execute)
- "run ls", "run git status", "run ps", "show me the directory", "what processes are running" (→ likely read-only, auto-execute)
- "delete this file", "remove the directory", "reset the branch", "kill the process" (→ destructive, prompt confirmation)

Do NOT trigger for: file edits, code writing, or requests that don't involve shell execution.

## Arguments

- `/cli <command>` — classify and execute a shell command
- `/cli --force <command>` — skip confirmation for destructive commands (user accepts risk)
- `--save <path>` — write command output to file instead of chat

## Instructions

### Safety classification

Before executing any command, classify it:

**READ-ONLY (auto-execute, no confirmation needed):**
- File listing: `ls`, `ll`, `find` (without `-delete`), `tree`
- File reading: `cat`, `head`, `tail`, `less`, `wc`, `stat`
- Directory: `pwd`, `cd` (report new dir only)
- Git read: `git status`, `git log`, `git diff`, `git branch`, `git show`
- System info: `ps`, `top`, `htop`, `df`, `du`, `uname`, `whoami`, `which`, `env`, `echo`, `date`
- Network read: `curl` (GET only), `ping`, `nslookup`, `dig`
- Package info: `pip list`, `npm list`, `apt list`, `brew list`
- Search: `grep`, `rg`, `ag`, `awk`, `sed` (read-only, no in-place)

**DESTRUCTIVE (require explicit confirmation before executing):**
- File deletion: `rm <file>`, `unlink`
- File modification: `mv`, `cp` (overwrite), `chmod`, `chown`, `truncate`
- Git write: `git reset`, `git checkout` (files), `git clean`, `git stash drop`, `git commit`, `git push`
- Process control: `kill`, `pkill`, `killall`
- Package changes: `pip install`, `pip uninstall`, `npm install`, `npm uninstall`, `apt install`, `apt remove`
- Database write: `INSERT`, `UPDATE`, `DELETE` (single-row operations)
- `sed -i` (in-place file edit)

**HARD-BLOCK (never execute, even with --force):**
- Recursive deletion: `rm -rf`, `rm -r` on root paths, `rmdir -p`
- Disk-level: `dd if=`, `mkfs`, `fdisk`, `format`
- Database drop: `DROP TABLE`, `DROP DATABASE`, `TRUNCATE TABLE`
- Force push to protected branches: `git push --force origin main`, `git push --force origin master`
- Credential exposure: `cat ~/.ssh/id_rsa`, `cat ~/.aws/credentials`, `env | grep -i key`
- Fork bombs or infinite loops

### Execution flow

**READ-ONLY:** Execute immediately, show output.

**DESTRUCTIVE:**
1. Show the command
2. Show a one-line explanation of what it will do
3. Ask: `Run this command? (yes/no)`
4. If yes: execute and show output. If no: `Cancelled.`
5. `--force` flag skips steps 2-3.

**HARD-BLOCK:**
Output: `Blocked: this command class is never auto-executed. If you need to do this, run it yourself in your terminal.`
Never offer a confirmation prompt. Never execute even with `--force`.

### Project context

Before executing, briefly note the project context if relevant:
- Current git branch (from `git branch --show-current`)
- Working directory
- This helps the user confirm they're in the right repo/directory before destructive ops.

### Execution

```python
import subprocess

result = subprocess.run(
    command,
    shell=True,
    capture_output=True,
    text=True,
    timeout=30
)

if result.returncode == 0:
    print(result.stdout)
else:
    print(f"Exit code {result.returncode}\nStdout: {result.stdout}\nStderr: {result.stderr}")
```

For long-running commands (>30s expected), use `run_in_background=True` in the Bash tool and inform the user.

### --save flag

If `--save <path>` provided, write command output to that path. Relative paths resolve from CWD.
If omitted, output goes to chat.

## Rules

- Classify BEFORE executing — never execute first and ask forgiveness.
- Hard-block commands are never executed regardless of `--force` or user insistence.
- Always show the full command before executing a destructive op.
- When in doubt, classify as DESTRUCTIVE (prompt confirmation) rather than READ-ONLY.
- Do not use this skill to read credential files, private keys, or secrets — hard-block those.
- This skill complements `cli-anything` — if `cli-anything` already handles a request, that is fine.
