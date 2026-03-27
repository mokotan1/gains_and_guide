"""Groq + 도구 ReAct 그래프 (LangGraph prebuilt)."""

from __future__ import annotations

import json
import logging
import re
from typing import Any, List

from langchain_core.messages import AIMessage, BaseMessage, HumanMessage, SystemMessage
from langchain_groq import ChatGroq
from langgraph.prebuilt import create_react_agent

from services.tools import COACH_TOOLS

logger = logging.getLogger(__name__)

DEFAULT_MODEL = "llama-3.1-8b-instant"

_JSON_FINAL_INSTRUCTION = (
    "도구가 더 필요 없으면, 최종 메시지는 오직 하나의 JSON 객체만 포함해야 한다. "
    '키: "response" (문자열), "routine" (객체 또는 null). '
    "마크다운 코드펜스나 추가 설명 없이 JSON만 출력한다."
)


def build_coach_agent(groq_api_key: str, model: str = DEFAULT_MODEL) -> Any:
    llm = ChatGroq(api_key=groq_api_key, model=model, temperature=0.7)
    return create_react_agent(llm, COACH_TOOLS)


def _parse_coach_json(content: str) -> dict[str, Any]:
    s = content.strip()
    if s.startswith("```"):
        s = re.sub(r"^```(?:json)?\s*", "", s, flags=re.IGNORECASE)
        s = re.sub(r"\s*```\s*$", "", s)
    try:
        data = json.loads(s)
        if isinstance(data, dict):
            return data
    except json.JSONDecodeError:
        pass
    return {"response": content, "routine": None}


def run_coach_agent(
    agent: Any,
    *,
    system_block: str,
    user_block: str,
) -> dict[str, Any]:
    messages: List[BaseMessage] = [
        SystemMessage(content=system_block + "\n\n" + _JSON_FINAL_INSTRUCTION),
        HumanMessage(content=user_block),
    ]
    try:
        result = agent.invoke({"messages": messages})
    except Exception:
        logger.exception("coach agent invoke failed")
        raise
    out_messages: List[BaseMessage] = list(result.get("messages", []))
    if not out_messages:
        return {"response": "응답을 생성하지 못했습니다.", "routine": None}
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
    return {"response": str(last), "routine": None}
