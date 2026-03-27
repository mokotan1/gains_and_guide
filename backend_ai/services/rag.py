"""코퍼스 RAG: 토큰 겹침 또는 임베딩+벡터 검색."""

from __future__ import annotations

import json
import logging
import os
import re
from pathlib import Path
from typing import Any, Optional, Protocol

from services.rag_types import DEFAULT_TOP_K, RetrievedChunk, format_references

logger = logging.getLogger(__name__)

_TOKEN_RE = re.compile(r"[\w가-힣]+", re.UNICODE)

# 하위 호환: 기존 import 경로
__all__ = [
    "DEFAULT_TOP_K",
    "RetrievedChunk",
    "RagService",
    "TokenOverlapRetriever",
    "create_rag_service",
    "format_references",
    "load_chunks_jsonl",
]


def _tokens(s: str) -> set[str]:
    return {t.lower() for t in _TOKEN_RE.findall(s)}


def load_chunks_jsonl(path: Optional[str | Path]) -> list[dict[str, Any]]:
    chunks: list[dict[str, Any]] = []
    if path is None:
        return chunks
    p = Path(path)
    if not p.is_file():
        return chunks
    try:
        with p.open(encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                chunks.append(json.loads(line))
        logger.info("RAG: loaded %d chunks from %s", len(chunks), p)
    except (OSError, json.JSONDecodeError) as e:
        logger.error("RAG: failed to load %s: %s", p, e)
    return chunks


class Retriever(Protocol):
    def retrieve(
        self,
        query: str,
        *,
        top_k: int = DEFAULT_TOP_K,
        namespace: Optional[str] = "corpus",
    ) -> list[RetrievedChunk]: ...


class TokenOverlapRetriever:
    """임베딩 없이 토큰 Jaccard top-k (폴백)."""

    def __init__(self, chunks: list[dict[str, Any]]) -> None:
        self._token_cache: list[tuple[dict[str, Any], set[str]]] = [
            (c, _tokens(str(c.get("text", "")))) for c in chunks
        ]

    def retrieve(
        self,
        query: str,
        *,
        top_k: int = DEFAULT_TOP_K,
        namespace: Optional[str] = "corpus",
    ) -> list[RetrievedChunk]:
        if not query.strip() or not self._token_cache:
            return []
        qt = _tokens(query)
        if not qt:
            return []
        scored: list[tuple[float, dict[str, Any]]] = []
        for chunk, ct in self._token_cache:
            ns = chunk.get("namespace", "corpus")
            if namespace is not None and ns != namespace:
                continue
            overlap = len(qt & ct)
            if overlap == 0:
                continue
            union = len(qt | ct) or 1
            score = overlap / union
            scored.append((score, chunk))
        scored.sort(key=lambda x: -x[0])
        out: list[RetrievedChunk] = []
        for s, c in scored[:top_k]:
            out.append(
                RetrievedChunk(
                    chunk_id=str(c.get("id", "")),
                    text=str(c.get("text", "")),
                    source=str(c.get("source", "")),
                    topic=str(c.get("topic", "")),
                    score=s,
                )
            )
        return out


class RagService:
    """청크 JSONL + 선택적 벡터/토큰 검색기."""

    def __init__(
        self,
        chunks: list[dict[str, Any]],
        *,
        retriever: Retriever,
        mode: str = "token",
    ) -> None:
        self._chunks = chunks
        self._retriever = retriever
        self._mode = mode

    @property
    def chunk_count(self) -> int:
        return len(self._chunks)

    @property
    def mode(self) -> str:
        return self._mode

    def retrieve(
        self,
        query: str,
        *,
        top_k: int = DEFAULT_TOP_K,
        namespace: Optional[str] = "corpus",
    ) -> list[RetrievedChunk]:
        return self._retriever.retrieve(query, top_k=top_k, namespace=namespace)


def create_rag_service(base_dir: str) -> RagService:
    """
    환경 변수로 백엔드 선택.
    - RAG_BACKEND=auto|token|local|pinecone (기본 auto)
    - auto: Pinecone 키+인덱스명 있으면 pinecone, 아니면 RAG_VECTOR_INDEX_PATH 파일+OPENAI면 local, 아니면 token
    - local: corpus/vector_index.json 또는 RAG_VECTOR_INDEX_PATH
    """
    base = Path(base_dir)
    chunks_path = base / "corpus" / "chunks.jsonl"
    chunks = load_chunks_jsonl(chunks_path)

    mode_env = os.getenv("RAG_BACKEND", "auto").strip().lower()
    openai_key = os.getenv("OPENAI_API_KEY", "").strip()
    pinecone_key = os.getenv("PINECONE_API_KEY", "").strip()
    index_name = os.getenv("PINECONE_INDEX_NAME", "").strip()
    vector_index_env = os.getenv("RAG_VECTOR_INDEX_PATH", "").strip()
    default_local = base / "corpus" / "vector_index.json"
    local_path = Path(vector_index_env) if vector_index_env else default_local
    if vector_index_env and not Path(vector_index_env).is_absolute():
        local_path = base / vector_index_env

    def token_fallback(reason: str) -> RagService:
        logger.warning("RAG: using token overlap (%s)", reason)
        return RagService(
            chunks,
            retriever=TokenOverlapRetriever(chunks),
            mode="token",
        )

    if mode_env == "token":
        return RagService(
            chunks, retriever=TokenOverlapRetriever(chunks), mode="token"
        )

    if mode_env == "pinecone" or (
        mode_env == "auto" and pinecone_key and index_name and openai_key
    ):
        if not openai_key:
            return token_fallback("pinecone needs OPENAI_API_KEY for query embedding")
        if not pinecone_key or not index_name:
            return token_fallback("pinecone needs PINECONE_API_KEY and PINECONE_INDEX_NAME")
        try:
            from services.embeddings import OpenAIEmbedder
            from services.vector_rag import PineconeRetriever

            embedder = OpenAIEmbedder(api_key=openai_key)
            pc_ns = os.getenv("PINECONE_NAMESPACE", "corpus").strip() or "corpus"
            retriever = PineconeRetriever(
                embedder=embedder,
                index_name=index_name,
                pinecone_namespace=pc_ns,
            )
            logger.info("RAG mode=pinecone index=%s", index_name)
            return RagService(chunks, retriever=retriever, mode="pinecone")
        except Exception as e:
            logger.exception("RAG pinecone init failed: %s", e)
            return token_fallback("pinecone init failed")

    if mode_env == "local" or (
        mode_env == "auto" and local_path.is_file() and openai_key
    ):
        if not openai_key:
            return token_fallback("local vector index needs OPENAI_API_KEY")
        if not local_path.is_file():
            if mode_env == "local":
                logger.error("RAG_BACKEND=local but index missing: %s", local_path)
            return token_fallback("no vector index file")
        try:
            from services.embeddings import OpenAIEmbedder
            from services.vector_rag import LocalVectorRetriever

            embedder = OpenAIEmbedder(api_key=openai_key)
            retriever = LocalVectorRetriever(
                index_path=local_path,
                embedder=embedder,
                expected_model=embedder.model,
                expected_dim=embedder.dimensions,
            )
            logger.info("RAG mode=local path=%s", local_path)
            return RagService(chunks, retriever=retriever, mode="local")
        except Exception as e:
            logger.exception("RAG local vector init failed: %s", e)
            return token_fallback("local vector init failed")

    return token_fallback("default")
