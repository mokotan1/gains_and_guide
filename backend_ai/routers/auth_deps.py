"""Bearer JWT 및 레거시 user_id 바디 병행 해석."""

from __future__ import annotations

import logging
import os

import jwt
from fastapi import HTTPException, Request

from services.auth_jwt import jwt_secret, verify_bearer_token

logger = logging.getLogger(__name__)


def auth_configured() -> bool:
    return jwt_secret() is not None


def resolve_request_subject(request: Request, body_user_id: str) -> str:
    """
    AUTH_JWT_SECRET 이 있으면 Bearer 필수, sub 반환. 바디 user_id 가 있으면 sub 와 일치해야 함.
    없으면 레거시: 바디 user_id 그대로.
    """
    secret = jwt_secret()
    if not secret:
        if not body_user_id.strip():
            raise HTTPException(
                status_code=401,
                detail="user_id is required when server JWT auth is disabled",
            )
        return body_user_id.strip()

    auth = request.headers.get("Authorization") or ""
    if not auth.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail="Authorization Bearer token required",
        )
    token = auth[7:].strip()
    try:
        sub = verify_bearer_token(token, secret)
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired") from None
    except jwt.InvalidTokenError as e:
        logger.debug("invalid jwt: %s", e)
        raise HTTPException(status_code=401, detail="Invalid token") from None

    if body_user_id.strip() and body_user_id.strip() != sub:
        raise HTTPException(status_code=403, detail="user_id does not match token subject")
    return sub


def require_memory_subject(request: Request) -> str:
    secret = jwt_secret()
    if not secret:
        raise HTTPException(
            status_code=503,
            detail="Memory API requires AUTH_JWT_SECRET to be configured",
        )
    auth = request.headers.get("Authorization") or ""
    if not auth.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer token required")
    token = auth[7:].strip()
    try:
        return verify_bearer_token(token, secret)
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired") from None
    except jwt.InvalidTokenError as e:
        logger.debug("invalid jwt: %s", e)
        raise HTTPException(status_code=401, detail="Invalid token") from None
