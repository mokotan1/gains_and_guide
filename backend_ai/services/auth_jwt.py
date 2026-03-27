"""익명 사용자용 HS256 JWT 발급·검증 (Firebase 등으로 교체 가능)."""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any

import jwt

DEFAULT_TOKEN_TTL_DAYS = 365


def jwt_secret() -> str | None:
    s = os.getenv("AUTH_JWT_SECRET", "").strip()
    return s or None


def issue_anonymous_token(
    secret: str,
    *,
    ttl_days: int | None = None,
) -> tuple[str, str]:
    """Returns (jwt_token, subject)."""
    sub = f"anon_{uuid.uuid4().hex}"
    days = ttl_days if ttl_days is not None else DEFAULT_TOKEN_TTL_DAYS
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": sub,
        "iat": now,
        "exp": now + timedelta(days=days),
        "typ": "anonymous",
    }
    token = jwt.encode(payload, secret, algorithm="HS256")
    if isinstance(token, bytes):
        token = token.decode("ascii")
    return token, sub


def verify_bearer_token(token: str, secret: str) -> str:
    data = jwt.decode(
        token,
        secret,
        algorithms=["HS256"],
        options={"require": ["sub", "exp"]},
    )
    if data.get("typ") != "anonymous":
        raise jwt.InvalidTokenError("unexpected token typ")
    return str(data["sub"])
