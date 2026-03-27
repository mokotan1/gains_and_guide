"""임베딩 기반 검색: 로컬 JSON 인덱스 또는 Pinecone."""

from __future__ import annotations

import json
import logging
import math
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional, Protocol, Sequence

from services.rag_types import DEFAULT_TOP_K, RetrievedChunk

logger = logging.getLogger(__name__)


class SupportsEmbed(Protocol):
    def embed_one(self, text: str) -> list[float]: ...


def _l2_normalize(v: Sequence[float]) -> list[float]:
    s = math.sqrt(sum(x * x for x in v))
    if s <= 0:
        return list(v)
    return [x / s for x in v]


def _cosine_dot(a: Sequence[float], b: Sequence[float]) -> float:
    """이미 L2 정규화된 벡터끼리 내적 = 코사인 유사도."""
    return sum(x * y for x, y in zip(a, b))


@dataclass(frozen=True)
class VectorRecord:
    chunk_id: str
    vector: list[float]
    text: str
    source: str
    topic: str
    namespace: str
    license: str


def load_local_vector_index(path: Path) -> tuple[str, int, list[VectorRecord]]:
    with path.open(encoding="utf-8") as f:
        data = json.load(f)
    model = str(data.get("embedding_model", ""))
    dim = int(data.get("embedding_dimensions", 0))
    raw_records = data.get("records", [])
    if not isinstance(raw_records, list):
        raise ValueError("index 'records' must be a list")
    records: list[VectorRecord] = []
    for r in raw_records:
        if not isinstance(r, dict):
            continue
        vec = r.get("values")
        if not isinstance(vec, list):
            continue
        fv = [float(x) for x in vec]
        nv = _l2_normalize(fv)
        if dim and len(nv) != dim:
            raise ValueError(
                f"vector dim mismatch for id={r.get('id')}: expected {dim}, got {len(nv)}"
            )
        records.append(
            VectorRecord(
                chunk_id=str(r.get("id", "")),
                vector=nv,
                text=str(r.get("text", "")),
                source=str(r.get("source", "")),
                topic=str(r.get("topic", "")),
                namespace=str(r.get("namespace", "corpus")),
                license=str(r.get("license", "")),
            )
        )
    return model, dim or (len(records[0].vector) if records else 0), records


class LocalVectorRetriever:
    """corpus/vector_index.json — 코사인 top-k (메모리)."""

    def __init__(
        self,
        *,
        index_path: Path,
        embedder: SupportsEmbed,
        expected_model: Optional[str] = None,
        expected_dim: Optional[int] = None,
    ) -> None:
        model, dim, self._records = load_local_vector_index(index_path)
        self._embedder = embedder
        if expected_model and model and model != expected_model:
            logger.warning(
                "Local index embedding_model=%s differs from runtime OPENAI_EMBEDDING_MODEL=%s",
                model,
                expected_model,
            )
        if expected_dim and dim and expected_dim != dim:
            logger.warning(
                "Local index dim=%s may differ from runtime dimensions=%s",
                dim,
                expected_dim,
            )
        logger.info(
            "RAG local vector: %d records from %s (index model=%s dim=%s)",
            len(self._records),
            index_path,
            model,
            dim,
        )

    def retrieve(
        self,
        query: str,
        *,
        top_k: int = DEFAULT_TOP_K,
        namespace: Optional[str] = "corpus",
    ) -> list[RetrievedChunk]:
        if not query.strip() or not self._records:
            return []
        qv = _l2_normalize(self._embedder.embed_one(query))
        scored: list[tuple[float, VectorRecord]] = []
        for rec in self._records:
            if namespace is not None and rec.namespace != namespace:
                continue
            s = _cosine_dot(qv, rec.vector)
            scored.append((s, rec))
        scored.sort(key=lambda x: -x[0])
        out: list[RetrievedChunk] = []
        for s, rec in scored[:top_k]:
            out.append(
                RetrievedChunk(
                    chunk_id=rec.chunk_id,
                    text=rec.text,
                    source=rec.source,
                    topic=rec.topic,
                    score=float(s),
                )
            )
        return out


class PineconeRetriever:
    """Pinecone 서버리스 인덱스 쿼리 (upsert는 ingest 스크립트)."""

    def __init__(
        self,
        *,
        embedder: SupportsEmbed,
        index_name: str,
        pinecone_namespace: str = "corpus",
    ) -> None:
        from pinecone import Pinecone

        api_key = os.environ.get("PINECONE_API_KEY", "").strip()
        if not api_key:
            raise ValueError("PINECONE_API_KEY is required")
        pc = Pinecone(api_key=api_key)
        self._index = pc.Index(index_name)
        self._embedder = embedder
        self._pinecone_namespace = pinecone_namespace
        logger.info("RAG Pinecone index=%s namespace=%s", index_name, pinecone_namespace)

    def retrieve(
        self,
        query: str,
        *,
        top_k: int = DEFAULT_TOP_K,
        namespace: Optional[str] = "corpus",
    ) -> list[RetrievedChunk]:
        if not query.strip():
            return []
        qv = self._embedder.embed_one(query)
        ns = (namespace if namespace is not None else "") or self._pinecone_namespace
        res = self._index.query(
            vector=qv,
            top_k=top_k,
            namespace=ns,
            include_metadata=True,
        )
        matches = getattr(res, "matches", None) or []
        out: list[RetrievedChunk] = []
        for match in matches:
            md_raw = getattr(match, "metadata", None) or {}
            md = dict(md_raw) if hasattr(md_raw, "keys") else {}
            score = float(getattr(match, "score", 0.0))
            cid = str(getattr(match, "id", ""))
            text = str(md.get("text", ""))
            out.append(
                RetrievedChunk(
                    chunk_id=cid,
                    text=text,
                    source=str(md.get("source", "")),
                    topic=str(md.get("topic", "")),
                    score=score,
                )
            )
        return out
