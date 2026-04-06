#!/usr/bin/env python3
"""Tests for cortex-parallel worktree isolation."""

import json
import os
import subprocess
import tempfile

import pytest


@pytest.fixture
def test_repo(tmp_path):
    """Create a temporary git repo for testing worktrees."""
    repo = tmp_path / "test-repo"
    repo.mkdir()
    subprocess.run(['git', 'init'], cwd=str(repo), capture_output=True)
    subprocess.run(['git', 'config', 'user.email', 'test@test.com'], cwd=str(repo), capture_output=True)
    subprocess.run(['git', 'config', 'user.name', 'Test'], cwd=str(repo), capture_output=True)
    # Create initial commit
    (repo / "README.md").write_text("# Test")
    (repo / ".gitignore").write_text(".cortex/\n.claude/worktrees/\n")
    subprocess.run(['git', 'add', '-A'], cwd=str(repo), capture_output=True)
    subprocess.run(['git', 'commit', '-m', 'init'], cwd=str(repo), capture_output=True)
    return repo


class TestWorktreeCreation:
    def test_create_worktree(self, test_repo):
        """Can create a worktree with a workspace branch."""
        wt_dir = test_repo / ".claude" / "worktrees" / "test-slug"
        wt_dir.parent.mkdir(parents=True, exist_ok=True)
        result = subprocess.run(
            ['git', 'worktree', 'add', str(wt_dir), '-b', 'workspace/test-slug'],
            cwd=str(test_repo), capture_output=True, text=True)
        assert result.returncode == 0
        assert wt_dir.exists()
        assert (wt_dir / "README.md").exists()

    def test_worktree_has_independent_working_tree(self, test_repo):
        """Changes in worktree don't affect main."""
        wt_dir = test_repo / ".claude" / "worktrees" / "test-slug"
        wt_dir.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ['git', 'worktree', 'add', str(wt_dir), '-b', 'workspace/test-slug'],
            cwd=str(test_repo), capture_output=True)

        # Create a file in worktree
        (wt_dir / "new-file.txt").write_text("worktree only")
        assert (wt_dir / "new-file.txt").exists()
        assert not (test_repo / "new-file.txt").exists()

    def test_gitignored_dirs_are_per_worktree(self, test_repo):
        """Gitignored .cortex/ is independent per worktree."""
        wt_dir = test_repo / ".claude" / "worktrees" / "test-slug"
        wt_dir.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ['git', 'worktree', 'add', str(wt_dir), '-b', 'workspace/test-slug'],
            cwd=str(test_repo), capture_output=True)

        # Create .cortex/ in main
        main_cortex = test_repo / ".cortex"
        main_cortex.mkdir()
        (main_cortex / "state.json").write_text('{"slug": "main-slug"}')

        # Create .cortex/ in worktree
        wt_cortex = wt_dir / ".cortex"
        wt_cortex.mkdir()
        (wt_cortex / "state.json").write_text('{"slug": "wt-slug"}')

        # Verify they're independent
        main_state = json.loads((main_cortex / "state.json").read_text())
        wt_state = json.loads((wt_cortex / "state.json").read_text())
        assert main_state["slug"] == "main-slug"
        assert wt_state["slug"] == "wt-slug"

    def test_cortex_state_initialization(self, test_repo):
        """Cortex state.json can be initialized in a worktree."""
        wt_dir = test_repo / ".claude" / "worktrees" / "my-feature"
        wt_dir.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ['git', 'worktree', 'add', str(wt_dir), '-b', 'workspace/my-feature'],
            cwd=str(test_repo), capture_output=True)

        cortex_dir = wt_dir / ".cortex"
        cortex_dir.mkdir()
        state = {
            "slug": "my-feature",
            "mode": "clarify",
            "approval_status": "pending",
            "active_contract": None,
            "artifacts": [],
            "approvals": {"contract": False, "evals": False},
            "gates": {
                "clarify_complete": False,
                "research_complete": False,
                "spec_complete": False,
                "contract_approved": False
            }
        }
        (cortex_dir / "state.json").write_text(json.dumps(state, indent=2))

        loaded = json.loads((cortex_dir / "state.json").read_text())
        assert loaded["slug"] == "my-feature"
        assert loaded["mode"] == "clarify"

    def test_worktree_cleanup(self, test_repo):
        """Worktrees can be removed cleanly."""
        wt_dir = test_repo / ".claude" / "worktrees" / "cleanup-test"
        wt_dir.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ['git', 'worktree', 'add', str(wt_dir), '-b', 'workspace/cleanup-test'],
            cwd=str(test_repo), capture_output=True)
        assert wt_dir.exists()

        result = subprocess.run(
            ['git', 'worktree', 'remove', str(wt_dir), '--force'],
            cwd=str(test_repo), capture_output=True, text=True)
        assert result.returncode == 0
        assert not wt_dir.exists()

    def test_multiple_worktrees_coexist(self, test_repo):
        """Multiple worktrees can exist simultaneously with different slugs."""
        wt_base = test_repo / ".claude" / "worktrees"
        wt_base.mkdir(parents=True, exist_ok=True)

        slugs = ["slug-a", "slug-b", "slug-c"]
        for slug in slugs:
            wt_dir = wt_base / slug
            subprocess.run(
                ['git', 'worktree', 'add', str(wt_dir), '-b', f'workspace/{slug}'],
                cwd=str(test_repo), capture_output=True)
            cortex_dir = wt_dir / ".cortex"
            cortex_dir.mkdir()
            (cortex_dir / "state.json").write_text(json.dumps({"slug": slug}))

        # Verify all exist and are independent
        for slug in slugs:
            wt_dir = wt_base / slug
            assert wt_dir.exists()
            state = json.loads((wt_dir / ".cortex" / "state.json").read_text())
            assert state["slug"] == slug

        # List worktrees
        result = subprocess.run(
            ['git', 'worktree', 'list'],
            cwd=str(test_repo), capture_output=True, text=True)
        assert result.returncode == 0
        for slug in slugs:
            assert slug in result.stdout

    def test_commits_in_worktree_visible_from_main(self, test_repo):
        """Commits made in a worktree are visible from the main repo."""
        wt_dir = test_repo / ".claude" / "worktrees" / "commit-test"
        wt_dir.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ['git', 'worktree', 'add', str(wt_dir), '-b', 'workspace/commit-test'],
            cwd=str(test_repo), capture_output=True)

        # Make a commit in the worktree
        (wt_dir / "feature.py").write_text("print('hello')")
        subprocess.run(['git', 'add', 'feature.py'], cwd=str(wt_dir), capture_output=True)
        subprocess.run(['git', 'commit', '-m', 'add feature'],
                       cwd=str(wt_dir), capture_output=True)

        # Verify commit is visible from main repo
        result = subprocess.run(
            ['git', 'log', '--all', '--oneline'],
            cwd=str(test_repo), capture_output=True, text=True)
        assert 'add feature' in result.stdout
