"""Pinecone upsert 배치 유틸 (ingest 스크립트·런타임 메모리 공용)."""

from __future__ import annotations

from typing import Any, Sequence

DEFAULT_UPSERT_BATCH = 100


def upsert_vector_batches(
    index: Any,
    namespace: str,
    vectors: Sequence[dict[str, Any]],
    *,
    batch_size: int = DEFAULT_UPSERT_BATCH,
) -> None:
    """vectors: Pinecone upsert 항목 리스트 (id, values, metadata)."""
    batch: list[dict[str, Any]] = []
    for row in vectors:
        batch.append(row)
        if len(batch) >= batch_size:
            index.upsert(vectors=batch, namespace=namespace)
            batch = []
    if batch:
        index.upsert(vectors=batch, namespace=namespace)


def delete_namespace_all(index: Any, namespace: str) -> None:
    index.delete(delete_all=True, namespace=namespace)
