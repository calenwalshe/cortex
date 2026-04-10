"""
Tests for scripts/cortex/generate-eval-plan.py

TDD: these tests are written BEFORE the implementation.
Run: python3 -m pytest test/test_generate_eval_plan.py -v
"""
import subprocess
import sys
import textwrap
import tempfile
import os
from pathlib import Path

SCRIPT = Path(__file__).parent.parent / "scripts" / "cortex" / "generate-eval-plan.py"

KALSHI_PROPOSAL = Path(__file__).parent.parent / "docs/cortex/evals/kalshi-adaptive-loop/eval-proposal.md"


def run_script(proposal_path: str, output_path: str, extra_args=None) -> subprocess.CompletedProcess:
    cmd = [sys.executable, str(SCRIPT), "--proposal", proposal_path, "--output", output_path]
    if extra_args:
        cmd.extend(extra_args)
    return subprocess.run(cmd, capture_output=True, text=True)


# ---------------------------------------------------------------------------
# Fixture: a minimal proposal with a mix of EXCLUDED and INCLUDED dimensions
# ---------------------------------------------------------------------------
MINIMAL_PROPOSAL = textwrap.dedent("""\
    # Eval Proposal: test-slug

    **Slug:** test-slug
    **Timestamp:** 20260410T000000Z
    **Status:** draft

    ---

    ## Proposed Dimensions

    ### 1. Functional Correctness
    **Applies because:** Always included. Core logic under test.
    **approval_required:** false

    ### 2. Regression
    **Applies because:** EXCLUDED. Greenfield — no prior code.

    ### 3. Style
    **Applies because:** INCLUDED. Code style matters.
    **approval_required:** false

    ### 4. UX/Taste
    **Applies because:** EXCLUDED. No user-facing output.

    ---

    ## Fixtures

    ### Fixtures: Functional Correctness
    - test/test_core.py (10 tests)
    - Known-answer cases

    ### Fixtures: Regression
    - N/A (excluded)

    ### Fixtures: Style
    - scripts/myscript.py

    ### Fixtures: UX/Taste
    - N/A (excluded)

    ---

    ## Rubrics

    ### Rubric: Functional Correctness
    - All tests pass

    ### Rubric: Style
    - Docstrings present

    ---

    ## Thresholds

    ### Threshold: Functional Correctness
    **Pass:** All 10 tests pass.
    **Fail:** Any test failure.

    ### Threshold: Regression
    **Pass:** N/A.
    **Fail:** N/A.

    ### Threshold: Style
    **Pass:** All public APIs documented.
    **Fail:** Public function without docstring.

    ### Threshold: UX/Taste
    **Pass:** N/A.
    **Fail:** N/A.

    ---

    ## Failure Taxonomy

    | Failure Category | Severity | Description | Repair Path |
    |-----------------|----------|-------------|-------------|
    | Test failure | P0 | Any test fails | Fix code |
    | Missing docstring | P2 | Undocumented function | Add docstring |

    ---

    ## Document-Level Approval Flag

    **approval_required:** false
    **Approval Status:** approved
""")

PROPOSAL_WITH_RUN_INSTRUCTIONS = textwrap.dedent("""\
    # Eval Proposal: slug-with-ri

    **Slug:** slug-with-ri
    **Timestamp:** 20260410T000000Z
    **Status:** draft

    ---

    ## Proposed Dimensions

    ### 1. Functional Correctness
    **Applies because:** Always included.
    **approval_required:** false

    ---

    ## Fixtures

    ### Fixtures: Functional Correctness
    - test/test_func.py

    ---

    ## Rubrics

    ### Rubric: Functional Correctness
    - All tests pass

    ---

    ## Thresholds

    ### Threshold: Functional Correctness
    **Pass:** All tests pass.
    **Fail:** Any failure.

    ---

    ## Failure Taxonomy

    | Failure Category | Severity | Description | Repair Path |
    |-----------------|----------|-------------|-------------|
    | Test failure | P0 | Any test fails | Fix code |

    ---

    ## Run Instructions

    1. Run the tests:
       ```bash
       python3 -m pytest test/test_func.py -v
       ```

    2. Check imports:
       ```bash
       python3 -c "import mymodule; print('OK')"
       ```

    ---

    ## Document-Level Approval Flag

    **approval_required:** false
    **Approval Status:** approved
""")


class TestGenerateEvalPlanExcludedFiltering:
    """EXCLUDED dimensions must not appear in the output plan."""

    def test_excluded_dimensions_not_in_approved_list(self, tmp_path):
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        # Regression and UX/Taste are EXCLUDED — must not appear in Approved Dimensions
        approved_section = content.split("## Approved Dimensions")[1].split("##")[0]
        assert "Regression" not in approved_section
        assert "UX/Taste" not in approved_section

    def test_included_dimensions_in_approved_list(self, tmp_path):
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        approved_section = content.split("## Approved Dimensions")[1].split("##")[0]
        assert "Functional Correctness" in approved_section or "Functional correctness" in approved_section
        assert "Style" in approved_section

    def test_kalshi_three_approved_dimensions(self, tmp_path):
        """Regression test: kalshi-adaptive-loop proposal → 3 approved dimensions."""
        output = tmp_path / "eval-plan.md"
        result = run_script(str(KALSHI_PROPOSAL), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        approved_section = content.split("## Approved Dimensions")[1].split("##")[0]
        # Functional Correctness, Integration, Style
        assert "Functional" in approved_section
        assert "Integration" in approved_section
        assert "Style" in approved_section
        # Excluded: Regression, Safety/Security, Performance, Resilience, UX/Taste
        assert "Regression" not in approved_section
        assert "Safety" not in approved_section
        assert "Performance" not in approved_section
        assert "Resilience" not in approved_section
        assert "UX/Taste" not in approved_section


class TestFixturesAndThresholds:
    """Fixtures and thresholds for approved dimensions must be present; excluded dimensions' fixtures/thresholds must be absent."""

    def test_approved_fixtures_present(self, tmp_path):
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "Fixtures: Functional Correctness" in content
        assert "Fixtures: Style" in content
        # Excluded fixtures must not appear
        assert "Fixtures: Regression" not in content
        assert "Fixtures: UX/Taste" not in content

    def test_approved_thresholds_present(self, tmp_path):
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "Threshold: Functional Correctness" in content
        assert "Threshold: Style" in content
        # Excluded thresholds must not appear
        assert "Threshold: Regression" not in content
        assert "Threshold: UX/Taste" not in content

    def test_fixture_content_verbatim(self, tmp_path):
        """Fixture content must be copied verbatim, not paraphrased."""
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        # Original fixture text must appear unchanged
        assert "test/test_core.py (10 tests)" in content
        assert "Known-answer cases" in content


class TestRemovedSections:
    """Rubrics and Failure Taxonomy sections must NOT appear in output."""

    def test_rubrics_removed(self, tmp_path):
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "## Rubrics" not in content
        assert "### Rubric:" not in content

    def test_failure_taxonomy_removed(self, tmp_path):
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "## Failure Taxonomy" not in content
        assert "Failure Category" not in content

    def test_document_level_approval_flag_removed(self, tmp_path):
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "Document-Level Approval Flag" not in content


class TestRunInstructions:
    """Run Instructions: preserved if present in proposal, absent if not."""

    def test_run_instructions_preserved_when_present(self, tmp_path):
        proposal = tmp_path / "proposal.md"
        proposal.write_text(PROPOSAL_WITH_RUN_INSTRUCTIONS)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "## Run Instructions" in content
        assert "python3 -m pytest test/test_func.py -v" in content

    def test_run_instructions_absent_when_not_in_proposal(self, tmp_path):
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "## Run Instructions" not in content


class TestOutputStructure:
    """Output file structure and header fields."""

    def test_output_has_eval_plan_header(self, tmp_path):
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "# Eval Plan:" in content

    def test_slug_in_header(self, tmp_path):
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "test-slug" in content

    def test_approved_dimensions_section_present(self, tmp_path):
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "## Approved Dimensions" in content

    def test_results_placeholder_present(self, tmp_path):
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        content = output.read_text()
        assert "## Results" in content

    def test_overwrite_guard_blocks_approved_proposal(self, tmp_path):
        """If output already exists and proposal Approval Status is 'approved', script must refuse to overwrite."""
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        # First write
        result = run_script(str(proposal), str(output))
        assert result.returncode == 0, result.stderr
        # Second write — should be blocked (already approved plan exists)
        result2 = run_script(str(proposal), str(output))
        assert result2.returncode != 0, "Script must refuse to overwrite existing plan without --force"
        assert "already exists" in result2.stderr.lower() or "overwrite" in result2.stderr.lower() or "force" in result2.stderr.lower()

    def test_force_flag_allows_overwrite(self, tmp_path):
        """--force flag allows overwriting an existing plan."""
        proposal = tmp_path / "proposal.md"
        proposal.write_text(MINIMAL_PROPOSAL)
        output = tmp_path / "eval-plan.md"
        run_script(str(proposal), str(output))
        result = run_script(str(proposal), str(output), extra_args=["--force"])
        assert result.returncode == 0, result.stderr

    def test_missing_proposal_exits_nonzero(self, tmp_path):
        output = tmp_path / "eval-plan.md"
        result = run_script(str(tmp_path / "nonexistent.md"), str(output))
        assert result.returncode != 0
