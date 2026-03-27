"""RAG 토큰 검색·빈 코퍼스 graceful degrade."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from services.rag import RagService, RetrievedChunk, format_references


class TestRagService(unittest.TestCase):
    def test_empty_path_returns_no_results(self) -> None:
        svc = RagService(None)
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
            svc = RagService(path)
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
            svc = RagService(path)
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


if __name__ == "__main__":
    unittest.main()
