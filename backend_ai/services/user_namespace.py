"""벡터 저장소용 사용자 네임스페이스 (PII·로그 노출 최소화)."""

from __future__ import annotations

import hashlib
import os


def user_vector_namespace(subject: str) -> str:
    """
    Pinecone namespace: ASCII, 고정 길이에 가깝게.
    `AUTH_NAMESPACE_SALT` 가 없으면 `AUTH_JWT_SECRET` 을 소금으로 사용 (개발 편의).
    """
    salt = (os.getenv("AUTH_NAMESPACE_SALT") or os.getenv("AUTH_JWT_SECRET") or "dev-only-salt").strip()
    h = hashlib.sha256(f"{salt}|{subject}".encode("utf-8")).hexdigest()[:24]
    return f"u_{h}"
