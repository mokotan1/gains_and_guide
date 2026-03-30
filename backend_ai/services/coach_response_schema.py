"""코치 /chat JSON 계약 검증 (Phase B)."""

from __future__ import annotations

from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, field_validator


class ProgressionItem(BaseModel):
    """증량 제안 한 항목 (Flutter applyProgression과 동일 계약)."""

    model_config = ConfigDict(extra="ignore")

    name: str
    increase: float

    @field_validator("name", mode="before")
    @classmethod
    def name_must_be_non_empty_str(cls, v: Any) -> str:
        if v is None:
            raise ValueError("progression item name is required")
        s = str(v).strip()
        if not s:
            raise ValueError("progression item name must be non-empty")
        return s

    @field_validator("increase", mode="before")
    @classmethod
    def increase_must_be_number(cls, v: Any) -> float:
        if isinstance(v, bool):
            raise ValueError("increase must be a number")
        if isinstance(v, (int, float)):
            return float(v)
        raise ValueError("increase must be a number")


class CoachChatResponse(BaseModel):
    """LLM·레거시 경로 공통 응답 스키마."""

    model_config = ConfigDict(extra="ignore")

    response: str
    routine: Optional[dict[str, Any]] = None
    progression: Optional[list[ProgressionItem]] = None

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

    @field_validator("progression", mode="before")
    @classmethod
    def progression_list_or_none(cls, v: Any) -> Any:
        if v is None:
            return None
        if isinstance(v, list):
            return v
        raise ValueError("progression must be an array or null")


def coerce_raw_coach_dict(data: dict[str, Any]) -> CoachChatResponse:
    """message 키 등 레거시 별칭을 흡수한 뒤 스키마 검증."""
    text = data.get("response")
    if text is None and "message" in data:
        text = data.get("message")
    payload = {
        "response": text,
        "routine": data.get("routine"),
        "progression": data.get("progression"),
    }
    return CoachChatResponse.model_validate(payload)
