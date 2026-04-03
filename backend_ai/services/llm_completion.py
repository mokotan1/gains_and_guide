"""Groq 또는 OpenAI 호환 API(Ollama `/v1` 등)로 chat.completions 를 통일한다."""

from __future__ import annotations

import os
from typing import Any, Tuple

from groq import Groq

from services.groq_settings import groq_max_completion_tokens, groq_model_name


def openai_compat_model_name() -> str:
    return os.getenv("OPENAI_COMPAT_MODEL", "llama3.2").strip() or "llama3.2"


def build_chat_completion_client() -> Tuple[Any | None, str]:
    """
    (client, provider) 반환. provider 는 'openai_compat' | 'groq' | 'none'.
    """
    if os.getenv("LLM_CHAT_PROVIDER", "").strip().lower() == "openai_compat":
        base = os.getenv("OPENAI_COMPAT_BASE_URL", "").strip()
        if not base:
            return None, "none"
        from openai import OpenAI

        key = os.getenv("OPENAI_COMPAT_API_KEY", "ollama").strip() or "ollama"
        return OpenAI(base_url=base, api_key=key), "openai_compat"

    gkey = os.getenv("GROQ_API_KEY", "").strip()
    if gkey:
        return Groq(api_key=gkey), "groq"
    return None, "none"


def completion_model_name(provider: str) -> str:
    if provider == "openai_compat":
        return openai_compat_model_name()
    return groq_model_name()


def chat_completion_create(
    client: Any,
    messages: list[dict[str, str]],
    *,
    provider: str,
    max_completion_tokens: int | None = None,
) -> Any:
    cap = groq_max_completion_tokens()
    if max_completion_tokens is not None:
        cap = min(cap, max(256, max_completion_tokens))
    kwargs: dict[str, Any] = {
        "model": completion_model_name(provider),
        "messages": messages,
        "temperature": 0.7,
        "max_tokens": cap,
        "response_format": {"type": "json_object"},
    }
    return client.chat.completions.create(**kwargs)
