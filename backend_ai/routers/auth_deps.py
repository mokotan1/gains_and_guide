"""Bearer JWT 및 레거시 user_id 바디 병행 해석."""

from __future__ import annotations

import logging
import os

import jwt
from fastapi import HTTPException, Request

from services.auth_jwt import jwt_secret, verify_bearer_token
from services.supabase_jwt import supabase_jwks_configured, try_verify_supabase_subject

logger = logging.getLogger(__name__)


def auth_configured() -> bool:
    return jwt_secret() is not None or supabase_jwks_configured()


def resolve_request_subject(request: Request, body_user_id: str) -> str:
    """
    Supabase JWKS(SUPABASE_JWKS_URL + SUPABASE_JWT_ISS)가 있으면 Bearer를 Supabase JWT로 먼저 검증.
    AUTH_JWT_SECRET 이 있으면 익명 HS256 JWT도 허용(위가 실패한 경우).
    둘 다 없으면 레거시: 바디 user_id.
    """
    secret = jwt_secret()
    use_supabase = supabase_jwks_configured()

    if not secret and not use_supabase:
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

    sub: str | None = None
    if use_supabase:
        sub = try_verify_supabase_subject(token)

    if sub is None and secret:
        try:
            sub = verify_bearer_token(token, secret)
        except jwt.ExpiredSignatureError:
            raise HTTPException(status_code=401, detail="Token expired") from None
        except jwt.InvalidTokenError as e:
            logger.debug("invalid jwt: %s", e)
            raise HTTPException(status_code=401, detail="Invalid token") from None

    if sub is None:
        raise HTTPException(status_code=401, detail="Invalid token")

    if body_user_id.strip() and body_user_id.strip() != sub:
        raise HTTPException(status_code=403, detail="user_id does not match token subject")
    return sub


def require_memory_subject(request: Request) -> str:
    secret = jwt_secret()
    use_supabase = supabase_jwks_configured()
    if not secret and not use_supabase:
        raise HTTPException(
            status_code=503,
            detail="Memory API requires AUTH_JWT_SECRET or Supabase JWKS env",
        )
    auth = request.headers.get("Authorization") or ""
    if not auth.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Authorization Bearer token required")
    token = auth[7:].strip()

    if use_supabase:
        sub = try_verify_supabase_subject(token)
        if sub is not None:
            return sub

    if secret:
        try:
            return verify_bearer_token(token, secret)
        except jwt.ExpiredSignatureError:
            raise HTTPException(status_code=401, detail="Token expired") from None
        except jwt.InvalidTokenError as e:
            logger.debug("invalid jwt: %s", e)
            raise HTTPException(status_code=401, detail="Invalid token") from None

    raise HTTPException(status_code=401, detail="Invalid token")
