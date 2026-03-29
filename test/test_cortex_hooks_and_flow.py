import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
HOOKS_DIR = REPO_ROOT / ".claude" / "hooks"


def run_hook(path: Path, project_dir: Path, payload: dict | None = None):
    env = os.environ.copy()
    env["CLAUDE_PROJECT_DIR"] = str(project_dir)
    return subprocess.run(
        ["bash", str(path)],
        input=(json.dumps(payload) if payload is not None else ""),
        text=True,
        capture_output=True,
        env=env,
        check=False,
    )


class HookRegressionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.project = Path(self.tmp.name)
        (self.project / ".cortex").mkdir(parents=True, exist_ok=True)
        (self.project / "docs" / "cortex" / "handoffs").mkdir(parents=True, exist_ok=True)

    def tearDown(self):
        self.tmp.cleanup()

    def write_state(self, mode="clarify", slug="demo", active_contract="docs/cortex/contracts/demo/contract-001.md"):
        state = {
            "slug": slug,
            "mode": mode,
            "active_contract": active_contract,
        }
        (self.project / ".cortex" / "state.json").write_text(json.dumps(state), encoding="utf-8")

    def test_phase_guard_blocks_write_outside_docs_and_cortex_in_research(self):
        self.write_state(mode="research")
        payload = {"tool_input": {"file_path": str(self.project / "src" / "main.ts")}}
        result = run_hook(HOOKS_DIR / "cortex-phase-guard.sh", self.project, payload)
        self.assertEqual(result.returncode, 0)
        parsed = json.loads(result.stdout)
        decision = parsed["hookSpecificOutput"]
        self.assertEqual(decision["permissionDecision"], "deny")
        self.assertIn("blocked", decision["permissionDecisionReason"])

    def test_phase_guard_allows_docs_cortex_and_execute_mode(self):
        self.write_state(mode="spec")
        payload = {"tool_input": {"file_path": str(self.project / "docs" / "cortex" / "handoffs" / "current-state.md")}}
        result = run_hook(HOOKS_DIR / "cortex-phase-guard.sh", self.project, payload)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "")

        self.write_state(mode="execute")
        payload = {"tool_input": {"file_path": str(self.project / "src" / "main.ts")}}
        result = run_hook(HOOKS_DIR / "cortex-phase-guard.sh", self.project, payload)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), "")

    def test_session_start_injects_current_state(self):
        current_state = self.project / "docs" / "cortex" / "handoffs" / "current-state.md"
        current_state.write_text("# Current State\nmode: execute\n", encoding="utf-8")
        result = run_hook(HOOKS_DIR / "cortex-session-start.sh", self.project)
        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)
        context = payload["hookSpecificOutput"]["additionalContext"]
        self.assertTrue(context.startswith("CORTEX STATE RESTORED"))
        self.assertIn("mode: execute", context)

    def test_validator_trigger_tracks_only_execute_or_repair(self):
        dirty = self.project / ".cortex" / "dirty-files.json"

        self.write_state(mode="execute")
        tracked_path = str(self.project / "src" / "feature.ts")
        payload = {"tool_response": {"filePath": tracked_path}}
        first = run_hook(HOOKS_DIR / "cortex-validator-trigger.sh", self.project, payload)
        second = run_hook(HOOKS_DIR / "cortex-validator-trigger.sh", self.project, payload)
        self.assertEqual(first.returncode, 0)
        self.assertEqual(second.returncode, 0)
        data = json.loads(dirty.read_text(encoding="utf-8"))
        self.assertEqual(data["dirty"], [tracked_path])

        self.write_state(mode="validate")
        ignored_payload = {"tool_response": {"filePath": str(self.project / "src" / "other.ts")}}
        ignored = run_hook(HOOKS_DIR / "cortex-validator-trigger.sh", self.project, ignored_payload)
        self.assertEqual(ignored.returncode, 0)
        data_after = json.loads(dirty.read_text(encoding="utf-8"))
        self.assertEqual(data_after["dirty"], [tracked_path])

    def test_compaction_hooks_write_snapshot_and_summary(self):
        self.write_state(mode="repair", slug="loop-lock", active_contract="docs/cortex/contracts/loop-lock/contract-002.md")
        current_state = self.project / "docs" / "cortex" / "handoffs" / "current-state.md"
        current_state.write_text("# Current State\nnext_action: run validators\n", encoding="utf-8")

        pre = run_hook(HOOKS_DIR / "cortex-precompact.sh", self.project)
        self.assertEqual(pre.returncode, 0)
        snapshots = sorted((self.project / ".cortex" / "compaction").glob("precompact-*.md"))
        self.assertTrue(snapshots, "expected precompact snapshot to be created")
        snapshot_text = snapshots[-1].read_text(encoding="utf-8")
        self.assertIn("# Pre-Compaction Snapshot", snapshot_text)
        self.assertIn("## state.json", snapshot_text)

        post = run_hook(HOOKS_DIR / "cortex-postcompact.sh", self.project)
        self.assertEqual(post.returncode, 0)
        summary = (self.project / "docs" / "cortex" / "handoffs" / "last-compact-summary.md").read_text(encoding="utf-8")
        next_prompt = (self.project / "docs" / "cortex" / "handoffs" / "next-prompt.md").read_text(encoding="utf-8")
        self.assertIn("loop-lock", summary)
        self.assertIn("repair", summary)
        self.assertIn("contract-002.md", summary)
        self.assertIn("Run /cortex-status", summary)
        self.assertIn("loop-lock", next_prompt)
        self.assertIn("contract-002.md", next_prompt)


class WorkflowPolicyRegressionTests(unittest.TestCase):
    def test_status_reconstruction_declares_state_sources_and_recovery_files(self):
        status_skill = (REPO_ROOT / "skills" / "cortex-status" / "SKILL.md").read_text(encoding="utf-8")
        self.assertIn("docs/cortex/handoffs/current-state.md", status_skill)
        self.assertIn(".cortex/state.json", status_skill)
        self.assertIn("Continuity files refreshed", status_skill)
        self.assertIn("docs/cortex/handoffs/next-prompt.md", status_skill)

    def test_eval_lifecycle_and_contract_requirements_are_explicit(self):
        research_skill = (REPO_ROOT / "skills" / "cortex-research" / "SKILL.md").read_text(encoding="utf-8")
        spec_skill = (REPO_ROOT / "skills" / "cortex-spec" / "SKILL.md").read_text(encoding="utf-8")
        commands = (REPO_ROOT / "docs" / "COMMANDS.md").read_text(encoding="utf-8")

        self.assertIn("eval-proposal.md", research_skill)
        self.assertIn("approval_required: true", research_skill)
        self.assertIn("BLOCKED: Eval Plan Cannot Be Written", research_skill)
        self.assertIn("eval-plan.md", research_skill)

        self.assertIn("Eval Plan", spec_skill)
        self.assertIn("Mandatory field", spec_skill)
        self.assertIn("contract without this field is incomplete", spec_skill)

        self.assertIn("/cortex-clarify` → `/cortex-research` → `/cortex-spec`", commands)


if __name__ == "__main__":
    unittest.main()
