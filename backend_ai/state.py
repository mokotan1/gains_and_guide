"""앱 전역 의존성 (테스트에서 교체 가능)."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Optional

from groq import Groq

from prompts import PromptAssets
from services.rag import RagService


@dataclass
class AppDependencies:
    """chat_completion_client: Groq 또는 OpenAI SDK 인스턴스(Ollama 호환)."""

    groq_client: Optional[Groq] = None
    groq_api_key: Optional[str] = None
    chat_completion_client: Any = None
    llm_chat_provider: str = "none"
    assets: Optional[PromptAssets] = None
    rag: Optional[RagService] = None
    coach_agent: Any = None


app_deps = AppDependencies()
