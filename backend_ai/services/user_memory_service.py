"""유저 메모리 청크 검증·임베딩·Pinecone upsert."""

from __future__ import annotations

import hashlib
import logging
import os
from dataclasses import dataclass
from typing import Any, Optional

from services.embedder_factory import BatchEmbedder, build_embedder
from services.pinecone_batch import delete_namespace_all, upsert_vector_batches
from services.user_namespace import user_vector_namespace

logger = logging.getLogger(__name__)

MAX_CHUNKS_PER_REQUEST = 32
MAX_TEXT_PER_CHUNK = 8_000
MAX_TOTAL_INPUT_CHARS = 120_000
VECTOR_TEXT_META_CAP = 35_000


@dataclass(frozen=True)
class MemoryChunkIn:
    text: str
    source: str = ""
    topic: str = ""
    client_chunk_id: str = ""


def memory_api_enabled() -> bool:
    return os.getenv("MEMORY_API_ENABLED", "1").strip().lower() in (
        "1",
        "true",
        "yes",
    )


def validate_chunks(raw: list[dict[str, Any]]) -> list[MemoryChunkIn]:
    if len(raw) > MAX_CHUNKS_PER_REQUEST:
        raise ValueError(f"too many chunks (max {MAX_CHUNKS_PER_REQUEST})")
    total = 0
    out: list[MemoryChunkIn] = []
    for i, row in enumerate(raw):
        text = str(row.get("text", "")).strip()
        if not text:
            raise ValueError(f"chunk {i}: empty text")
        if len(text) > MAX_TEXT_PER_CHUNK:
            raise ValueError(f"chunk {i}: text exceeds max length")
        total += len(text)
        if total > MAX_TOTAL_INPUT_CHARS:
            raise ValueError("total text length exceeds limit")
        cid = str(row.get("client_chunk_id", "") or "").strip()
        out.append(
            MemoryChunkIn(
                text=text,
                source=str(row.get("source", "") or "")[:500],
                topic=str(row.get("topic", "") or "")[:500],
                client_chunk_id=cid,
            )
        )
    return out


def _vector_id(subject: str, chunk: MemoryChunkIn, index: int) -> str:
    key = chunk.client_chunk_id or f"idx_{index}|{hashlib.sha256(chunk.text.encode()).hexdigest()[:16]}"
    raw = f"{subject}|{key}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()[:32]


class UserMemoryService:
    def __init__(self, embedder: BatchEmbedder, index: Any) -> None:
        self._embedder = embedder
        self._index = index

    def upsert_for_subject(self, subject: str, chunks: list[MemoryChunkIn]) -> int:
        if not chunks:
            return 0
        namespace = user_vector_namespace(subject)
        texts = [c.text for c in chunks]
        vectors = self._embedder.embed_batch(texts)
        if len(vectors) != len(chunks):
            raise RuntimeError("embedding count mismatch")
        upsert_rows: list[dict[str, Any]] = []
        for i, (c, vec) in enumerate(zip(chunks, vectors)):
            vid = _vector_id(subject, c, i)
            text_meta = c.text[:VECTOR_TEXT_META_CAP]
            meta = {
                "text": text_meta,
                "source": c.source,
                "topic": c.topic,
                "namespace": namespace,
                "memory": "user",
            }
            upsert_rows.append({"id": vid, "values": vec, "metadata": meta})
        upsert_vector_batches(self._index, namespace, upsert_rows)
        logger.info("user memory upsert subject_ns=%s count=%d", namespace, len(upsert_rows))
        return len(upsert_rows)

    def delete_all_for_subject(self, subject: str) -> None:
        namespace = user_vector_namespace(subject)
        delete_namespace_all(self._index, namespace)
        logger.info("user memory deleted namespace=%s", namespace)


def build_user_memory_service() -> Optional["UserMemoryService"]:
    if not memory_api_enabled():
        return None
    from services.embedder_factory import embedding_credentials_ready

    pc_key = os.getenv("PINECONE_API_KEY", "").strip()
    index_name = os.getenv("PINECONE_INDEX_NAME", "").strip()
    if not (embedding_credentials_ready() and pc_key and index_name):
        logger.warning(
            "UserMemoryService disabled: missing embedding credentials or Pinecone env"
        )
        return None
    try:
        from pinecone import Pinecone

        pc = Pinecone(api_key=pc_key)
        index = pc.Index(index_name)
        embedder = build_embedder()
        return UserMemoryService(embedder=embedder, index=index)
    except Exception as e:
        logger.exception("UserMemoryService init failed: %s", e)
        return None
