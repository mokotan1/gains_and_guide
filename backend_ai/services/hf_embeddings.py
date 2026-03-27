"""Hugging Face Inference API 기반 임베딩 (무료 티어 후보, Pinecone 차원=모델 출력)."""

from __future__ import annotations

import logging
import os
from typing import Optional, Sequence

logger = logging.getLogger(__name__)

DEFAULT_HF_EMBEDDING_MODEL = "sentence-transformers/all-MiniLM-L6-v2"
DEFAULT_HF_BATCH_SIZE = 16


class HuggingFaceApiEmbedder:
    """feature_extraction — 토큰은 HUGGINGFACE_API_TOKEN (무료 계정 가능)."""

    def __init__(
        self,
        *,
        api_token: str,
        model: Optional[str] = None,
        batch_size: int = DEFAULT_HF_BATCH_SIZE,
    ) -> None:
        if not api_token.strip():
            raise ValueError("HUGGINGFACE_API_TOKEN is required for huggingface embedding backend")
        self._model = (model or os.getenv("HF_EMBEDDING_MODEL") or DEFAULT_HF_EMBEDDING_MODEL).strip()
        self._batch_size = max(1, batch_size)
        from huggingface_hub import InferenceClient

        self._client = InferenceClient(token=api_token.strip())

    @property
    def model(self) -> str:
        return self._model

    @property
    def dimensions(self) -> Optional[int]:
        return None

    def _normalize_vector(self, raw: object) -> list[float]:
        if hasattr(raw, "tolist"):
            raw = raw.tolist()  # numpy ndarray from huggingface_hub
        if isinstance(raw, list) and raw and isinstance(raw[0], list):
            inner = raw[0]
            return [float(x) for x in inner]
        if isinstance(raw, list):
            return [float(x) for x in raw]
        raise TypeError(f"unexpected embedding shape: {type(raw)}")

    def embed_batch(self, texts: Sequence[str]) -> list[list[float]]:
        if not texts:
            return []
        out: list[list[float]] = []
        for i in range(0, len(texts), self._batch_size):
            batch = list(texts[i : i + self._batch_size])
            for t in batch:
                raw = self._client.feature_extraction(t, model=self._model)
                out.append(self._normalize_vector(raw))
        logger.debug("HF embedded %d texts model=%s", len(texts), self._model)
        return out

    def embed_one(self, text: str) -> list[float]:
        return self.embed_batch([text])[0]
