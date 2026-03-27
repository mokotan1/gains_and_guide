"""RAG 공용 타입·포맷터."""

from __future__ import annotations

from dataclasses import dataclass

DEFAULT_TOP_K = 5


@dataclass(frozen=True)
class RetrievedChunk:
    chunk_id: str
    text: str
    source: str
    topic: str
    score: float


def format_references(chunks: list[RetrievedChunk]) -> str:
    lines: list[str] = []
    for c in chunks:
        snippet = c.text if len(c.text) <= 600 else c.text[:597] + "..."
        lines.append(f"- [{c.chunk_id}] ({c.source} / {c.topic}) {snippet}")
    return "\n".join(lines)
