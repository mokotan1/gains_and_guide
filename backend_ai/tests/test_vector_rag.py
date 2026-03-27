"""로컬 벡터 인덱스 검색 (OpenAI 없이 고정 임베더)."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from services.vector_rag import LocalVectorRetriever


class _FixedEmbedder:
    def embed_one(self, text: str) -> list[float]:
        if "alpha" in text.lower():
            return [1.0, 0.0, 0.0]
        return [0.0, 1.0, 0.0]


class TestLocalVectorRetriever(unittest.TestCase):
    def test_cosine_ranks_best_match(self) -> None:
        payload = {
            "embedding_model": "fake",
            "embedding_dimensions": 3,
            "records": [
                {
                    "id": "r1",
                    "values": [1.0, 0.0, 0.0],
                    "text": "alpha topic",
                    "source": "s",
                    "topic": "t",
                    "namespace": "corpus",
                    "license": "",
                },
                {
                    "id": "r2",
                    "values": [0.0, 1.0, 0.0],
                    "text": "beta topic",
                    "source": "s",
                    "topic": "t",
                    "namespace": "corpus",
                    "license": "",
                },
            ],
        }
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False, encoding="utf-8"
        ) as f:
            json.dump(payload, f)
            p = f.name
        try:
            retriever = LocalVectorRetriever(
                index_path=Path(p),
                embedder=_FixedEmbedder(),
            )
            hits = retriever.retrieve("ask about alpha", top_k=2, namespace="corpus")
            self.assertEqual(hits[0].chunk_id, "r1")
            self.assertGreaterEqual(hits[0].score, hits[1].score)
        finally:
            Path(p).unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
