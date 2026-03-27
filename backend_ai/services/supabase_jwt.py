"""Supabase Auth JWT 검증 (JWKS, RS256/ES256). 익명 HS256과 병행 가능."""

from __future__ import annotations

import logging
import os
from typing import Optional

import jwt
from jwt import PyJWKClient

logger = logging.getLogger(__name__)


def supabase_jwks_configured() -> bool:
    return bool(
        os.getenv("SUPABASE_JWKS_URL", "").strip()
        and os.getenv("SUPABASE_JWT_ISS", "").strip()
    )


def supabase_jwks_url() -> Optional[str]:
    u = os.getenv("SUPABASE_JWKS_URL", "").strip()
    return u or None


def supabase_jwt_issuer() -> Optional[str]:
    u = os.getenv("SUPABASE_JWT_ISS", "").strip()
    return u or None


def supabase_jwt_audience() -> str:
    return os.getenv("SUPABASE_JWT_AUD", "authenticated").strip() or "authenticated"


def try_verify_supabase_subject(token: str) -> Optional[str]:
    """
    유효한 Supabase access JWT면 sub 반환, 아니면 None (다른 방식 검증 시도용).
    """
    url = supabase_jwks_url()
    iss = supabase_jwt_issuer()
    if not url or not iss:
        return None
    try:
        jwks_client = PyJWKClient(url)
        signing_key = jwks_client.get_signing_key_from_jwt(token)
        payload = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256", "ES256"],
            audience=supabase_jwt_audience(),
            issuer=iss,
        )
        sub = payload.get("sub")
        return str(sub) if sub else None
    except jwt.exceptions.PyJWTError as e:
        logger.debug("not a valid Supabase JWT: %s", e)
        return None
    except Exception as e:
        logger.warning("Supabase JWKS verification error: %s", e)
        return None
