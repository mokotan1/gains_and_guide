"""코치 라우터: RAG 실패 시 500 대신 참조만 생략."""

from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from routers import coach as coach_mod


class TestCoachRagResilience(unittest.TestCase):
    def test_rag_retrieve_exception_returns_empty_appendix(self) -> None:
        with patch.object(coach_mod.app_deps, "rag", MagicMock()):
            with patch(
                "routers.coach.retrieve_corpus_and_user",
                side_effect=RuntimeError("pinecone unavailable"),
            ):
                out = coach_mod._rag_reference_appendix(
                    "hello", "subj", rag_snippet_max=100
                )
        self.assertEqual(out, "")

    def test_rag_disabled_returns_empty(self) -> None:
        prev = coach_mod.app_deps.rag
        coach_mod.app_deps.rag = None
        try:
            out = coach_mod._rag_reference_appendix("q", "u", rag_snippet_max=None)
            self.assertEqual(out, "")
        finally:
            coach_mod.app_deps.rag = prev


if __name__ == "__main__":
    unittest.main()
