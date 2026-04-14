#!/usr/bin/env python3
"""Tests for communication judge functions in cortex-judge.py."""

import importlib.util
import json
import os
import sys
import tempfile
from unittest.mock import patch, MagicMock

import pytest

SCRIPTS_DIR = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'cortex')


def load_judge_module():
    """Load cortex-judge.py module (handles hyphen in filename)."""
    spec = importlib.util.spec_from_file_location(
        'judge', os.path.join(SCRIPTS_DIR, 'cortex-judge.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


SAMPLE_RUBRIC = {
    'rubric': 'drive-summary',
    'version': 1,
    'surface': 'drive_completion_summary',
    'dimensions': [
        {'name': 'clarity', 'description': 'Single reading comprehension; no ambiguous referents', 'threshold': 3, 'scale': 4},
        {'name': 'actionability', 'description': 'Owner can derive next step without follow-up', 'threshold': 3, 'scale': 4},
        {'name': 'evidence_traceability', 'description': 'Every claim references a specific artifact', 'threshold': 2, 'scale': 4},
        {'name': 'completeness', 'description': 'All 3 formula bullets present', 'threshold': 3, 'scale': 4},
        {'name': 'calibrated_uncertainty', 'description': 'Caveats and open questions preserved', 'threshold': 3, 'scale': 4},
    ],
    'aggregate_threshold': 0.7,
    'rejection_rules': [
        {'dimension': 'calibrated_uncertainty', 'condition': '< 2', 'verdict': 'FAIL',
         'note': 'Applies regardless of aggregate score'},
    ],
}

PASS_SCORES = {
    'clarity': 4,
    'actionability': 4,
    'evidence_traceability': 3,
    'completeness': 4,
    'calibrated_uncertainty': 3,
}

FAIL_SCORES_UNCERTAINTY = {
    'clarity': 4,
    'actionability': 4,
    'evidence_traceability': 4,
    'completeness': 4,
    'calibrated_uncertainty': 1,  # triggers rejection rule
}

FAIL_SCORES_LOW_AGGREGATE = {
    'clarity': 1,
    'actionability': 1,
    'evidence_traceability': 1,
    'completeness': 2,
    'calibrated_uncertainty': 2,
}


class TestBuildCommunicationJudgePrompt:
    def setup_method(self):
        self.mod = load_judge_module()

    def test_prompt_declares_communication_quality_judge(self):
        prompt = self.mod.build_communication_judge_prompt('test message', SAMPLE_RUBRIC)
        assert 'communication quality judge' in prompt.lower()

    def test_prompt_does_not_say_code_quality_judge(self):
        prompt = self.mod.build_communication_judge_prompt('test message', SAMPLE_RUBRIC)
        assert 'code quality judge' not in prompt.lower()

    def test_prompt_includes_all_five_dimensions(self):
        prompt = self.mod.build_communication_judge_prompt('test message', SAMPLE_RUBRIC)
        for dim in ['clarity', 'actionability', 'evidence_traceability',
                    'completeness', 'calibrated_uncertainty']:
            assert dim in prompt, f'Missing dimension: {dim}'

    def test_prompt_includes_rejection_rule(self):
        prompt = self.mod.build_communication_judge_prompt('test message', SAMPLE_RUBRIC)
        assert 'calibrated_uncertainty' in prompt
        assert '< 2' in prompt or 'less than 2' in prompt.lower()

    def test_prompt_includes_message_text(self):
        message = 'The retrieval system is now working. Changes: added caching. Risk: latency.'
        prompt = self.mod.build_communication_judge_prompt(message, SAMPLE_RUBRIC)
        assert message in prompt

    def test_prompt_requests_json_output_with_required_fields(self):
        prompt = self.mod.build_communication_judge_prompt('test message', SAMPLE_RUBRIC)
        assert 'verdict' in prompt
        assert 'per_dimension_scores' in prompt

    def test_prompt_includes_aggregate_threshold(self):
        prompt = self.mod.build_communication_judge_prompt('test message', SAMPLE_RUBRIC)
        assert '0.7' in prompt or '70' in prompt


class TestJudgeCommunicationLogic:
    """Tests for judge_communication() — all mocked, no API calls."""

    def setup_method(self):
        self.mod = load_judge_module()

    def _make_call_judge_response(self, scores, verdict=None):
        """Build a mock call_judge return value from scores dict."""
        if verdict is None:
            # compute aggregate: mean/4.0
            agg = sum(scores.values()) / (len(scores) * 4.0)
            # apply rejection rule
            if scores.get('calibrated_uncertainty', 4) < 2:
                verdict = 'FAIL'
            elif agg >= 0.7:
                verdict = 'PASS'
            else:
                verdict = 'FAIL'
        agg = sum(scores.values()) / (len(scores) * 4.0)
        response = {
            'verdict': verdict,
            'per_dimension_scores': scores,
            'aggregate_score': round(agg, 3),
            'critique': 'Some critique text here.',
        }
        usage = {'input_tokens': 100, 'output_tokens': 50}
        return response, usage

    def _write_rubric_file(self, tmp_path):
        import yaml
        rubric_path = os.path.join(tmp_path, 'drive-summary.yaml')
        with open(rubric_path, 'w') as f:
            yaml.dump(SAMPLE_RUBRIC, f)
        return rubric_path

    def test_pass_verdict_when_aggregate_above_threshold(self, tmp_path):
        rubric_path = self._write_rubric_file(str(tmp_path))
        call_judge_return = self._make_call_judge_response(PASS_SCORES, verdict='PASS')

        with patch.object(self.mod, 'call_judge', return_value=call_judge_return):
            result = self.mod.judge_communication(
                'Good summary', rubric_path, max_retries=3)

        assert result['verdict'] == 'PASS'

    def test_fail_on_calibrated_uncertainty_below_2_regardless_of_aggregate(self, tmp_path):
        """Rejection rule: calibrated_uncertainty < 2 → FAIL regardless of high aggregate."""
        rubric_path = self._write_rubric_file(str(tmp_path))
        # All scores high except calibrated_uncertainty=1
        high_scores_bad_uncertainty = dict(FAIL_SCORES_UNCERTAINTY)
        # judge might return PASS from aggregate, but rejection rule must override
        call_judge_return = self._make_call_judge_response(
            high_scores_bad_uncertainty, verdict='PASS')

        with patch.object(self.mod, 'call_judge', return_value=call_judge_return):
            result = self.mod.judge_communication(
                'Overconfident summary', rubric_path, max_retries=1)

        assert result['verdict'] in ('FAIL', 'ESCALATE'), (
            f"Expected FAIL or ESCALATE due to rejection rule, got {result['verdict']}")

    def test_retry_on_fail(self, tmp_path):
        rubric_path = self._write_rubric_file(str(tmp_path))
        fail_return = self._make_call_judge_response(FAIL_SCORES_LOW_AGGREGATE, verdict='FAIL')
        pass_return = self._make_call_judge_response(PASS_SCORES, verdict='PASS')

        call_count = {'n': 0}
        def mock_call_judge(prompt):
            call_count['n'] += 1
            # First 2 attempts fail (original + 1 rewrite), third passes
            if call_count['n'] <= 2:
                return fail_return
            return pass_return

        with patch.object(self.mod, 'call_judge', side_effect=mock_call_judge):
            result = self.mod.judge_communication('Bad summary', rubric_path, max_retries=3)

        assert call_count['n'] >= 2, 'Should have retried at least once'
        assert result['verdict'] == 'PASS'

    def test_escalation_struct_on_cap_exhaustion(self, tmp_path):
        rubric_path = self._write_rubric_file(str(tmp_path))
        fail_return = self._make_call_judge_response(FAIL_SCORES_LOW_AGGREGATE, verdict='FAIL')

        with patch.object(self.mod, 'call_judge', return_value=fail_return):
            result = self.mod.judge_communication('Always bad', rubric_path, max_retries=3)

        assert result['verdict'] == 'ESCALATE'
        assert 'original_message' in result
        assert 'final_rewrite' in result
        assert 'critique' in result
        assert 'attempts' in result

    def test_writes_jsonl_on_every_attempt(self, tmp_path):
        rubric_path = self._write_rubric_file(str(tmp_path))
        fail_return = self._make_call_judge_response(FAIL_SCORES_LOW_AGGREGATE, verdict='FAIL')

        # Override CALIBRATION_DIR to tmp_path
        orig_dir = self.mod.CALIBRATION_DIR
        self.mod.CALIBRATION_DIR = str(tmp_path)
        try:
            with patch.object(self.mod, 'call_judge', return_value=fail_return):
                self.mod.judge_communication('Always bad', rubric_path, max_retries=3)
        finally:
            self.mod.CALIBRATION_DIR = orig_dir

        # Find JSONL files in tmp_path
        jsonl_files = [f for f in os.listdir(str(tmp_path)) if f.endswith('.jsonl')]
        assert len(jsonl_files) == 1, f'Expected 1 JSONL file, found: {jsonl_files}'

        with open(os.path.join(str(tmp_path), jsonl_files[0])) as f:
            lines = [line.strip() for line in f if line.strip()]
        assert len(lines) == 3, f'Expected 3 JSONL entries (3 attempts), got {len(lines)}'

    def test_jsonl_has_required_fields(self, tmp_path):
        rubric_path = self._write_rubric_file(str(tmp_path))
        fail_return = self._make_call_judge_response(FAIL_SCORES_LOW_AGGREGATE, verdict='FAIL')

        orig_dir = self.mod.CALIBRATION_DIR
        self.mod.CALIBRATION_DIR = str(tmp_path)
        try:
            with patch.object(self.mod, 'call_judge', return_value=fail_return):
                self.mod.judge_communication('Always bad', rubric_path, max_retries=1)
        finally:
            self.mod.CALIBRATION_DIR = orig_dir

        jsonl_files = [f for f in os.listdir(str(tmp_path)) if f.endswith('.jsonl')]
        with open(os.path.join(str(tmp_path), jsonl_files[0])) as f:
            entry = json.loads(f.readline().strip())

        required_fields = [
            'timestamp', 'slug', 'surface', 'judge_model', 'rubric_hash',
            'original_message', 'rewrite_attempt', 'per_dimension_scores',
            'aggregate_score', 'verdict', 'critique', 'rewrite_diff',
            'confidence', 'calibration_corrections_applied',
        ]
        for field in required_fields:
            assert field in entry, f'Missing JSONL field: {field}'

    def test_max_retries_default_is_3(self, tmp_path):
        rubric_path = self._write_rubric_file(str(tmp_path))
        fail_return = self._make_call_judge_response(FAIL_SCORES_LOW_AGGREGATE, verdict='FAIL')

        call_count = {'n': 0}
        def mock_call_judge(prompt):
            call_count['n'] += 1
            return fail_return

        orig_dir = self.mod.CALIBRATION_DIR
        self.mod.CALIBRATION_DIR = str(tmp_path)
        try:
            with patch.object(self.mod, 'call_judge', side_effect=mock_call_judge):
                result = self.mod.judge_communication('Always bad', rubric_path)
        finally:
            self.mod.CALIBRATION_DIR = orig_dir

        assert result['verdict'] == 'ESCALATE'
        assert result['attempts'] == 3
