#!/usr/bin/env python3
"""Tests for cortex-drive policy loop decision table.

Tests the decision logic that determines the next action based on
state.json fields and artifact existence.
"""

import json
import os

import pytest


def decide_next_action(state, artifacts_exist=None, planning_exists=False,
                       gsd_complete=False, validators_pass=None, backlog_items=0,
                       open_impl_questions=False):
    """Pure function implementing the cortex-drive decision table.

    This mirrors the decision table in skills/cortex-drive/SKILL.md.
    Returns (action, row_number, needs_llm).
    """
    if artifacts_exist is None:
        artifacts_exist = {}
    if validators_pass is None:
        validators_pass = None  # None = not run yet

    slug = state.get('slug')
    mode = state.get('mode', 'done')
    gates = state.get('gates', {})
    approval = state.get('approval_status', 'pending')
    contract = state.get('active_contract')
    repair_budget = state.get('repair_budget', 3)

    # Row 1: No slug, backlog has items
    if slug is None and backlog_items > 0:
        return ('clarify_from_backlog', 1, True)

    # Row 2: Clarify complete → research concept
    if mode == 'clarify' and gates.get('clarify_complete'):
        return ('research_concept', 2, False)

    # Row 3: Research done, open impl questions
    if mode == 'research' and artifacts_exist.get('research_dossier') and open_impl_questions:
        return ('research_implementation', 3, True)

    # Row 4: Research complete → spec
    if mode == 'research' and gates.get('research_complete'):
        return ('spec', 4, False)

    # Row 5: Spec complete, approved → bridge
    if mode == 'spec' and gates.get('spec_complete') and approval == 'approved':
        return ('bridge', 5, False)

    # Row 6: Spec complete, pending, auto-approve gate off → auto-approve + bridge
    if mode == 'spec' and approval == 'pending' and not gates.get('contract_approval', True):
        return ('auto_approve_bridge', 6, False)

    # Row 7: Spec complete, pending, approval gate on → stop
    if mode == 'spec' and approval == 'pending' and gates.get('contract_approval', True):
        return ('stop_human_approval', 7, False)

    # Row 8: Planning exists, GSD not complete → gsd:drive
    if planning_exists and not gsd_complete:
        return ('gsd_drive', 8, False)

    # Row 9: GSD complete, validators exist but not run
    if gsd_complete and validators_pass is None:
        return ('run_validators', 9, False)

    # Row 10: Validators pass → close
    if validators_pass is True:
        return ('close', 10, False)

    # Row 11: Validators fail, budget > 0
    if validators_pass is False and repair_budget > 0:
        return ('repair', 11, False)

    # Row 12: Validators fail, budget exhausted
    if validators_pass is False and repair_budget <= 0:
        return ('stop_repair_exhausted', 12, False)

    # Row 13: Done
    if mode == 'done' and slug is None:
        return ('done', 13, False)

    return ('unknown', 0, False)


class TestDecisionTable:
    """Test every row of the decision table."""

    def test_row1_backlog_to_clarify(self):
        state = {'slug': None, 'mode': 'done', 'gates': {}}
        action, row, llm = decide_next_action(state, backlog_items=3)
        assert row == 1
        assert action == 'clarify_from_backlog'
        assert llm is True

    def test_row2_clarify_to_research(self):
        state = {'slug': 'test', 'mode': 'clarify',
                 'gates': {'clarify_complete': True}}
        action, row, llm = decide_next_action(state)
        assert row == 2
        assert action == 'research_concept'
        assert llm is False

    def test_row3_research_escalation(self):
        state = {'slug': 'test', 'mode': 'research',
                 'gates': {'research_complete': False}}
        action, row, llm = decide_next_action(
            state, artifacts_exist={'research_dossier': True},
            open_impl_questions=True)
        assert row == 3
        assert action == 'research_implementation'
        assert llm is True

    def test_row4_research_to_spec(self):
        state = {'slug': 'test', 'mode': 'research',
                 'gates': {'research_complete': True}}
        action, row, llm = decide_next_action(state)
        assert row == 4
        assert action == 'spec'
        assert llm is False

    def test_row5_spec_approved_to_bridge(self):
        state = {'slug': 'test', 'mode': 'spec',
                 'gates': {'spec_complete': True},
                 'approval_status': 'approved'}
        action, row, llm = decide_next_action(state)
        assert row == 5
        assert action == 'bridge'

    def test_row6_auto_approve(self):
        state = {'slug': 'test', 'mode': 'spec',
                 'gates': {'spec_complete': True, 'contract_approval': False},
                 'approval_status': 'pending'}
        action, row, llm = decide_next_action(state)
        assert row == 6
        assert action == 'auto_approve_bridge'

    def test_row7_stop_for_human_approval(self):
        state = {'slug': 'test', 'mode': 'spec',
                 'gates': {'spec_complete': True, 'contract_approval': True},
                 'approval_status': 'pending'}
        action, row, llm = decide_next_action(state)
        assert row == 7
        assert action == 'stop_human_approval'

    def test_row8_gsd_drive(self):
        state = {'slug': 'test', 'mode': 'execute', 'gates': {}}
        action, row, llm = decide_next_action(state, planning_exists=True)
        assert row == 8
        assert action == 'gsd_drive'

    def test_row9_run_validators(self):
        state = {'slug': 'test', 'mode': 'execute', 'gates': {}}
        action, row, llm = decide_next_action(
            state, planning_exists=True, gsd_complete=True)
        assert row == 9
        assert action == 'run_validators'

    def test_row10_validators_pass_close(self):
        state = {'slug': 'test', 'mode': 'execute', 'gates': {}}
        action, row, llm = decide_next_action(
            state, planning_exists=True, gsd_complete=True, validators_pass=True)
        assert row == 10
        assert action == 'close'

    def test_row11_validators_fail_repair(self):
        state = {'slug': 'test', 'mode': 'execute', 'gates': {},
                 'repair_budget': 2}
        action, row, llm = decide_next_action(
            state, planning_exists=True, gsd_complete=True, validators_pass=False)
        assert row == 11
        assert action == 'repair'

    def test_row12_repair_exhausted(self):
        state = {'slug': 'test', 'mode': 'execute', 'gates': {},
                 'repair_budget': 0}
        action, row, llm = decide_next_action(
            state, planning_exists=True, gsd_complete=True, validators_pass=False)
        assert row == 12
        assert action == 'stop_repair_exhausted'

    def test_row13_done(self):
        state = {'slug': None, 'mode': 'done', 'gates': {}}
        action, row, llm = decide_next_action(state)
        assert row == 13
        assert action == 'done'


class TestSafetyProperties:
    """Test safety invariants of the decision table."""

    def test_only_two_rows_need_llm(self):
        """Only rows 1 and 3 should need LLM reasoning."""
        llm_rows = []
        # Test all rows
        test_cases = [
            ({'slug': None, 'mode': 'done', 'gates': {}}, {'backlog_items': 3}),
            ({'slug': 'x', 'mode': 'clarify', 'gates': {'clarify_complete': True}}, {}),
            ({'slug': 'x', 'mode': 'research', 'gates': {}},
             {'artifacts_exist': {'research_dossier': True}, 'open_impl_questions': True}),
            ({'slug': 'x', 'mode': 'research', 'gates': {'research_complete': True}}, {}),
        ]
        for state, kwargs in test_cases:
            _, row, llm = decide_next_action(state, **kwargs)
            if llm:
                llm_rows.append(row)
        assert llm_rows == [1, 3], f"LLM rows should be [1, 3], got {llm_rows}"

    def test_no_action_modifies_state_directly(self):
        """Decision function is pure — it returns an action name, never modifies state."""
        state = {'slug': 'test', 'mode': 'clarify',
                 'gates': {'clarify_complete': True}}
        original = json.dumps(state)
        decide_next_action(state)
        assert json.dumps(state) == original

    def test_unknown_state_returns_safely(self):
        """Unrecognized state combinations return 'unknown', not crash."""
        state = {'slug': 'test', 'mode': 'weird_mode', 'gates': {}}
        action, row, _ = decide_next_action(state)
        assert action == 'unknown'
        assert row == 0


class TestSessionReplay:
    """Replay this session's slug transitions through the decision table."""

    def test_semantic_retrieval_path(self):
        """semantic-retrieval followed: clarify → research → spec → execute → close."""
        transitions = [
            ({'slug': 'sr', 'mode': 'clarify', 'gates': {'clarify_complete': True}},
             'research_concept'),
            ({'slug': 'sr', 'mode': 'research', 'gates': {'research_complete': True}},
             'spec'),
            ({'slug': 'sr', 'mode': 'spec', 'gates': {'spec_complete': True},
              'approval_status': 'approved'}, 'bridge'),
        ]
        for state, expected_action in transitions:
            action, _, _ = decide_next_action(state)
            assert action == expected_action, \
                f"Expected {expected_action} for state {state}, got {action}"

    def test_done_state_terminates(self):
        """After close, the loop should terminate."""
        state = {'slug': None, 'mode': 'done', 'gates': {}}
        action, _, _ = decide_next_action(state, backlog_items=0)
        assert action == 'done'
