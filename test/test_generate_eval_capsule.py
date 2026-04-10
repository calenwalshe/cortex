"""
Tests for scripts/cortex/generate-eval-capsule.py

TDD: written BEFORE implementation.
Run: python3 -m pytest test/test_generate_eval_capsule.py -v
"""
import subprocess
import sys
import textwrap
import tempfile
import os
from pathlib import Path

SCRIPT = Path(__file__).parent.parent / "scripts" / "cortex" / "generate-eval-capsule.py"
KALSHI_PLAN = Path(__file__).parent.parent / "docs/cortex/evals/kalshi-adaptive-loop/eval-plan.md"


def run_script(eval_plan: str, output: str, slug: str = None, extra_args=None) -> subprocess.CompletedProcess:
    cmd = [sys.executable, str(SCRIPT), "--eval-plan", eval_plan, "--output", output]
    if slug:
        cmd += ["--slug", slug]
    if extra_args:
        cmd.extend(extra_args)
    return subprocess.run(cmd, capture_output=True, text=True)


# ---------------------------------------------------------------------------
# Minimal eval plan for fixture use
# ---------------------------------------------------------------------------
MINIMAL_PLAN = textwrap.dedent("""\
    # Eval Plan: test-slug

    **Slug:** test-slug
    **Timestamp:** 20260410T000000Z
    **Approved By:** auto-approved (no approval_required dimensions)
    **Approved At:** 20260410T000000Z

    ---

    ## Approved Dimensions

    - Functional Correctness

    ---

    ## Fixtures Per Dimension

    ### Fixtures: Functional Correctness
    - test/test_core.py

    ---

    ## Thresholds Per Dimension

    ### Threshold: Functional Correctness
    **Pass:** All tests pass.
    **Fail:** Any test failure.

    ---

    ## Run Instructions

    1. Run tests:
       ```bash
       python3 -m pytest test/test_core.py -v
       ```

    ---

    ## Results

    <!-- Results written to docs/cortex/evals/test-slug/results-<timestamp>.md -->
""")

PLAN_WITHOUT_REJECTION_RULES = MINIMAL_PLAN  # The base plan has no rejection rules section

PLAN_WITH_REJECTION_RULES = MINIMAL_PLAN + textwrap.dedent("""\

    ## Rejection Rules

    1. If any test exits non-zero, overall_verdict MUST be "fail"
    2. If any deliverable file is missing, overall_verdict MUST be "fail"
    3. If any public function lacks a docstring, Style verdict MUST be "fail"
""")


class TestCapsuleStructure:
    """Capsule output must have required sections."""

    def test_capsule_has_slug_section(self, tmp_path):
        plan = tmp_path / "eval-plan.md"
        plan.write_text(PLAN_WITH_REJECTION_RULES)
        output = tmp_path / "capsule.md"
        result = run_script(str(plan), str(output), slug="test-slug")
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "test-slug" in content

    def test_capsule_has_approved_dimensions(self, tmp_path):
        plan = tmp_path / "eval-plan.md"
        plan.write_text(PLAN_WITH_REJECTION_RULES)
        output = tmp_path / "capsule.md"
        result = run_script(str(plan), str(output), slug="test-slug")
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "Approved Dimensions" in content
        assert "Functional Correctness" in content

    def test_capsule_has_fixtures_section(self, tmp_path):
        plan = tmp_path / "eval-plan.md"
        plan.write_text(PLAN_WITH_REJECTION_RULES)
        output = tmp_path / "capsule.md"
        result = run_script(str(plan), str(output), slug="test-slug")
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "Fixtures" in content

    def test_capsule_has_thresholds_section(self, tmp_path):
        plan = tmp_path / "eval-plan.md"
        plan.write_text(PLAN_WITH_REJECTION_RULES)
        output = tmp_path / "capsule.md"
        result = run_script(str(plan), str(output), slug="test-slug")
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "Threshold" in content

    def test_capsule_has_rejection_rules_section(self, tmp_path):
        plan = tmp_path / "eval-plan.md"
        plan.write_text(PLAN_WITH_REJECTION_RULES)
        output = tmp_path / "capsule.md"
        result = run_script(str(plan), str(output), slug="test-slug")
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "## Rejection Rules" in content


class TestRejectionRulesValidation:
    """generate-eval-capsule.py must validate the Rejection Rules section."""

    def test_missing_rejection_rules_fails(self, tmp_path):
        """Plan without ## Rejection Rules section must cause non-zero exit."""
        plan = tmp_path / "eval-plan.md"
        plan.write_text(PLAN_WITHOUT_REJECTION_RULES)
        output = tmp_path / "capsule.md"
        result = run_script(str(plan), str(output), slug="test-slug")
        assert result.returncode != 0
        assert "rejection rules" in result.stderr.lower() or "rejection" in result.stderr.lower()

    def test_fewer_than_3_rejection_rules_fails(self, tmp_path):
        """Plan with < 3 rejection rule items must cause non-zero exit."""
        plan_text = MINIMAL_PLAN + textwrap.dedent("""\

            ## Rejection Rules

            1. If any test exits non-zero, overall_verdict MUST be "fail"
            2. If any deliverable file is missing, overall_verdict MUST be "fail"
        """)
        plan = tmp_path / "eval-plan.md"
        plan.write_text(plan_text)
        output = tmp_path / "capsule.md"
        result = run_script(str(plan), str(output), slug="test-slug")
        assert result.returncode != 0
        assert "3" in result.stderr or "three" in result.stderr.lower() or "rejection" in result.stderr.lower()

    def test_exactly_3_rejection_rules_passes(self, tmp_path):
        plan = tmp_path / "eval-plan.md"
        plan.write_text(PLAN_WITH_REJECTION_RULES)
        output = tmp_path / "capsule.md"
        result = run_script(str(plan), str(output), slug="test-slug")
        assert result.returncode == 0, result.stderr

    def test_more_than_3_rejection_rules_passes(self, tmp_path):
        plan_text = MINIMAL_PLAN + textwrap.dedent("""\

            ## Rejection Rules

            1. If any test exits non-zero, overall_verdict MUST be "fail"
            2. If any deliverable file is missing, overall_verdict MUST be "fail"
            3. If any public function lacks a docstring, Style verdict MUST be "fail"
            4. If the config file fails yaml.safe_load, overall_verdict MUST be "fail"
        """)
        plan = tmp_path / "eval-plan.md"
        plan.write_text(plan_text)
        output = tmp_path / "capsule.md"
        result = run_script(str(plan), str(output), slug="test-slug")
        assert result.returncode == 0, result.stderr


class TestDeliverableFiles:
    """Deliverable files referenced in plan's Fixtures should be embedded in capsule."""

    def test_referenced_test_file_content_included(self, tmp_path):
        """A test file referenced in fixtures should have its content embedded."""
        # Create a synthetic test file
        test_file = tmp_path / "test_core.py"
        test_file.write_text("def test_example():\n    assert 1 + 1 == 2\n")

        plan_text = textwrap.dedent(f"""\
            # Eval Plan: test-slug

            **Slug:** test-slug
            **Timestamp:** 20260410T000000Z
            **Approved By:** auto-approved
            **Approved At:** 20260410T000000Z

            ---

            ## Approved Dimensions

            - Functional Correctness

            ---

            ## Fixtures Per Dimension

            ### Fixtures: Functional Correctness
            - {test_file}

            ---

            ## Thresholds Per Dimension

            ### Threshold: Functional Correctness
            **Pass:** All tests pass.
            **Fail:** Any failure.

            ---

            ## Results

            <!-- placeholder -->

            ## Rejection Rules

            1. If any test exits non-zero, overall_verdict MUST be "fail"
            2. If any deliverable file is missing, overall_verdict MUST be "fail"
            3. If any import fails, overall_verdict MUST be "fail"
        """)
        plan = tmp_path / "eval-plan.md"
        plan.write_text(plan_text)
        output = tmp_path / "capsule.md"
        result = run_script(str(plan), str(output), slug="test-slug")
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "test_example" in content

    def test_large_file_truncated(self, tmp_path):
        """Non-test files with >200 lines should be truncated with a marker."""
        # Create a file with 300 lines
        large_file = tmp_path / "bigmodule.py"
        lines = [f"line_{i} = {i}\n" for i in range(300)]
        large_file.write_text("".join(lines))

        plan_text = textwrap.dedent(f"""\
            # Eval Plan: test-slug

            **Slug:** test-slug
            **Timestamp:** 20260410T000000Z
            **Approved By:** auto-approved
            **Approved At:** 20260410T000000Z

            ---

            ## Approved Dimensions

            - Style

            ---

            ## Fixtures Per Dimension

            ### Fixtures: Style
            - {large_file}

            ---

            ## Thresholds Per Dimension

            ### Threshold: Style
            **Pass:** All public APIs documented.
            **Fail:** Any missing docstring.

            ---

            ## Results

            <!-- placeholder -->

            ## Rejection Rules

            1. If any test exits non-zero, overall_verdict MUST be "fail"
            2. If any deliverable file is missing, overall_verdict MUST be "fail"
            3. If any public function lacks a docstring, Style verdict MUST be "fail"
        """)
        plan = tmp_path / "eval-plan.md"
        plan.write_text(plan_text)
        output = tmp_path / "capsule.md"
        result = run_script(str(plan), str(output), slug="test-slug")
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        # Should not contain line 299 (0-indexed 298)
        assert "line_299" not in content
        # Should contain truncation marker
        assert "truncated" in content.lower()


class TestErrorCases:
    """Error handling for bad inputs."""

    def test_missing_eval_plan_exits_nonzero(self, tmp_path):
        output = tmp_path / "capsule.md"
        result = run_script(str(tmp_path / "nonexistent.md"), str(output), slug="test-slug")
        assert result.returncode != 0

    def test_output_written_to_specified_path(self, tmp_path):
        plan = tmp_path / "eval-plan.md"
        plan.write_text(PLAN_WITH_REJECTION_RULES)
        output = tmp_path / "my-capsule.md"
        result = run_script(str(plan), str(output), slug="test-slug")
        assert result.returncode == 0, result.stderr
        assert output.exists()
