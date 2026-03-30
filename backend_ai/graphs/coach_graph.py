"""Groq + 도구 ReAct 그래프 (LangGraph prebuilt)."""

from __future__ import annotations

import json
import logging
import os
import re
from typing import Any, List

from langchain_core.messages import AIMessage, BaseMessage, HumanMessage, SystemMessage
from langchain_groq import ChatGroq
from langgraph.prebuilt import create_react_agent

from services.groq_settings import groq_max_completion_tokens, groq_model_name
from services.tools import COACH_TOOLS

logger = logging.getLogger(__name__)

DEFAULT_MODEL = groq_model_name()

_JSON_FINAL_INSTRUCTION = (
    "도구가 더 필요 없으면, 최종 메시지는 오직 하나의 JSON 객체만 포함해야 한다. "
    '키: "response" (문자열), "routine" (객체 또는 null), "progression" (배열 또는 null). '
    "마크다운 코드펜스나 추가 설명 없이 JSON만 출력한다."
)

COACH_SCHEMA_RETRY_USER_SUFFIX = (
    "\n\n[형식 복구]\n"
    "직전 최종 출력이 "
    '{"response": string, "routine": object|null, "progression": array|null} 규칙을 어겼다. '
    "도구 호출이 끝났다면 같은 키만 가진 JSON 한 객체만 다시 출력하라."
)


def _audit_tool_calls(messages: List[BaseMessage]) -> None:
    if os.getenv("COACH_AUDIT_TOOLS", "").strip().lower() not in ("1", "true", "yes"):
        return
    for m in messages:
        if not isinstance(m, AIMessage):
            continue
        tcs = getattr(m, "tool_calls", None) or []
        for tc in tcs:
            if isinstance(tc, dict):
                name = tc.get("name", "")
                tid = tc.get("id", "")
                args = tc.get("args", tc.get("function", {}))
            else:
                name = getattr(tc, "name", "") or ""
                tid = getattr(tc, "id", "") or ""
                args = getattr(tc, "args", None)
            logger.info(
                "coach_tool_audit name=%s id=%s args=%s",
                name,
                tid,
                args,
            )


def build_coach_agent(
    groq_api_key: str,
    model: str | None = None,
    *,
    max_tokens: int | None = None,
) -> Any:
    resolved_model = (model or "").strip() or groq_model_name()
    cap = max_tokens if max_tokens is not None else groq_max_completion_tokens()
    llm = ChatGroq(
        api_key=groq_api_key,
        model=resolved_model,
        temperature=0.7,
        max_tokens=cap,
    )
    return create_react_agent(llm, COACH_TOOLS)


def _parse_coach_json(content: str) -> dict[str, Any]:
    s = content.strip()
    if s.startswith("```"):
        s = re.sub(r"^```(?:json)?\s*", "", s, flags=re.IGNORECASE)
        s = re.sub(r"\s*```\s*$", "", s)
    try:
        data = json.loads(s)
        if isinstance(data, dict):
            merged = dict(data)
            merged.setdefault("progression", None)
            return merged
    except json.JSONDecodeError:
        pass
    return {"response": content, "routine": None, "progression": None}


def run_coach_agent(
    agent: Any,
    *,
    system_block: str,
    user_block: str,
    user_suffix: str = "",
) -> dict[str, Any]:
    user_full = user_block + (user_suffix or "")
    messages: List[BaseMessage] = [
        SystemMessage(content=system_block + "\n\n" + _JSON_FINAL_INSTRUCTION),
        HumanMessage(content=user_full),
    ]
    try:
        result = agent.invoke({"messages": messages})
    except Exception:
        logger.exception("coach agent invoke failed")
        raise
    out_messages: List[BaseMessage] = list(result.get("messages", []))
    _audit_tool_calls(out_messages)
    if not out_messages:
        return {
            "response": "응답을 생성하지 못했습니다.",
            "routine": None,
            "progression": None,
        }
    last = out_messages[-1]
    if isinstance(last, AIMessage):
        content = last.content
        if isinstance(content, str):
            return _parse_coach_json(content)
        if isinstance(content, list):
            text = "".join(
                part.get("text", "") if isinstance(part, dict) else str(part)
                for part in content
            )
            return _parse_coach_json(text)
        return _parse_coach_json(str(content))
    return {"response": str(last), "routine": None, "progression": None}
