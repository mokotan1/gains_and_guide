"""Groq API 공통 설정 (모델·출력 토큰 상한)."""

from __future__ import annotations

import os

_DEFAULT_MODEL = "llama-3.1-8b-instant"
# Groq on_demand 는 요청당 TPM 한도가 낮아, 입력+출력 상한 합이 초과되기 쉽다.
_DEFAULT_MAX_COMPLETION = 512
_MIN_MAX_COMPLETION = 256


def groq_model_name() -> str:
    return os.getenv("GROQ_MODEL", _DEFAULT_MODEL).strip() or _DEFAULT_MODEL


def groq_max_completion_tokens() -> int:
    raw = os.getenv("GROQ_MAX_COMPLETION_TOKENS", str(_DEFAULT_MAX_COMPLETION)).strip()
    try:
        return max(_MIN_MAX_COMPLETION, int(raw))
    except ValueError:
        return _DEFAULT_MAX_COMPLETION
