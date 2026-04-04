#!/usr/bin/env python3
"""Tests for cortex-embed.py and cortex-retrieve.py."""

import json
import os
import subprocess
import sys
import tempfile
import shutil

import numpy as np
import pytest

SCRIPTS_DIR = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'cortex')
EMBED_SCRIPT = os.path.join(SCRIPTS_DIR, 'cortex-embed.py')
RETRIEVE_SCRIPT = os.path.join(SCRIPTS_DIR, 'cortex-retrieve.py')


@pytest.fixture
def cortex_dir(tmp_path):
    """Create a temp .cortex dir with sample facts."""
    cortex = tmp_path / '.cortex'
    cortex.mkdir()

    facts = [
        {'id': f'fact-{i}', 'type': 'decision', 'slug': 'test',
         'text': text, 'source': 'test', 'extracted_at': '20260404T000000Z',
         'session_context': 'test'}
        for i, text in enumerate([
            'Hook performance budget must be under 5 seconds',
            'Use ollama nomic-embed-text for all embeddings',
            'Python 3.12 is the target runtime',
            'Facts are stored in JSONL format in .cortex/facts.jsonl',
            'Cosine similarity is used for semantic retrieval',
            'The project uses numpy for vector operations',
            'Compaction triggers fact extraction via PostCompact hook',
            'Graceful degradation when ollama is unavailable',
        ])
    ]

    facts_path = cortex / 'facts.jsonl'
    with open(facts_path, 'w') as f:
        for fact in facts:
            f.write(json.dumps(fact) + '\n')

    return str(cortex)


def run_embed(cortex_dir, env_overrides=None):
    """Run cortex-embed.py with CORTEX_DIR set."""
    env = os.environ.copy()
    env['CORTEX_DIR'] = cortex_dir
    if env_overrides:
        env.update(env_overrides)
    result = subprocess.run(
        [sys.executable, EMBED_SCRIPT],
        env=env, capture_output=True, text=True, timeout=30)
    return result


def run_retrieve(cortex_dir, query, top_k=5, env_overrides=None):
    """Run cortex-retrieve.py with CORTEX_DIR set."""
    env = os.environ.copy()
    env['CORTEX_DIR'] = cortex_dir
    if env_overrides:
        env.update(env_overrides)
    result = subprocess.run(
        [sys.executable, RETRIEVE_SCRIPT, query, '--top-k', str(top_k)],
        env=env, capture_output=True, text=True, timeout=10)
    return result


class TestEmbed:
    def test_produces_npy_with_correct_shape(self, cortex_dir):
        result = run_embed(cortex_dir)
        assert result.returncode == 0

        npy_path = os.path.join(cortex_dir, 'fact-embeddings.npy')
        assert os.path.exists(npy_path)

        embeddings = np.load(npy_path)
        assert embeddings.shape == (8, 768)
        assert embeddings.dtype == np.float32

    def test_produces_index_json(self, cortex_dir):
        run_embed(cortex_dir)

        index_path = os.path.join(cortex_dir, 'fact-index.json')
        assert os.path.exists(index_path)

        with open(index_path) as f:
            index = json.load(f)

        assert len(index) == 8
        for i in range(8):
            assert f'fact-{i}' in index
            assert index[f'fact-{i}'] == i

    def test_produces_meta_json(self, cortex_dir):
        run_embed(cortex_dir)

        meta_path = os.path.join(cortex_dir, 'fact-embeddings.meta.json')
        assert os.path.exists(meta_path)

        with open(meta_path) as f:
            meta = json.load(f)

        assert meta['last_embedded_count'] == 8
        assert meta['model'] == 'nomic-embed-text'
        assert 'timestamp' in meta
        assert meta['dimensions'] == 768

    def test_incremental_embedding(self, cortex_dir):
        # First run: embed 8 facts
        run_embed(cortex_dir)

        meta_path = os.path.join(cortex_dir, 'fact-embeddings.meta.json')
        with open(meta_path) as f:
            meta1 = json.load(f)
        assert meta1['last_embedded_count'] == 8

        # Add 2 more facts
        facts_path = os.path.join(cortex_dir, 'facts.jsonl')
        with open(facts_path, 'a') as f:
            for i in range(8, 10):
                fact = {'id': f'fact-{i}', 'type': 'decision', 'slug': 'test',
                        'text': f'Additional fact number {i}', 'source': 'test',
                        'extracted_at': '20260404T000000Z', 'session_context': 'test'}
                f.write(json.dumps(fact) + '\n')

        # Second run: should only embed 2 new facts
        result = run_embed(cortex_dir)
        assert 'Incremental: embedding 2 new facts' in result.stderr

        embeddings = np.load(os.path.join(cortex_dir, 'fact-embeddings.npy'))
        assert embeddings.shape == (10, 768)

        with open(meta_path) as f:
            meta2 = json.load(f)
        assert meta2['last_embedded_count'] == 10

    def test_skips_when_already_embedded(self, cortex_dir):
        run_embed(cortex_dir)
        result = run_embed(cortex_dir)
        assert 'already embedded, skipping' in result.stderr

    def test_exits_zero_on_missing_facts(self, tmp_path):
        empty_dir = str(tmp_path / '.cortex-empty')
        os.makedirs(empty_dir)
        result = run_embed(empty_dir)
        assert result.returncode == 0

    def test_exits_zero_on_ollama_unreachable(self, cortex_dir):
        result = run_embed(cortex_dir, env_overrides={'OLLAMA_URL': 'http://localhost:99999'})
        assert result.returncode == 0
        assert 'unreachable' in result.stderr.lower() or 'error' in result.stderr.lower()


class TestRetrieve:
    @pytest.fixture(autouse=True)
    def _embed_first(self, cortex_dir):
        """Embed facts before each retrieval test."""
        self.cortex_dir = cortex_dir
        run_embed(cortex_dir)

    def test_returns_json_array(self):
        result = run_retrieve(self.cortex_dir, 'hook performance')
        assert result.returncode == 0

        results = json.loads(result.stdout)
        assert isinstance(results, list)
        assert len(results) <= 5

    def test_results_have_required_fields(self):
        result = run_retrieve(self.cortex_dir, 'embedding model')
        results = json.loads(result.stdout)

        for r in results:
            assert 'id' in r
            assert 'text' in r
            assert 'score' in r
            assert isinstance(r['score'], float)

    def test_results_sorted_by_descending_score(self):
        result = run_retrieve(self.cortex_dir, 'numpy vector operations')
        results = json.loads(result.stdout)

        scores = [r['score'] for r in results]
        assert scores == sorted(scores, reverse=True)

    def test_top_k_limits_results(self):
        result = run_retrieve(self.cortex_dir, 'test query', top_k=3)
        results = json.loads(result.stdout)
        assert len(results) <= 3

    def test_semantic_relevance(self):
        """The top result for 'hook performance budget' should mention hooks or performance."""
        result = run_retrieve(self.cortex_dir, 'hook performance budget', top_k=1)
        results = json.loads(result.stdout)
        assert len(results) == 1
        text = results[0]['text'].lower()
        assert 'hook' in text or 'performance' in text or 'budget' in text

    def test_fallback_when_npy_missing(self):
        npy_path = os.path.join(self.cortex_dir, 'fact-embeddings.npy')
        os.remove(npy_path)

        result = run_retrieve(self.cortex_dir, 'test query')
        assert result.returncode == 0
        assert 'WARNING' in result.stderr

        results = json.loads(result.stdout)
        assert len(results) == 8  # all facts returned
        assert all(r['score'] == 0.0 for r in results)

    def test_fallback_when_ollama_unreachable(self):
        result = run_retrieve(self.cortex_dir, 'test query',
                              env_overrides={'OLLAMA_URL': 'http://localhost:99999'})
        assert result.returncode == 0
        assert 'WARNING' in result.stderr

        results = json.loads(result.stdout)
        assert len(results) == 8
        assert all(r['score'] == 0.0 for r in results)

    def test_completes_within_2_seconds(self):
        """Retrieval must complete in <2 seconds."""
        import time
        start = time.time()
        result = run_retrieve(self.cortex_dir, 'hook performance budget')
        elapsed = time.time() - start

        assert result.returncode == 0
        assert elapsed < 2.0, f'Retrieval took {elapsed:.2f}s, exceeds 2s budget'
