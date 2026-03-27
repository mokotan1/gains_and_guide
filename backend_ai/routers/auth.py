"""익명 JWT 발급."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException

from services.auth_jwt import issue_anonymous_token, jwt_secret

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/anonymous")
def post_anonymous_token() -> dict[str, str]:
    secret = jwt_secret()
    if not secret:
        raise HTTPException(
            status_code=503,
            detail="AUTH_JWT_SECRET is not configured on the server",
        )
    token, sub = issue_anonymous_token(secret)
    return {
        "access_token": token,
        "token_type": "bearer",
        "subject": sub,
    }
