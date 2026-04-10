"""
Tests for scripts/cortex/format-eval-results.py

TDD: written BEFORE implementation.
Run: python3 -m pytest test/test_format_eval_results.py -v
"""
import subprocess
import sys
import json
import textwrap
from pathlib import Path

SCRIPT = Path(__file__).parent.parent / "scripts" / "cortex" / "format-eval-results.py"


def run_script(result_json: str, slug: str, output_dir: str, extra_args=None) -> subprocess.CompletedProcess:
    cmd = [
        sys.executable, str(SCRIPT),
        "--result-json", result_json,
        "--slug", slug,
        "--output-dir", output_dir,
    ]
    if extra_args:
        cmd.extend(extra_args)
    return subprocess.run(cmd, capture_output=True, text=True)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

PASS_RESULT = {
    "overall_verdict": "pass",
    "evaluated_dimensions": [
        {
            "dimension": "Functional Correctness",
            "verdict": "pass",
            "finding": "All 49 tests pass, all 6 validators pass.",
            "severity": "note",
            "fixtures_tested": ["test/test_stats.py"],
            "failures": [],
        },
        {
            "dimension": "Style",
            "verdict": "pass",
            "finding": "All public APIs have docstrings.",
            "severity": "note",
            "fixtures_tested": ["scripts/kalshi/stats.py"],
            "failures": [],
        },
    ],
    "deviations": [],
    "convergence_risk": None,
}

FAIL_RESULT = {
    "overall_verdict": "fail",
    "evaluated_dimensions": [
        {
            "dimension": "Functional Correctness",
            "verdict": "pass",
            "finding": "Tests pass.",
            "severity": "note",
            "fixtures_tested": ["test/test_stats.py"],
            "failures": [],
        },
        {
            "dimension": "Style",
            "verdict": "fail",
            "finding": "Two public functions lack docstrings.",
            "severity": "blocking",
            "fixtures_tested": ["scripts/kalshi/stats.py"],
            "failures": [
                {"criterion": "All public functions documented", "evidence": "cusum() missing docstring at line 42"},
                {"criterion": "All public functions documented", "evidence": "msprt() missing docstring at line 88"},
            ],
        },
    ],
    "deviations": ["stats.py imports scipy but spec says no external deps"],
    "convergence_risk": None,
}

PARTIAL_RESULT = {
    "overall_verdict": "partial",
    "evaluated_dimensions": [
        {
            "dimension": "Functional Correctness",
            "verdict": "partial",
            "finding": "47/49 tests pass. 2 failures in edge cases.",
            "severity": "warn",
            "fixtures_tested": ["test/test_stats.py"],
            "failures": [
                {"criterion": "All tests pass", "evidence": "test_cusum_zero_input FAIL"},
            ],
        },
    ],
    "deviations": [],
    "convergence_risk": "Same edge cases failed in previous run — may not converge.",
}


class TestResultsMdStructure:
    """Output results-{timestamp}.md must have required structure."""

    def test_results_file_created(self, tmp_path):
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(PASS_RESULT))
        result = run_script(str(result_json), "test-slug", str(tmp_path))
        assert result.returncode == 0, result.stderr
        files = list(tmp_path.glob("results-*.md"))
        assert len(files) == 1, f"Expected 1 results file, found: {files}"

    def test_results_header_present(self, tmp_path):
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(PASS_RESULT))
        result = run_script(str(result_json), "test-slug", str(tmp_path))
        assert result.returncode == 0, result.stderr
        content = list(tmp_path.glob("results-*.md"))[0].read_text()
        assert "# Eval Results: test-slug" in content

    def test_results_summary_table_present(self, tmp_path):
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(PASS_RESULT))
        result = run_script(str(result_json), "test-slug", str(tmp_path))
        assert result.returncode == 0, result.stderr
        content = list(tmp_path.glob("results-*.md"))[0].read_text()
        assert "## Results Summary" in content
        assert "| Dimension |" in content

    def test_overall_verdict_pass_in_summary(self, tmp_path):
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(PASS_RESULT))
        result = run_script(str(result_json), "test-slug", str(tmp_path))
        assert result.returncode == 0, result.stderr
        content = list(tmp_path.glob("results-*.md"))[0].read_text()
        assert "**Overall: PASSED**" in content

    def test_overall_verdict_fail_in_summary(self, tmp_path):
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(FAIL_RESULT))
        result = run_script(str(result_json), "test-slug", str(tmp_path))
        assert result.returncode == 0, result.stderr
        content = list(tmp_path.glob("results-*.md"))[0].read_text()
        assert "**Overall: FAILED**" in content

    def test_overall_verdict_partial_in_summary(self, tmp_path):
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(PARTIAL_RESULT))
        result = run_script(str(result_json), "test-slug", str(tmp_path))
        assert result.returncode == 0, result.stderr
        content = list(tmp_path.glob("results-*.md"))[0].read_text()
        assert "**Overall: PARTIAL**" in content

    def test_dimension_rows_in_summary_table(self, tmp_path):
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(PASS_RESULT))
        result = run_script(str(result_json), "test-slug", str(tmp_path))
        assert result.returncode == 0, result.stderr
        content = list(tmp_path.glob("results-*.md"))[0].read_text()
        assert "Functional Correctness" in content
        assert "Style" in content
        assert "PASSED" in content

    def test_failed_dimension_shows_failed(self, tmp_path):
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(FAIL_RESULT))
        result = run_script(str(result_json), "test-slug", str(tmp_path))
        assert result.returncode == 0, result.stderr
        content = list(tmp_path.glob("results-*.md"))[0].read_text()
        assert "FAILED" in content

    def test_detailed_results_section_present(self, tmp_path):
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(PASS_RESULT))
        result = run_script(str(result_json), "test-slug", str(tmp_path))
        assert result.returncode == 0, result.stderr
        content = list(tmp_path.glob("results-*.md"))[0].read_text()
        assert "## Detailed Results" in content

    def test_failure_evidence_in_detailed_results(self, tmp_path):
        """Failure criterion and evidence must appear in Detailed Results section."""
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(FAIL_RESULT))
        result = run_script(str(result_json), "test-slug", str(tmp_path))
        assert result.returncode == 0, result.stderr
        content = list(tmp_path.glob("results-*.md"))[0].read_text()
        assert "cusum() missing docstring" in content


class TestEvalStatusUpdate:
    """eval-status.md must be updated with per-dimension rows."""

    def test_eval_status_file_updated(self, tmp_path):
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(PASS_RESULT))
        eval_status = tmp_path / "eval-status.md"
        result = run_script(str(result_json), "test-slug", str(tmp_path),
                           extra_args=["--eval-status", str(eval_status)])
        assert result.returncode == 0, result.stderr
        assert eval_status.exists()

    def test_eval_status_has_dimension_rows(self, tmp_path):
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(PASS_RESULT))
        eval_status = tmp_path / "eval-status.md"
        result = run_script(str(result_json), "test-slug", str(tmp_path),
                           extra_args=["--eval-status", str(eval_status)])
        assert result.returncode == 0, result.stderr
        content = eval_status.read_text()
        assert "Functional Correctness" in content
        assert "Style" in content

    def test_eval_status_has_pass_status(self, tmp_path):
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(PASS_RESULT))
        eval_status = tmp_path / "eval-status.md"
        result = run_script(str(result_json), "test-slug", str(tmp_path),
                           extra_args=["--eval-status", str(eval_status)])
        assert result.returncode == 0, result.stderr
        content = eval_status.read_text()
        assert "PASS" in content

    def test_eval_status_has_fail_status(self, tmp_path):
        result_json = tmp_path / "eval-result.json"
        result_json.write_text(json.dumps(FAIL_RESULT))
        eval_status = tmp_path / "eval-status.md"
        result = run_script(str(result_json), "test-slug", str(tmp_path),
                           extra_args=["--eval-status", str(eval_status)])
        assert result.returncode == 0, result.stderr
        content = eval_status.read_text()
        assert "FAIL" in content


class TestErrorCases:
    def test_missing_result_json_exits_nonzero(self, tmp_path):
        result = run_script(str(tmp_path / "nonexistent.json"), "test-slug", str(tmp_path))
        assert result.returncode != 0

    def test_malformed_json_exits_nonzero(self, tmp_path):
        result_json = tmp_path / "bad.json"
        result_json.write_text("not valid json {{{")
        result = run_script(str(result_json), "test-slug", str(tmp_path))
        assert result.returncode != 0
