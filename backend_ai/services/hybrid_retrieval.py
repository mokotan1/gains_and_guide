"""코퍼스·유저 네임스페이스 분리 검색 및 점수 가중(옵션)."""

from __future__ import annotations

import os
from dataclasses import dataclass, replace
from typing import Optional

from services.rag import RagService
from services.rag_types import RetrievedChunk

DEFAULT_K_CORPUS = 4
DEFAULT_K_USER = 2
DEFAULT_USER_SCORE_WEIGHT = 1.2


@dataclass(frozen=True)
class HybridRagConfig:
    k_corpus: int
    k_user: int
    user_score_weight: float


def hybrid_rag_config_from_env() -> HybridRagConfig:
    def _i(name: str, default: int) -> int:
        try:
            return int(os.getenv(name, str(default)).strip())
        except ValueError:
            return default

    def _f(name: str, default: float) -> float:
        try:
            return float(os.getenv(name, str(default)).strip())
        except ValueError:
            return default

    kc = max(0, _i("RAG_TOP_K_CORPUS", DEFAULT_K_CORPUS))
    ku = max(0, _i("RAG_TOP_K_USER", DEFAULT_K_USER))
    w = max(0.0, _f("USER_RAG_SCORE_WEIGHT", DEFAULT_USER_SCORE_WEIGHT))
    return HybridRagConfig(k_corpus=kc, k_user=ku, user_score_weight=w)


def retrieve_corpus_and_user(
    rag: RagService,
    query: str,
    *,
    user_namespace: Optional[str],
    cfg: HybridRagConfig,
    corpus_namespace: str = "corpus",
) -> tuple[list[RetrievedChunk], list[RetrievedChunk]]:
    corpus_hits: list[RetrievedChunk] = []
    if cfg.k_corpus > 0:
        corpus_hits = rag.retrieve(
            query, top_k=cfg.k_corpus, namespace=corpus_namespace
        )

    user_hits: list[RetrievedChunk] = []
    if user_namespace and cfg.k_user > 0:
        user_hits = rag.retrieve(query, top_k=cfg.k_user, namespace=user_namespace)
        if cfg.user_score_weight != 1.0:
            user_hits = [
                replace(c, score=float(c.score) * cfg.user_score_weight) for c in user_hits
            ]

    return corpus_hits, user_hits
