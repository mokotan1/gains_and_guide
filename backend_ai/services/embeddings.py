"""OpenAI 임베딩 API (문서·쿼리 동일 모델)."""

from __future__ import annotations

import logging
import os
from typing import Optional, Sequence

logger = logging.getLogger(__name__)

DEFAULT_EMBEDDING_MODEL = "text-embedding-3-small"
DEFAULT_BATCH_SIZE = 64


class OpenAIEmbedder:
    """text-embedding-3-small 등 단일 모델로 배치 임베딩."""

    def __init__(
        self,
        *,
        api_key: str,
        model: Optional[str] = None,
        dimensions: Optional[int] = None,
        batch_size: int = DEFAULT_BATCH_SIZE,
    ) -> None:
        if not api_key.strip():
            raise ValueError("OpenAI API key is required for embeddings")
        self._model = (model or os.getenv("OPENAI_EMBEDDING_MODEL") or DEFAULT_EMBEDDING_MODEL).strip()
        self._dimensions = dimensions
        if self._dimensions is None:
            raw = os.getenv("OPENAI_EMBEDDING_DIMENSIONS", "").strip()
            if raw:
                try:
                    self._dimensions = int(raw)
                except ValueError:
                    self._dimensions = None
        self._batch_size = max(1, batch_size)
        from openai import OpenAI

        self._client = OpenAI(api_key=api_key)

    @property
    def model(self) -> str:
        return self._model

    @property
    def dimensions(self) -> Optional[int]:
        return self._dimensions

    def embed_batch(self, texts: Sequence[str]) -> list[list[float]]:
        """여러 텍스트를 한 번에 임베딩한다. 빈 입력은 제외하지 않고 호출자가 관리."""
        if not texts:
            return []
        out: list[list[float]] = []
        for i in range(0, len(texts), self._batch_size):
            batch = list(texts[i : i + self._batch_size])
            kwargs: dict = {"model": self._model, "input": batch}
            if self._dimensions is not None:
                kwargs["dimensions"] = self._dimensions
            resp = self._client.embeddings.create(**kwargs)
            by_index = {item.index: item.embedding for item in resp.data}
            for j in range(len(batch)):
                out.append(by_index[j])
        logger.debug("Embedded %d texts with model=%s", len(texts), self._model)
        return out

    def embed_one(self, text: str) -> list[float]:
        return self.embed_batch([text])[0]
