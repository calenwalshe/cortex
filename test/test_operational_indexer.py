"""
test_operational_indexer.py — Tests for operational-indexer.py --hook mode

Covers AC1–AC4:
  AC1: Edit/Write tool calls append exactly one JSONL entry to the ledger
  AC2: Bash/Read/Glob/Grep tool calls do NOT append to the ledger
  AC3: Hook exits 0 for any valid PostToolUse JSON payload
  AC4: Writing 502 entries results in exactly 500 entries (oldest 2 dropped)
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

CORTEX_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT_PATH = os.path.join(CORTEX_ROOT, "scripts", "cortex", "operational-indexer.py")


def run_hook(payload: dict, ledger_path: str, state_path: str | None = None) -> subprocess.CompletedProcess:
    """Run operational-indexer.py --hook with given payload via stdin."""
    env = os.environ.copy()
    cmd = [sys.executable, SCRIPT_PATH, "--hook", "--ledger", ledger_path]
    if state_path is not None:
        cmd += ["--state", state_path]
    return subprocess.run(
        cmd,
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env=env,
    )


def count_ledger_lines(ledger_path: str) -> int:
    """Count non-empty lines in ledger file."""
    if not os.path.exists(ledger_path):
        return 0
    with open(ledger_path) as f:
        return sum(1 for line in f if line.strip())


def write_ledger_entries(ledger_path: str, count: int) -> None:
    """Write `count` synthetic JSONL entries directly to ledger file."""
    with open(ledger_path, "w") as f:
        for i in range(count):
            entry = {
                "timestamp": f"2026-01-01T00:00:{i:02d}Z",
                "session_id": f"s{i}",
                "file_path": f"/f{i}.py",
                "tool_name": "Edit",
                "slug": "test",
            }
            f.write(json.dumps(entry) + "\n")


class TestHookModeAC1(unittest.TestCase):
    """AC1: Edit and Write tool calls append exactly one JSONL entry."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.ledger = os.path.join(self.tmp_dir, "edit-ledger.jsonl")
        # Write a minimal state.json so slug can be read
        self.state = os.path.join(self.tmp_dir, "state.json")
        with open(self.state, "w") as f:
            json.dump({"slug": "test-slug"}, f)

    def _edit_payload(self, session_id="sess-1", file_path="/tmp/x.py"):
        return {
            "tool_name": "Edit",
            "tool_input": {"file_path": file_path},
            "session_id": session_id,
            "cwd": "/tmp",
        }

    def _write_payload(self, session_id="sess-1", file_path="/tmp/y.py"):
        return {
            "tool_name": "Write",
            "tool_input": {"file_path": file_path},
            "session_id": session_id,
            "cwd": "/tmp",
        }

    def test_edit_appends_one_line(self):
        """Edit payload produces exactly one new JSONL line."""
        before = count_ledger_lines(self.ledger)
        run_hook(self._edit_payload(), self.ledger, self.state)
        after = count_ledger_lines(self.ledger)
        self.assertEqual(after - before, 1, "Edit must append exactly one line")

    def test_write_appends_one_line(self):
        """Write payload produces exactly one new JSONL line."""
        before = count_ledger_lines(self.ledger)
        run_hook(self._write_payload(), self.ledger, self.state)
        after = count_ledger_lines(self.ledger)
        self.assertEqual(after - before, 1, "Write must append exactly one line")

    def test_edit_schema_all_fields_present(self):
        """JSONL entry has all required schema fields."""
        run_hook(self._edit_payload(session_id="schema-sess", file_path="/tmp/schema.py"), self.ledger, self.state)
        with open(self.ledger) as f:
            lines = [l for l in f if l.strip()]
        entry = json.loads(lines[-1])
        required = {"timestamp", "session_id", "file_path", "tool_name", "slug"}
        self.assertTrue(required.issubset(entry.keys()), f"Missing fields: {required - entry.keys()}")

    def test_edit_schema_field_values(self):
        """JSONL entry captures correct field values."""
        payload = self._edit_payload(session_id="value-sess", file_path="/tmp/target.py")
        run_hook(payload, self.ledger, self.state)
        with open(self.ledger) as f:
            lines = [l for l in f if l.strip()]
        entry = json.loads(lines[-1])
        self.assertEqual(entry["session_id"], "value-sess")
        self.assertEqual(entry["file_path"], "/tmp/target.py")
        self.assertEqual(entry["tool_name"], "Edit")
        self.assertEqual(entry["slug"], "test-slug")
        # Timestamp must be a non-empty string ending in Z
        self.assertTrue(entry["timestamp"].endswith("Z"), "timestamp must end with Z")

    def test_write_schema_tool_name(self):
        """JSONL entry records tool_name as 'Write' for Write payloads."""
        run_hook(self._write_payload(), self.ledger, self.state)
        with open(self.ledger) as f:
            lines = [l for l in f if l.strip()]
        entry = json.loads(lines[-1])
        self.assertEqual(entry["tool_name"], "Write")

    def test_slug_defaults_to_empty_when_state_absent(self):
        """Slug field defaults to empty string when state.json is absent."""
        missing_state = os.path.join(self.tmp_dir, "nonexistent-state.json")
        run_hook(self._edit_payload(), self.ledger, missing_state)
        with open(self.ledger) as f:
            lines = [l for l in f if l.strip()]
        entry = json.loads(lines[-1])
        self.assertEqual(entry["slug"], "", "slug must default to empty string if state absent")

    def test_file_path_defaults_to_empty_when_missing_from_payload(self):
        """file_path defaults to empty string when tool_input has no file_path key."""
        payload = {"tool_name": "Edit", "tool_input": {}, "session_id": "s1", "cwd": "/tmp"}
        run_hook(payload, self.ledger, self.state)
        with open(self.ledger) as f:
            lines = [l for l in f if l.strip()]
        entry = json.loads(lines[-1])
        self.assertEqual(entry["file_path"], "")


class TestHookModeAC2(unittest.TestCase):
    """AC2: Non-Edit/Write tool calls do NOT append to the ledger."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.ledger = os.path.join(self.tmp_dir, "edit-ledger.jsonl")
        self.state = os.path.join(self.tmp_dir, "state.json")
        with open(self.state, "w") as f:
            json.dump({"slug": "test-slug"}, f)

    def _payload(self, tool_name: str):
        return {
            "tool_name": tool_name,
            "tool_input": {"command": "ls"},
            "session_id": "s1",
            "cwd": "/tmp",
        }

    def test_bash_does_not_append(self):
        before = count_ledger_lines(self.ledger)
        run_hook(self._payload("Bash"), self.ledger, self.state)
        self.assertEqual(count_ledger_lines(self.ledger), before, "Bash must not append")

    def test_read_does_not_append(self):
        before = count_ledger_lines(self.ledger)
        run_hook(self._payload("Read"), self.ledger, self.state)
        self.assertEqual(count_ledger_lines(self.ledger), before, "Read must not append")

    def test_glob_does_not_append(self):
        before = count_ledger_lines(self.ledger)
        run_hook(self._payload("Glob"), self.ledger, self.state)
        self.assertEqual(count_ledger_lines(self.ledger), before, "Glob must not append")

    def test_grep_does_not_append(self):
        before = count_ledger_lines(self.ledger)
        run_hook(self._payload("Grep"), self.ledger, self.state)
        self.assertEqual(count_ledger_lines(self.ledger), before, "Grep must not append")

    def test_unknown_tool_does_not_append(self):
        before = count_ledger_lines(self.ledger)
        run_hook(self._payload("SomeFutureTool"), self.ledger, self.state)
        self.assertEqual(count_ledger_lines(self.ledger), before, "Unknown tool must not append")


class TestHookModeAC3(unittest.TestCase):
    """AC3: Hook exits 0 for any valid PostToolUse JSON payload."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.ledger = os.path.join(self.tmp_dir, "edit-ledger.jsonl")
        self.state = os.path.join(self.tmp_dir, "state.json")
        with open(self.state, "w") as f:
            json.dump({"slug": "test-slug"}, f)

    def _check_exit_zero(self, payload):
        result = run_hook(payload, self.ledger, self.state)
        self.assertEqual(result.returncode, 0, f"Hook must exit 0 for payload: {payload}")

    def test_exit_zero_edit(self):
        self._check_exit_zero(
            {"tool_name": "Edit", "tool_input": {"file_path": "/tmp/x.py"}, "session_id": "s1", "cwd": "/tmp"}
        )

    def test_exit_zero_write(self):
        self._check_exit_zero(
            {"tool_name": "Write", "tool_input": {"file_path": "/tmp/y.py"}, "session_id": "s1", "cwd": "/tmp"}
        )

    def test_exit_zero_bash(self):
        self._check_exit_zero(
            {"tool_name": "Bash", "tool_input": {"command": "ls"}, "session_id": "s1", "cwd": "/tmp"}
        )

    def test_exit_zero_read(self):
        self._check_exit_zero(
            {"tool_name": "Read", "tool_input": {"file_path": "/tmp/z.py"}, "session_id": "s1", "cwd": "/tmp"}
        )

    def test_exit_zero_minimal_payload(self):
        """Hook exits 0 even with a minimal/near-empty payload."""
        self._check_exit_zero({"tool_name": "Edit"})

    def test_exit_zero_missing_tool_name(self):
        """Hook exits 0 even when tool_name is absent."""
        self._check_exit_zero({"tool_input": {"file_path": "/tmp/x.py"}, "session_id": "s1"})

    def test_exit_zero_state_missing(self):
        """Hook exits 0 when state.json does not exist."""
        missing_state = os.path.join(self.tmp_dir, "no-state.json")
        result = run_hook(
            {"tool_name": "Edit", "tool_input": {"file_path": "/tmp/x.py"}, "session_id": "s1"},
            self.ledger,
            missing_state,
        )
        self.assertEqual(result.returncode, 0)

    def test_exit_zero_unwriteable_ledger_dir(self):
        """Hook exits 0 even if ledger path is unwriteable."""
        bad_ledger = "/root/noperm/edit-ledger.jsonl"
        result = run_hook(
            {"tool_name": "Edit", "tool_input": {"file_path": "/tmp/x.py"}, "session_id": "s1"},
            bad_ledger,
            self.state,
        )
        self.assertEqual(result.returncode, 0)


class TestHookModeAC4(unittest.TestCase):
    """AC4: Writing 502 entries results in exactly 500 (oldest 2 dropped)."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.ledger = os.path.join(self.tmp_dir, "edit-ledger.jsonl")
        self.state = os.path.join(self.tmp_dir, "state.json")
        with open(self.state, "w") as f:
            json.dump({"slug": "prune-slug"}, f)

    def test_prune_to_500(self):
        """Writing 502 entries via hook produces exactly 500 in ledger."""
        # Pre-populate ledger with 500 entries
        write_ledger_entries(self.ledger, 500)
        self.assertEqual(count_ledger_lines(self.ledger), 500)

        # Append 2 more via hook (total would be 502 → prune to 500)
        for i in range(2):
            run_hook(
                {
                    "tool_name": "Edit",
                    "tool_input": {"file_path": f"/tmp/extra{i}.py"},
                    "session_id": f"extra-{i}",
                    "cwd": "/tmp",
                },
                self.ledger,
                self.state,
            )

        final_count = count_ledger_lines(self.ledger)
        self.assertEqual(final_count, 500, f"Expected 500 entries after prune, got {final_count}")

    def test_prune_drops_oldest(self):
        """After prune, the oldest entries are dropped (newest 500 retained)."""
        write_ledger_entries(self.ledger, 500)

        # Append 2 entries with distinctive session IDs
        for i in range(2):
            run_hook(
                {
                    "tool_name": "Edit",
                    "tool_input": {"file_path": f"/tmp/newest{i}.py"},
                    "session_id": f"newest-session-{i}",
                    "cwd": "/tmp",
                },
                self.ledger,
                self.state,
            )

        with open(self.ledger) as f:
            lines = [l for l in f if l.strip()]

        # First 2 original entries must be gone (session_id "s0" and "s1")
        first_entry = json.loads(lines[0])
        self.assertNotEqual(first_entry["session_id"], "s0", "Oldest entry s0 must be pruned")

        # Last entries must be the new ones
        last_entry = json.loads(lines[-1])
        self.assertIn("newest-session", last_entry["session_id"], "Newest entry must be last")

    def test_no_prune_when_below_limit(self):
        """No prune occurs when ledger has fewer than 500 entries."""
        write_ledger_entries(self.ledger, 50)
        run_hook(
            {"tool_name": "Edit", "tool_input": {"file_path": "/tmp/x.py"}, "session_id": "s1", "cwd": "/tmp"},
            self.ledger,
            self.state,
        )
        self.assertEqual(count_ledger_lines(self.ledger), 51)

    def test_exactly_500_no_prune(self):
        """At exactly 500 entries, no prune occurs."""
        write_ledger_entries(self.ledger, 499)
        run_hook(
            {"tool_name": "Edit", "tool_input": {"file_path": "/tmp/x.py"}, "session_id": "s1", "cwd": "/tmp"},
            self.ledger,
            self.state,
        )
        self.assertEqual(count_ledger_lines(self.ledger), 500)


if __name__ == "__main__":
    unittest.main()
