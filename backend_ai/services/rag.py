"""코퍼스 RAG: 임베딩 없이 토큰 겹침(Jaccard)으로 top-k (MVP)."""

from __future__ import annotations

import json
import logging
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional

logger = logging.getLogger(__name__)

_TOKEN_RE = re.compile(r"[\w가-힣]+", re.UNICODE)

DEFAULT_TOP_K = 5


@dataclass(frozen=True)
class RetrievedChunk:
    chunk_id: str
    text: str
    source: str
    topic: str
    score: float


def _tokens(s: str) -> set[str]:
    return {t.lower() for t in _TOKEN_RE.findall(s)}


class RagService:
    """corpus/*.jsonl 줄 단위 청크를 메모리에 올려 검색한다."""

    def __init__(self, chunks_path: Optional[str | Path] = None) -> None:
        self._chunks: list[dict[str, Any]] = []
        path = Path(chunks_path) if chunks_path else None
        if path and path.is_file():
            try:
                with path.open(encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if not line:
                            continue
                        self._chunks.append(json.loads(line))
                logger.info("RAG: loaded %d chunks from %s", len(self._chunks), path)
            except (OSError, json.JSONDecodeError) as e:
                logger.error("RAG: failed to load %s: %s", path, e)
        elif path:
            logger.warning("RAG: chunks file missing, retrieval disabled (%s)", path)

        self._token_cache: list[tuple[dict[str, Any], set[str]]] = [
            (c, _tokens(c.get("text", ""))) for c in self._chunks
        ]

    @property
    def chunk_count(self) -> int:
        return len(self._chunks)

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


def format_references(chunks: list[RetrievedChunk]) -> str:
    lines: list[str] = []
    for c in chunks:
        snippet = c.text if len(c.text) <= 600 else c.text[:597] + "..."
        lines.append(f"- [{c.chunk_id}] ({c.source} / {c.topic}) {snippet}")
    return "\n".join(lines)
