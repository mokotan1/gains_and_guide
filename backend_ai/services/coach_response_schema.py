"""코치 /chat JSON 계약 검증 (Phase B)."""

from __future__ import annotations

from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, field_validator


class CoachChatResponse(BaseModel):
    """LLM·레거시 경로 공통 응답 스키마."""

    model_config = ConfigDict(extra="ignore")

    response: str
    routine: Optional[dict[str, Any]] = None

    @field_validator("response", mode="before")
    @classmethod
    def response_must_be_non_empty_str(cls, v: Any) -> str:
        if v is None:
            raise ValueError("response is required")
        if not isinstance(v, str):
            v = str(v)
        s = v.strip()
        if not s:
            raise ValueError("response must be non-empty")
        return s

    @field_validator("routine", mode="before")
    @classmethod
    def routine_dict_or_none(cls, v: Any) -> Optional[dict[str, Any]]:
        if v is None:
            return None
        if isinstance(v, dict):
            return v
        raise ValueError("routine must be an object or null")


def coerce_raw_coach_dict(data: dict[str, Any]) -> CoachChatResponse:
    """message 키 등 레거시 별칭을 흡수한 뒤 스키마 검증."""
    text = data.get("response")
    if text is None and "message" in data:
        text = data.get("message")
    payload = {"response": text, "routine": data.get("routine")}
    return CoachChatResponse.model_validate(payload)
