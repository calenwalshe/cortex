#!/usr/bin/env python3
"""Tests for cortex-judge.py."""

import json
import os
import subprocess
import sys
import tempfile

import pytest

SCRIPTS_DIR = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'cortex')
JUDGE_SCRIPT = os.path.join(SCRIPTS_DIR, 'cortex-judge.py')

# Import judge module for unit tests
sys.path.insert(0, SCRIPTS_DIR)


class TestRubricParser:
    def test_parse_rubric_file(self):
        from importlib import import_module
        # Use importlib to handle the hyphen issue — just test via subprocess
        result = subprocess.run(
            [sys.executable, '-c', '''
import sys; sys.path.insert(0, "scripts/cortex")
# Inline import since module name has hyphens
import importlib.util
spec = importlib.util.spec_from_file_location("judge", "scripts/cortex/cortex-judge.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

rubric = mod.parse_rubric("docs/cortex/rubrics/semantic-retrieval/relevance.rubric.md")
assert rubric is not None
assert rubric["validator"] == "Review that retrieval returns semantically relevant facts"
assert rubric["pass_threshold"] == 3
assert rubric["max_score"] == 6
assert len(rubric["criteria"]) == 3
assert rubric["criteria"][0]["name"] == "relevance"
assert rubric["criteria"][0]["range"] == [0, 3]
print("OK")
'''], capture_output=True, text=True)
        assert result.stdout.strip() == 'OK', f'Failed: {result.stderr}'

    def test_parse_degradation_rubric(self):
        result = subprocess.run(
            [sys.executable, '-c', '''
import importlib.util
spec = importlib.util.spec_from_file_location("judge", "scripts/cortex/cortex-judge.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

rubric = mod.parse_rubric("docs/cortex/rubrics/semantic-retrieval/degradation.rubric.md")
assert rubric is not None
assert rubric["pass_threshold"] == 3
assert rubric["max_score"] == 5
assert len(rubric["criteria"]) == 4
print("OK")
'''], capture_output=True, text=True)
        assert result.stdout.strip() == 'OK', f'Failed: {result.stderr}'


class TestContractParser:
    def test_extract_judgment_validators(self):
        result = subprocess.run(
            [sys.executable, '-c', '''
import importlib.util
spec = importlib.util.spec_from_file_location("judge", "scripts/cortex/cortex-judge.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

validators = mod.extract_judgment_validators(
    "docs/cortex/contracts/semantic-retrieval/contract-001.md")
assert len(validators) == 2
assert "semantically relevant" in validators[0]
assert "graceful degradation" in validators[1]
print("OK")
'''], capture_output=True, text=True)
        assert result.stdout.strip() == 'OK', f'Failed: {result.stderr}'


class TestDefaultRubric:
    def test_generates_default_rubric(self):
        result = subprocess.run(
            [sys.executable, '-c', '''
import importlib.util
spec = importlib.util.spec_from_file_location("judge", "scripts/cortex/cortex-judge.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

rubric = mod.generate_default_rubric("Some validator text")
assert rubric["validator"] == "Some validator text"
assert len(rubric["criteria"]) == 2
assert rubric["_default"] is True
assert rubric["pass_threshold"] == 3
print("OK")
'''], capture_output=True, text=True)
        assert result.stdout.strip() == 'OK', f'Failed: {result.stderr}'


class TestCalibration:
    def test_save_and_load_calibration(self, tmp_path):
        result = subprocess.run(
            [sys.executable, '-c', f'''
import os, json
os.environ["HOME"] = "{tmp_path}"

import importlib.util
spec = importlib.util.spec_from_file_location("judge", "scripts/cortex/cortex-judge.py")
mod = importlib.util.module_from_spec(spec)
mod.CALIBRATION_DIR = os.path.join("{tmp_path}", ".cortex", "calibration")
spec.loader.exec_module(mod)

# Reassign after exec
mod.CALIBRATION_DIR = os.path.join("{tmp_path}", ".cortex", "calibration")

entry = {{"timestamp": "test", "rubric_hash": "abc123", "human_correction": {{"relevance": 1}}}}
mod.save_calibration("abc123", entry)

loaded = mod.load_calibration("abc123")
assert len(loaded) == 1
assert loaded[0]["human_correction"]["relevance"] == 1
print("OK")
'''], capture_output=True, text=True)
        assert result.stdout.strip() == 'OK', f'Failed: {result.stderr}'


class TestJudgeRun:
    @pytest.fixture(autouse=True)
    def _check_api_key(self):
        if not os.environ.get('ANTHROPIC_API_KEY'):
            pytest.skip('ANTHROPIC_API_KEY not set')

    def test_run_produces_json_output(self):
        result = subprocess.run(
            [sys.executable, JUDGE_SCRIPT, 'run', 'semantic-retrieval'],
            capture_output=True, text=True, timeout=60)
        assert result.returncode == 0

        results = json.loads(result.stdout)
        assert isinstance(results, list)
        assert len(results) == 2

    def test_results_have_required_fields(self):
        result = subprocess.run(
            [sys.executable, JUDGE_SCRIPT, 'run', 'semantic-retrieval'],
            capture_output=True, text=True, timeout=60)
        results = json.loads(result.stdout)

        for r in results:
            assert 'validator' in r
            assert 'verdict' in r
            assert 'status' in r
            assert r['status'] in ('PASS', 'FAIL', 'FLAG')
            v = r['verdict']
            assert 'pass' in v
            assert 'confidence' in v
            assert 'reasoning' in v

    def test_report_generated(self):
        subprocess.run(
            [sys.executable, JUDGE_SCRIPT, 'run', 'semantic-retrieval'],
            capture_output=True, text=True, timeout=60)

        report = 'docs/cortex/evals/semantic-retrieval/judge-report.md'
        assert os.path.exists(report)
        with open(report) as f:
            content = f.read()
        assert '# Judge Report' in content
        assert 'semantic-retrieval' in content

    def test_errors_without_api_key(self):
        env = os.environ.copy()
        env.pop('ANTHROPIC_API_KEY', None)
        result = subprocess.run(
            [sys.executable, JUDGE_SCRIPT, 'run', 'semantic-retrieval'],
            capture_output=True, text=True, env=env, timeout=10)
        assert result.returncode == 1
        assert 'ANTHROPIC_API_KEY' in result.stderr
