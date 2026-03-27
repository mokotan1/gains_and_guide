"""하이브리드 코퍼스·유저 RAG 검색."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from services.hybrid_retrieval import (
    HybridRagConfig,
    hybrid_rag_config_from_env,
    retrieve_corpus_and_user,
)
from services.rag import RagService, TokenOverlapRetriever, load_chunks_jsonl


class TestHybridRetrieval(unittest.TestCase):
    def test_corpus_and_user_namespaces_split(self) -> None:
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".jsonl", delete=False, encoding="utf-8"
        ) as f:
            for row in (
                {
                    "id": "c1",
                    "namespace": "corpus",
                    "text": "protein intake muscle recovery",
                    "source": "guide",
                    "topic": "nutrition",
                },
                {
                    "id": "u1",
                    "namespace": "user_ns_demo",
                    "text": "my squat day monday",
                    "source": "note",
                    "topic": "log",
                },
            ):
                f.write(json.dumps(row, ensure_ascii=False) + "\n")
            path = f.name
        try:
            chunks = load_chunks_jsonl(path)
            svc = RagService(
                chunks, retriever=TokenOverlapRetriever(chunks), mode="token"
            )
            cfg = HybridRagConfig(k_corpus=2, k_user=2, user_score_weight=2.0)
            corp, usr = retrieve_corpus_and_user(
                svc,
                "squat protein",
                user_namespace="user_ns_demo",
                cfg=cfg,
                corpus_namespace="corpus",
            )
            self.assertTrue(any(h.chunk_id == "c1" for h in corp))
            self.assertTrue(any(h.chunk_id == "u1" for h in usr))
            self.assertTrue(all(h.score >= 0 for h in usr))
        finally:
            Path(path).unlink(missing_ok=True)

    def test_user_namespace_none_skips_user(self) -> None:
        chunks: list = []
        svc = RagService(chunks, retriever=TokenOverlapRetriever(chunks), mode="token")
        cfg = HybridRagConfig(k_corpus=1, k_user=2, user_score_weight=1.0)
        corp, usr = retrieve_corpus_and_user(
            svc, "q", user_namespace=None, cfg=cfg, corpus_namespace="corpus"
        )
        self.assertEqual(usr, [])

    def test_k_zero_returns_empty(self) -> None:
        chunks: list = []
        svc = RagService(chunks, retriever=TokenOverlapRetriever(chunks), mode="token")
        cfg = HybridRagConfig(k_corpus=0, k_user=0, user_score_weight=1.0)
        corp, usr = retrieve_corpus_and_user(
            svc, "q", user_namespace="x", cfg=cfg, corpus_namespace="corpus"
        )
        self.assertEqual(corp, [])
        self.assertEqual(usr, [])

    def test_hybrid_rag_config_from_env_defaults(self) -> None:
        cfg = hybrid_rag_config_from_env()
        self.assertGreaterEqual(cfg.k_corpus, 0)
        self.assertGreaterEqual(cfg.k_user, 0)


if __name__ == "__main__":
    unittest.main()
