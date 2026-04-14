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


def run_summary(ledger_path: str | None = None, min_count: int | None = None,
                top_files: int | None = None, top_pairs: int | None = None,
                extra_args: list[str] | None = None) -> subprocess.CompletedProcess:
    """Run operational-indexer.py --summary with optional flags."""
    cmd = [sys.executable, SCRIPT_PATH, "--summary"]
    if ledger_path is not None:
        cmd += ["--ledger", ledger_path]
    if min_count is not None:
        cmd += ["--min-count", str(min_count)]
    if top_files is not None:
        cmd += ["--top-files", str(top_files)]
    if top_pairs is not None:
        cmd += ["--top-pairs", str(top_pairs)]
    if extra_args:
        cmd += extra_args
    return subprocess.run(cmd, capture_output=True, text=True)


def write_fixture_ledger(ledger_path: str, sessions: int, files: int, entries_per_session: int = 10) -> int:
    """Write a synthetic multi-session, multi-file JSONL ledger.

    Each session references all `files` in round-robin. Returns total entries written.
    """
    count = 0
    with open(ledger_path, "w") as f:
        for s in range(sessions):
            for e in range(entries_per_session):
                entry = {
                    "timestamp": f"2026-01-01T00:{s:02d}:{e:02d}Z",
                    "session_id": f"session-{s}",
                    "file_path": f"/project/file-{e % files}.py",
                    "tool_name": "Edit",
                    "slug": "test",
                }
                f.write(json.dumps(entry) + "\n")
                count += 1
    return count


class TestSummaryModeAC5Schema(unittest.TestCase):
    """AC5: --summary outputs valid JSON with required fields."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.ledger = os.path.join(self.tmp_dir, "edit-ledger.jsonl")

    def test_output_is_valid_json(self):
        """--summary always outputs valid JSON to stdout."""
        result = run_summary(ledger_path=self.ledger)
        self.assertEqual(result.returncode, 0, f"Must exit 0, stderr: {result.stderr}")
        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError as e:
            self.fail(f"Output is not valid JSON: {e}\nOutput: {result.stdout}")
        self.assertIsNotNone(data)

    def test_schema_hotspots_field_present(self):
        """Output must have 'hotspots' field (list)."""
        result = run_summary(ledger_path=self.ledger)
        data = json.loads(result.stdout)
        self.assertIn("hotspots", data, "Missing 'hotspots' field")
        self.assertIsInstance(data["hotspots"], list)

    def test_schema_co_change_pairs_field_present(self):
        """Output must have 'co_change_pairs' field (list)."""
        result = run_summary(ledger_path=self.ledger)
        data = json.loads(result.stdout)
        self.assertIn("co_change_pairs", data, "Missing 'co_change_pairs' field")
        self.assertIsInstance(data["co_change_pairs"], list)

    def test_schema_entry_count_present(self):
        """Output must have 'entry_count' field (int)."""
        result = run_summary(ledger_path=self.ledger)
        data = json.loads(result.stdout)
        self.assertIn("entry_count", data, "Missing 'entry_count' field")
        self.assertIsInstance(data["entry_count"], int)

    def test_schema_as_of_present(self):
        """Output must have 'as_of' ISO8601 field."""
        result = run_summary(ledger_path=self.ledger)
        data = json.loads(result.stdout)
        self.assertIn("as_of", data, "Missing 'as_of' field")
        self.assertTrue(data["as_of"].endswith("Z"), "'as_of' must end with Z")

    def test_schema_caveat_present(self):
        """Output must have 'caveat' field."""
        result = run_summary(ledger_path=self.ledger)
        data = json.loads(result.stdout)
        self.assertIn("caveat", data, "Missing 'caveat' field")
        self.assertIsInstance(data["caveat"], str)
        self.assertGreater(len(data["caveat"]), 0, "'caveat' must be non-empty")

    def test_ledger_absent_exits_zero_with_valid_json(self):
        """When ledger is absent, exit 0 with valid JSON, entry_count 0, ledger_absent true."""
        result = run_summary(ledger_path="/nonexistent/no-such-file.jsonl")
        self.assertEqual(result.returncode, 0, f"Must exit 0 when ledger absent, stderr: {result.stderr}")
        data = json.loads(result.stdout)
        self.assertEqual(data["entry_count"], 0)
        self.assertEqual(data["hotspots"], [])
        self.assertEqual(data["co_change_pairs"], [])
        self.assertTrue(data.get("ledger_absent"), "'ledger_absent' must be True when file missing")

    def test_entry_count_matches_ledger_size(self):
        """entry_count must equal total lines in ledger (before filtering)."""
        total = write_fixture_ledger(self.ledger, sessions=3, files=3, entries_per_session=5)
        result = run_summary(ledger_path=self.ledger)
        data = json.loads(result.stdout)
        self.assertEqual(data["entry_count"], total,
                         f"entry_count {data['entry_count']} != {total} total entries")

    def test_hotspot_entry_schema(self):
        """Each hotspot entry must have file_path (str) and edit_count (int)."""
        write_fixture_ledger(self.ledger, sessions=3, files=2, entries_per_session=5)
        result = run_summary(ledger_path=self.ledger, min_count=1)
        data = json.loads(result.stdout)
        self.assertGreater(len(data["hotspots"]), 0, "Expected at least one hotspot with min_count=1")
        for entry in data["hotspots"]:
            self.assertIn("file_path", entry, "hotspot missing 'file_path'")
            self.assertIn("edit_count", entry, "hotspot missing 'edit_count'")
            self.assertIsInstance(entry["file_path"], str)
            self.assertIsInstance(entry["edit_count"], int)

    def test_co_change_pair_entry_schema(self):
        """Each co_change_pairs entry must have files (list of 2) and session_count (int)."""
        write_fixture_ledger(self.ledger, sessions=3, files=2, entries_per_session=5)
        result = run_summary(ledger_path=self.ledger, min_count=1)
        data = json.loads(result.stdout)
        self.assertGreater(len(data["co_change_pairs"]), 0, "Expected co_change_pairs with multi-file sessions")
        for pair in data["co_change_pairs"]:
            self.assertIn("files", pair, "co_change_pair missing 'files'")
            self.assertIn("session_count", pair, "co_change_pair missing 'session_count'")
            self.assertIsInstance(pair["files"], list)
            self.assertEqual(len(pair["files"]), 2, "co_change_pair 'files' must have exactly 2 entries")
            self.assertIsInstance(pair["session_count"], int)


class TestSummaryModeAC6Filtering(unittest.TestCase):
    """AC6: --summary filters files by min-count; threshold overridable via --min-count N."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.ledger = os.path.join(self.tmp_dir, "edit-ledger.jsonl")

    def _write_single_file_ledger(self, file_path: str, count: int, session_id: str = "s0") -> None:
        """Write `count` entries for a single file."""
        with open(self.ledger, "a") as f:
            for i in range(count):
                entry = {
                    "timestamp": f"2026-01-01T00:00:{i:02d}Z",
                    "session_id": session_id,
                    "file_path": file_path,
                    "tool_name": "Edit",
                    "slug": "test",
                }
                f.write(json.dumps(entry) + "\n")

    def test_default_min_count_2_excludes_single_edit(self):
        """File with edit_count==1 is NOT in hotspots with default min_count=2."""
        self._write_single_file_ledger("/only-once.py", 1, "s0")
        result = run_summary(ledger_path=self.ledger)
        data = json.loads(result.stdout)
        paths = [e["file_path"] for e in data["hotspots"]]
        self.assertNotIn("/only-once.py", paths,
                         "File with edit_count==1 must not appear with default min_count=2")

    def test_default_min_count_2_includes_double_edit(self):
        """File with edit_count==2 IS in hotspots with default min_count=2."""
        self._write_single_file_ledger("/twice.py", 2, "s0")
        result = run_summary(ledger_path=self.ledger)
        data = json.loads(result.stdout)
        paths = [e["file_path"] for e in data["hotspots"]]
        self.assertIn("/twice.py", paths,
                      "File with edit_count==2 must appear with default min_count=2")

    def test_min_count_1_includes_single_edit(self):
        """File with edit_count==1 IS in hotspots when --min-count 1 is set."""
        self._write_single_file_ledger("/only-once.py", 1, "s0")
        result = run_summary(ledger_path=self.ledger, min_count=1)
        data = json.loads(result.stdout)
        paths = [e["file_path"] for e in data["hotspots"]]
        self.assertIn("/only-once.py", paths,
                      "File with edit_count==1 must appear with --min-count 1")

    def test_min_count_5_excludes_below_threshold(self):
        """File with edit_count==3 is NOT in hotspots when --min-count 5 is set."""
        self._write_single_file_ledger("/three-times.py", 3, "s0")
        result = run_summary(ledger_path=self.ledger, min_count=5)
        data = json.loads(result.stdout)
        paths = [e["file_path"] for e in data["hotspots"]]
        self.assertNotIn("/three-times.py", paths,
                         "File with edit_count==3 must not appear with --min-count 5")

    def test_hotspots_sorted_by_edit_count_desc(self):
        """Hotspots are sorted by edit_count descending."""
        self._write_single_file_ledger("/high.py", 10, "s0")
        self._write_single_file_ledger("/low.py", 2, "s1")
        result = run_summary(ledger_path=self.ledger, min_count=2)
        data = json.loads(result.stdout)
        counts = [e["edit_count"] for e in data["hotspots"]]
        self.assertEqual(counts, sorted(counts, reverse=True),
                         "Hotspots must be sorted by edit_count descending")


class TestSummaryModeAC10CoChange(unittest.TestCase):
    """AC10: fixture with ≥3 sessions and ≥2 files in multiple sessions produces
    hotspots with edit_count≥2 and co_change_pairs with session_count≥2."""

    def setUp(self):
        self.tmp_dir = tempfile.mkdtemp()
        self.ledger = os.path.join(self.tmp_dir, "edit-ledger.jsonl")

    def _write_multi_session_fixture(self) -> None:
        """3 sessions × 3 files → /f0.py and /f1.py appear in all 3 sessions."""
        with open(self.ledger, "w") as f:
            for s in range(3):
                for fp in ["/f0.py", "/f1.py", "/f2.py"]:
                    entry = {
                        "timestamp": f"2026-01-01T0{s}:00:00Z",
                        "session_id": f"session-{s}",
                        "file_path": fp,
                        "tool_name": "Edit",
                        "slug": "test",
                    }
                    f.write(json.dumps(entry) + "\n")

    def test_hotspots_has_entry_with_edit_count_gte_2(self):
        """After 3 sessions × 3 files, hotspots has entries with edit_count >= 2."""
        self._write_multi_session_fixture()
        result = run_summary(ledger_path=self.ledger)
        data = json.loads(result.stdout)
        high_count = [e for e in data["hotspots"] if e["edit_count"] >= 2]
        self.assertGreater(len(high_count), 0,
                           "Expected at least one hotspot with edit_count >= 2")

    def test_co_change_pairs_has_entry_with_session_count_gte_2(self):
        """After 3 sessions × 3 files, co_change_pairs has entry with session_count >= 2."""
        self._write_multi_session_fixture()
        result = run_summary(ledger_path=self.ledger)
        data = json.loads(result.stdout)
        high_pairs = [p for p in data["co_change_pairs"] if p["session_count"] >= 2]
        self.assertGreater(len(high_pairs), 0,
                           "Expected at least one co_change pair with session_count >= 2")

    def test_co_change_pairs_sorted_by_session_count_desc(self):
        """co_change_pairs are sorted by session_count descending."""
        self._write_multi_session_fixture()
        result = run_summary(ledger_path=self.ledger)
        data = json.loads(result.stdout)
        counts = [p["session_count"] for p in data["co_change_pairs"]]
        self.assertEqual(counts, sorted(counts, reverse=True),
                         "co_change_pairs must be sorted by session_count descending")

    def test_no_self_pairs_in_co_change(self):
        """co_change_pairs never contains a pair where both files are the same."""
        self._write_multi_session_fixture()
        result = run_summary(ledger_path=self.ledger)
        data = json.loads(result.stdout)
        for pair in data["co_change_pairs"]:
            self.assertNotEqual(pair["files"][0], pair["files"][1],
                                f"Self-pair found: {pair['files']}")

    def test_large_fixture_entry_count(self):
        """Fixture with 502 entries → entry_count == 502 (reads all before filtering)."""
        # Generate exactly as the contract validator does
        with open(self.ledger, "w") as f:
            for i in range(502):
                entry = {
                    "timestamp": "2026-01-01T00:00:0" + str(i % 10) + "Z",
                    "session_id": "s" + str(i % 3),
                    "file_path": "/f" + str(i % 5) + ".py",
                    "tool_name": "Edit",
                    "slug": "test",
                }
                f.write(json.dumps(entry) + "\n")
        result = run_summary(ledger_path=self.ledger)
        data = json.loads(result.stdout)
        self.assertEqual(data["entry_count"], 502,
                         f"entry_count must be 502 (all entries read), got {data['entry_count']}")

    def test_top_files_limits_hotspot_output(self):
        """--top-files N limits hotspot list to N entries."""
        write_fixture_ledger(self.ledger, sessions=3, files=5, entries_per_session=6)
        result = run_summary(ledger_path=self.ledger, min_count=1, top_files=2)
        data = json.loads(result.stdout)
        self.assertLessEqual(len(data["hotspots"]), 2,
                             "--top-files 2 must limit hotspots to at most 2 entries")

    def test_top_pairs_limits_co_change_output(self):
        """--top-pairs N limits co_change_pairs list to N entries."""
        write_fixture_ledger(self.ledger, sessions=3, files=5, entries_per_session=6)
        result = run_summary(ledger_path=self.ledger, top_pairs=3)
        data = json.loads(result.stdout)
        self.assertLessEqual(len(data["co_change_pairs"]), 3,
                             "--top-pairs 3 must limit co_change_pairs to at most 3 entries")


if __name__ == "__main__":
    unittest.main()
