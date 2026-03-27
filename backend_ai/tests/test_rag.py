"""RAG 토큰 검색·빈 코퍼스 graceful degrade."""

from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path

from services.rag import (
    RagService,
    TokenOverlapRetriever,
    create_rag_service,
    load_chunks_jsonl,
)
from services.rag_types import RetrievedChunk, format_references, rag_snippet_max_chars_from_env


class TestRagService(unittest.TestCase):
    def test_empty_chunks_returns_no_results(self) -> None:
        chunks: list = []
        svc = RagService(chunks, retriever=TokenOverlapRetriever(chunks), mode="token")
        self.assertEqual(svc.retrieve("anything"), [])
        self.assertEqual(svc.chunk_count, 0)

    def test_retrieves_by_overlap(self) -> None:
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".jsonl", delete=False, encoding="utf-8"
        ) as f:
            f.write(
                json.dumps(
                    {
                        "id": "a",
                        "namespace": "corpus",
                        "text": "Epley formula weight reps thirty",
                        "source": "t",
                        "topic": "x",
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )
            f.write(
                json.dumps(
                    {
                        "id": "b",
                        "namespace": "corpus",
                        "text": "unrelated cooking pasta",
                        "source": "t",
                        "topic": "x",
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )
            path = f.name
        try:
            chunks = load_chunks_jsonl(path)
            svc = RagService(
                chunks, retriever=TokenOverlapRetriever(chunks), mode="token"
            )
            hits = svc.retrieve("Epley 1RM weight", top_k=2)
            self.assertTrue(hits)
            self.assertEqual(hits[0].chunk_id, "a")
        finally:
            Path(path).unlink(missing_ok=True)

    def test_namespace_filter(self) -> None:
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".jsonl", delete=False, encoding="utf-8"
        ) as f:
            f.write(
                json.dumps(
                    {
                        "id": "u1",
                        "namespace": "user_x",
                        "text": "squat program",
                        "source": "u",
                        "topic": "p",
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )
            path = f.name
        try:
            chunks = load_chunks_jsonl(path)
            svc = RagService(
                chunks, retriever=TokenOverlapRetriever(chunks), mode="token"
            )
            self.assertEqual(svc.retrieve("squat", namespace="corpus"), [])
            self.assertEqual(len(svc.retrieve("squat", namespace="user_x")), 1)
        finally:
            Path(path).unlink(missing_ok=True)

    def test_format_references_truncates(self) -> None:
        long_text = "x" * 800
        s = format_references(
            [
                RetrievedChunk(
                    chunk_id="1",
                    text=long_text,
                    source="s",
                    topic="t",
                    score=1.0,
                )
            ]
        )
        self.assertIn("...", s)
        self.assertLess(len(s), len(long_text) + 100)

    def test_format_references_respects_max_snippet_override(self) -> None:
        long_text = "y" * 200
        s = format_references(
            [
                RetrievedChunk(
                    chunk_id="1",
                    text=long_text,
                    source="s",
                    topic="t",
                    score=1.0,
                )
            ],
            max_snippet_chars=50,
        )
        self.assertIn("...", s)
        self.assertLessEqual(len(s), 120)

    def test_rag_snippet_max_chars_from_env_invalid_falls_back(self) -> None:
        old = os.environ.get("RAG_SNIPPET_MAX_CHARS")
        try:
            os.environ["RAG_SNIPPET_MAX_CHARS"] = "not-a-number"
            self.assertEqual(rag_snippet_max_chars_from_env(), 450)
        finally:
            if old is None:
                os.environ.pop("RAG_SNIPPET_MAX_CHARS", None)
            else:
                os.environ["RAG_SNIPPET_MAX_CHARS"] = old


class TestCreateRagService(unittest.TestCase):
    def test_forces_token_when_backend_token(self) -> None:
        root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        old = os.environ.get("RAG_BACKEND")
        try:
            os.environ["RAG_BACKEND"] = "token"
            svc = create_rag_service(root)
            self.assertEqual(svc.mode, "token")
        finally:
            if old is None:
                os.environ.pop("RAG_BACKEND", None)
            else:
                os.environ["RAG_BACKEND"] = old


class TestGoldenQueriesFile(unittest.TestCase):
    def test_structure(self) -> None:
        root = Path(__file__).resolve().parents[1]
        path = root / "corpus" / "golden_queries.json"
        self.assertTrue(path.is_file())
        with path.open(encoding="utf-8") as f:
            data = json.load(f)
        cases = data.get("cases", [])
        self.assertTrue(len(cases) >= 1)
        for c in cases:
            self.assertIn("query", c)
            self.assertIn("expected_ids", c)
            self.assertIsInstance(c["expected_ids"], list)


if __name__ == "__main__":
    unittest.main()
