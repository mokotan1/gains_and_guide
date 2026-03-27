"""RAG 공용 타입·포맷터."""

from __future__ import annotations

import os
from dataclasses import dataclass

DEFAULT_TOP_K = 5
_DEFAULT_RAG_SNIPPET_MAX = 600
_MIN_RAG_SNIPPET = 80


@dataclass(frozen=True)
class RetrievedChunk:
    chunk_id: str
    text: str
    source: str
    topic: str
    score: float


def rag_snippet_max_chars_from_env() -> int:
    raw = os.getenv("RAG_SNIPPET_MAX_CHARS", str(_DEFAULT_RAG_SNIPPET_MAX)).strip()
    try:
        return max(_MIN_RAG_SNIPPET, int(raw))
    except ValueError:
        return _DEFAULT_RAG_SNIPPET_MAX


def format_references(
    chunks: list[RetrievedChunk], *, max_snippet_chars: int | None = None
) -> str:
    cap = (
        max_snippet_chars
        if max_snippet_chars is not None
        else rag_snippet_max_chars_from_env()
    )
    cap = max(_MIN_RAG_SNIPPET, cap)
    lines: list[str] = []
    for c in chunks:
        if len(c.text) <= cap:
            snippet = c.text
        else:
            snippet = c.text[: max(1, cap - 3)] + "..."
        lines.append(f"- [{c.chunk_id}] ({c.source} / {c.topic}) {snippet}")
    return "\n".join(lines)
