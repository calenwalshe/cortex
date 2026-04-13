"""
Unit tests for cortex-vault-extractor.py

TDD: RED phase — these tests are written before the production code.

Coverage:
  - Artifact type detection (all 4 cases including ValueError)
  - Idempotency guard (skip add_fact when duplicate key exists)
  - Soft-fail on missing vault (ImportError → logged warning, no exception)
  - add_fact() called with correct fields for each category
"""

import importlib.util
import os
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, call, patch

# ---------------------------------------------------------------------------
# Helper: load the module from path (not importable as a package yet)
# ---------------------------------------------------------------------------

_EXTRACTOR_PATH = Path(__file__).parent.parent / "scripts" / "cortex" / "cortex-vault-extractor.py"


def _load_extractor():
    """Dynamically load the extractor module so tests can import it regardless
    of whether it is on sys.path."""
    spec = importlib.util.spec_from_file_location("cortex_vault_extractor", _EXTRACTOR_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# ---------------------------------------------------------------------------
# Artifact-type detection tests (truth table)
# ---------------------------------------------------------------------------

class TestArtifactTypeDetection(unittest.TestCase):
    """Path-pattern truth table:
      clarify/  → brief
      research/ + filename ≠ current-understanding.md → dossier
      specs/    + filename == spec.md                 → spec
      anything else → ValueError
    """

    def setUp(self):
        self.mod = _load_extractor()

    def test_clarify_path_returns_brief(self):
        path = "docs/cortex/clarify/cortex-vault/20260413T020000Z-clarify-brief.md"
        self.assertEqual(self.mod.detect_artifact_type(path), "brief")

    def test_research_path_returns_dossier(self):
        path = "docs/cortex/research/cortex-vault/concept-20260413T140000Z.md"
        self.assertEqual(self.mod.detect_artifact_type(path), "dossier")

    def test_research_current_understanding_raises(self):
        """current-understanding.md inside research/ must raise ValueError."""
        path = "docs/cortex/research/cortex-vault/current-understanding.md"
        with self.assertRaises(ValueError) as ctx:
            self.mod.detect_artifact_type(path)
        self.assertIn("unsupported artifact type", str(ctx.exception))

    def test_specs_spec_md_returns_spec(self):
        path = "docs/cortex/specs/cortex-vault/spec.md"
        self.assertEqual(self.mod.detect_artifact_type(path), "spec")

    def test_specs_non_spec_md_raises(self):
        """specs/ path with a filename other than spec.md → ValueError."""
        path = "docs/cortex/specs/cortex-vault/gsd-handoff.md"
        with self.assertRaises(ValueError) as ctx:
            self.mod.detect_artifact_type(path)
        self.assertIn("unsupported artifact type", str(ctx.exception))

    def test_unknown_path_raises(self):
        path = "docs/cortex/contracts/cortex-vault/contract-001.md"
        with self.assertRaises(ValueError) as ctx:
            self.mod.detect_artifact_type(path)
        self.assertIn("unsupported artifact type", str(ctx.exception))


# ---------------------------------------------------------------------------
# Idempotency guard tests
# ---------------------------------------------------------------------------

class TestIdempotencyGuard(unittest.TestCase):
    """Before every add_fact() call, check SQLite for existing row with
    matching (session_id, topic, content[:50]). Skip if found."""

    def setUp(self):
        self.mod = _load_extractor()

    def test_check_duplicate_returns_true_when_exists(self):
        """is_duplicate() returns True when matching row is in DB."""
        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
            db_path = f.name
        try:
            conn = sqlite3.connect(db_path)
            conn.execute(
                "CREATE TABLE facts (id TEXT, session_id TEXT, topic TEXT, content TEXT)"
            )
            conn.execute(
                "INSERT INTO facts VALUES ('abc', 'cortex-slug', 'architecture-decision', "
                "'This is a fact that is longer than fifty characters for testing.')"
            )
            conn.commit()
            conn.close()

            result = self.mod.is_duplicate(
                db_path=db_path,
                session_id="cortex-slug",
                topic="architecture-decision",
                content="This is a fact that is longer than fifty characters for testing.",
            )
            self.assertTrue(result)
        finally:
            os.unlink(db_path)

    def test_check_duplicate_returns_false_when_absent(self):
        """is_duplicate() returns False when no matching row."""
        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
            db_path = f.name
        try:
            conn = sqlite3.connect(db_path)
            conn.execute(
                "CREATE TABLE facts (id TEXT, session_id TEXT, topic TEXT, content TEXT)"
            )
            conn.commit()
            conn.close()

            result = self.mod.is_duplicate(
                db_path=db_path,
                session_id="cortex-slug",
                topic="architecture-decision",
                content="Some new fact content.",
            )
            self.assertFalse(result)
        finally:
            os.unlink(db_path)

    def test_add_fact_skipped_when_duplicate(self):
        """write_fact() must not call add_fact() if is_duplicate() returns True."""
        with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as f:
            db_path = f.name
        try:
            conn = sqlite3.connect(db_path)
            conn.execute(
                "CREATE TABLE facts (id TEXT, session_id TEXT, topic TEXT, content TEXT)"
            )
            existing_content = "Existing fact content that is long enough for the key."
            conn.execute(
                "INSERT INTO facts VALUES ('id1', 'cortex-test', 'design-assumption', ?)",
                (existing_content,),
            )
            conn.commit()
            conn.close()

            mock_add_fact = MagicMock()
            # write_fact must accept these kwargs — it checks idempotency then calls add_fact
            self.mod.write_fact(
                add_fact_fn=mock_add_fact,
                db_path=db_path,
                session_id="cortex-test",
                topic="design-assumption",
                content=existing_content,
                valid_from="2026-04-13",
                memory_type="semantic",
                confidence=0.75,
                importance=0.7,
                scope="learning",
                project_scope="cortex-memory-platform",
            )
            mock_add_fact.assert_not_called()
        finally:
            os.unlink(db_path)


# ---------------------------------------------------------------------------
# Soft-fail on missing vault tests
# ---------------------------------------------------------------------------

class TestSoftFailOnMissingVault(unittest.TestCase):
    """When fact_store.py is not importable or vault path absent,
    extractor must log a warning and NOT raise an exception."""

    def setUp(self):
        self.mod = _load_extractor()

    def test_extract_does_not_raise_when_vault_missing(self):
        """extract_and_write() soft-fails when sys.path insert fails to provide fact_store."""
        # Patch the vault path to a non-existent location
        with patch.object(self.mod, "VAULT_SCRIPTS_PATH", "/nonexistent/vault/scripts"):
            # Should not raise
            try:
                self.mod.extract_and_write(
                    artifact_path="docs/cortex/clarify/cortex-vault/20260413T020000Z-clarify-brief.md",
                    slug="cortex-vault",
                    dry_run=True,  # do not actually write
                )
            except Exception as e:
                self.fail(f"extract_and_write raised an exception when vault missing: {e}")


# ---------------------------------------------------------------------------
# add_fact() field value tests for each category
# ---------------------------------------------------------------------------

class TestAddFactFieldValues(unittest.TestCase):
    """Verify write_fact() calls add_fact() with correct per-category field values."""

    def setUp(self):
        self.mod = _load_extractor()
        # Use an in-memory temp DB so is_duplicate() always returns False
        self._tmpdb = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        self._db_path = self._tmpdb.name
        conn = sqlite3.connect(self._db_path)
        conn.execute(
            "CREATE TABLE facts (id TEXT, session_id TEXT, topic TEXT, content TEXT)"
        )
        conn.commit()
        conn.close()

    def tearDown(self):
        os.unlink(self._db_path)

    def _call_write_fact(self, mock_add_fact, topic, memory_type, confidence, importance):
        self.mod.write_fact(
            add_fact_fn=mock_add_fact,
            db_path=self._db_path,
            session_id="cortex-cortex-vault",
            topic=topic,
            content=f"Test fact content for topic {topic}.",
            valid_from="2026-04-13",
            memory_type=memory_type,
            confidence=confidence,
            importance=importance,
            scope="learning",
            project_scope="cortex-memory-platform",
        )

    def _assert_add_fact_called_with(self, mock_add_fact, **expected_kwargs):
        self.assertTrue(mock_add_fact.called, "add_fact was not called")
        actual_kwargs = mock_add_fact.call_args.kwargs
        for k, v in expected_kwargs.items():
            self.assertIn(k, actual_kwargs, f"Missing kwarg: {k}")
            self.assertEqual(actual_kwargs[k], v, f"Mismatch for {k}: {actual_kwargs[k]} != {v}")

    # --- scope-exclusion ---
    def test_scope_exclusion_fields(self):
        mock = MagicMock()
        self._call_write_fact(mock, "scope-exclusion", "semantic", 0.95, 0.6)
        self._assert_add_fact_called_with(
            mock,
            topic="scope-exclusion",
            memory_type="semantic",
            confidence=0.95,
            importance=0.6,
            scope="learning",
            project_scope="cortex-memory-platform",
        )

    # --- owner-constraint ---
    def test_owner_constraint_fields(self):
        mock = MagicMock()
        self._call_write_fact(mock, "owner-constraint", "semantic", 0.95, 0.8)
        self._assert_add_fact_called_with(
            mock,
            topic="owner-constraint",
            memory_type="semantic",
            confidence=0.95,
            importance=0.8,
        )

    # --- design-assumption ---
    def test_design_assumption_fields(self):
        mock = MagicMock()
        self._call_write_fact(mock, "design-assumption", "semantic", 0.75, 0.7)
        self._assert_add_fact_called_with(
            mock,
            topic="design-assumption",
            memory_type="semantic",
            confidence=0.75,
            importance=0.7,
        )

    # --- research-finding ---
    def test_research_finding_fields(self):
        mock = MagicMock()
        self._call_write_fact(mock, "research-finding", "semantic", 0.80, 0.7)
        self._assert_add_fact_called_with(
            mock,
            topic="research-finding",
            memory_type="semantic",
            confidence=0.80,
            importance=0.7,
        )

    # --- architecture-decision ---
    def test_architecture_decision_fields(self):
        mock = MagicMock()
        self._call_write_fact(mock, "architecture-decision", "semantic", 0.90, 0.8)
        self._assert_add_fact_called_with(
            mock,
            topic="architecture-decision",
            memory_type="semantic",
            confidence=0.90,
            importance=0.8,
        )

    # --- adjacent-finding ---
    def test_adjacent_finding_fields(self):
        mock = MagicMock()
        self._call_write_fact(mock, "adjacent-finding", "semantic", 0.75, 0.65)
        self._assert_add_fact_called_with(
            mock,
            topic="adjacent-finding",
            memory_type="semantic",
            confidence=0.75,
            importance=0.65,
        )

    # --- failed-approach ---
    def test_failed_approach_fields(self):
        mock = MagicMock()
        self._call_write_fact(mock, "failed-approach", "procedural", 0.85, 0.75)
        self._assert_add_fact_called_with(
            mock,
            topic="failed-approach",
            memory_type="procedural",
            confidence=0.85,
            importance=0.75,
        )

    # --- risk-mitigation ---
    def test_risk_mitigation_fields(self):
        mock = MagicMock()
        self._call_write_fact(mock, "risk-mitigation", "semantic", 0.80, 0.70)
        self._assert_add_fact_called_with(
            mock,
            topic="risk-mitigation",
            memory_type="semantic",
            confidence=0.80,
            importance=0.70,
        )


# ---------------------------------------------------------------------------
# Session-id format test
# ---------------------------------------------------------------------------

class TestSessionIdFormat(unittest.TestCase):
    """session_id must be cortex-{slug}."""

    def setUp(self):
        self.mod = _load_extractor()
        self._tmpdb = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        self._db_path = self._tmpdb.name
        conn = sqlite3.connect(self._db_path)
        conn.execute(
            "CREATE TABLE facts (id TEXT, session_id TEXT, topic TEXT, content TEXT)"
        )
        conn.commit()
        conn.close()

    def tearDown(self):
        os.unlink(self._db_path)

    def test_session_id_uses_cortex_prefix(self):
        mock = MagicMock()
        self.mod.write_fact(
            add_fact_fn=mock,
            db_path=self._db_path,
            session_id="cortex-my-slug",
            topic="design-assumption",
            content="Some assumption content.",
            valid_from="2026-04-13",
            memory_type="semantic",
            confidence=0.75,
            importance=0.7,
            scope="learning",
            project_scope="cortex-memory-platform",
        )
        self.assertTrue(mock.called)
        actual_kwargs = mock.call_args.kwargs
        self.assertTrue(
            actual_kwargs.get("session_id", "").startswith("cortex-"),
            f"session_id should start with 'cortex-', got: {actual_kwargs.get('session_id')}"
        )


if __name__ == "__main__":
    unittest.main()
