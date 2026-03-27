"""SlowAPI Limiter 인스턴스 (파일명은 third-party `limits` 와 충돌 방지)."""

from __future__ import annotations

import os

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)


def coach_rate_limit_string() -> str:
    return os.getenv("COACH_RATE_LIMIT", "30/minute").strip() or "30/minute"
