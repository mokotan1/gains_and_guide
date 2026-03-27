"""EMBEDDING_BACKEND 환경변수로 OpenAI / Hugging Face 임베더 선택."""

from __future__ import annotations

import os
from typing import Any, Optional, Protocol, Sequence

from services.embeddings import OpenAIEmbedder


class BatchEmbedder(Protocol):
    @property
    def model(self) -> str: ...

    @property
    def dimensions(self) -> Optional[int]: ...

    def embed_batch(self, texts: Sequence[str]) -> list[list[float]]: ...

    def embed_one(self, text: str) -> list[float]: ...


def embedding_backend_name() -> str:
    return os.getenv("EMBEDDING_BACKEND", "openai").strip().lower()


def embedding_credentials_ready() -> bool:
    """Pinecone·로컬 벡터·메모리에 쓸 임베딩을 만들 수 있는지."""
    b = embedding_backend_name()
    if b == "huggingface":
        return bool(os.getenv("HUGGINGFACE_API_TOKEN", "").strip())
    return bool(os.getenv("OPENAI_API_KEY", "").strip())


def build_embedder(*, batch_size: int = 64) -> BatchEmbedder:
    """OPENAI_API_KEY 또는 HUGGINGFACE_API_TOKEN 등 환경 기준."""
    b = embedding_backend_name()
    if b == "huggingface":
        from services.hf_embeddings import HuggingFaceApiEmbedder

        token = os.getenv("HUGGINGFACE_API_TOKEN", "").strip()
        return HuggingFaceApiEmbedder(api_token=token, batch_size=min(batch_size, 32))
    if b not in ("openai", ""):
        raise ValueError(f"Unknown EMBEDDING_BACKEND={b!r} (use openai or huggingface)")
    key = os.getenv("OPENAI_API_KEY", "").strip()
    return OpenAIEmbedder(api_key=key, batch_size=batch_size)


def build_embedder_or_raise(**kwargs: Any) -> BatchEmbedder:
    try:
        return build_embedder(**kwargs)
    except ValueError as e:
        raise RuntimeError(str(e)) from e
