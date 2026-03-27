"""코치 /chat·/recommend 엔드포인트."""

from __future__ import annotations

import json
import logging
import os
from typing import Any, Optional

from fastapi import APIRouter, HTTPException
from groq import Groq
from pydantic import BaseModel

import catalog
import prompts
from graphs.coach_graph import run_coach_agent
from services.rag import format_references
from state import app_deps

logger = logging.getLogger(__name__)

router = APIRouter()


class ChatRequest(BaseModel):
    user_id: str
    message: str
    context: str = ""


class RecommendRequest(BaseModel):
    user_id: str
    weekly_summary: str


def _rag_top_k() -> int:
    try:
        return int(os.getenv("RAG_TOP_K", "5"))
    except ValueError:
        return 5


def _use_legacy_chat() -> bool:
    return os.getenv("USE_LEGACY_CHAT", "").strip().lower() in ("1", "true", "yes")


def _build_chat_system_base(user_message: str) -> str:
    if not app_deps.assets:
        raise HTTPException(status_code=500, detail="프롬프트 자산이 로드되지 않았습니다.")
    s = prompts.append_routine_guide(
        app_deps.assets.system_prompt, app_deps.assets.routine_guide_text
    )
    s = prompts.append_catalog(s, catalog.exercise_catalog_text)
    if app_deps.rag:
        chunks = app_deps.rag.retrieve(user_message, top_k=_rag_top_k())
        if chunks:
            s += "\n\n[References — 코퍼스 RAG]\n" + format_references(chunks)
    return s


def _build_recommend_system_base(weekly_summary: str) -> str:
    if not app_deps.assets:
        raise HTTPException(status_code=500, detail="프롬프트 자산이 로드되지 않았습니다.")
    s = prompts.append_routine_guide(
        app_deps.assets.routine_system_prompt, app_deps.assets.routine_guide_text
    )
    s = prompts.append_catalog(s, catalog.exercise_catalog_text)
    if app_deps.rag:
        chunks = app_deps.rag.retrieve(weekly_summary, top_k=_rag_top_k())
        if chunks:
            s += "\n\n[References — 코퍼스 RAG]\n" + format_references(chunks)
    return s


def _legacy_chat_completion(
    client: Groq, system_prompt: str, user_content: str
) -> dict[str, Any]:
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_content},
    ]
    chat_completion = client.chat.completions.create(
        messages=messages,
        model="llama-3.1-8b-instant",
        temperature=0.7,
        max_tokens=1024,
        response_format={"type": "json_object"},
    )
    reply = chat_completion.choices[0].message.content
    if not reply:
        return {"response": "빈 응답", "routine": None}
    try:
        parsed_reply = json.loads(reply)
        text_response = (
            parsed_reply.get("response")
            or parsed_reply.get("message")
            or "답변 내용을 찾을 수 없습니다."
        )
        return {
            "response": text_response,
            "routine": catalog.localize_routine_exercise_names(
                parsed_reply.get("routine")
            ),
        }
    except json.JSONDecodeError:
        return {"response": reply, "routine": None}


@router.post("/chat")
async def chat_with_coach(request: ChatRequest) -> dict[str, Any]:
    if not app_deps.groq_client or not app_deps.groq_api_key:
        raise HTTPException(status_code=500, detail="서버에 Groq API 키가 없습니다.")

    system_prompt = _build_chat_system_base(request.message)
    user_content = (
        f"[과거 운동 기록]\n{request.context}\n\n[질문]\n{request.message}"
    )

    if _use_legacy_chat() or not app_deps.coach_agent:
        try:
            return _legacy_chat_completion(
                app_deps.groq_client, system_prompt, user_content
            )
        except Exception as e:
            logger.exception("legacy chat failed")
            raise HTTPException(status_code=500, detail=str(e)) from e

    try:
        parsed = run_coach_agent(
            app_deps.coach_agent,
            system_block=system_prompt,
            user_block=user_content,
        )
        text_response = (
            parsed.get("response")
            or parsed.get("message")
            or "답변 내용을 찾을 수 없습니다."
        )
        return {
            "response": text_response,
            "routine": catalog.localize_routine_exercise_names(parsed.get("routine")),
        }
    except Exception as e:
        logger.exception("agent chat failed, falling back to legacy JSON chat")
        try:
            return _legacy_chat_completion(
                app_deps.groq_client, system_prompt, user_content
            )
        except Exception:
            raise HTTPException(status_code=500, detail=str(e)) from e


@router.post("/recommend")
async def recommend_routine(request: RecommendRequest) -> dict[str, Any]:
    if not app_deps.groq_client:
        raise HTTPException(status_code=500, detail="서버에 Groq API 키가 없습니다.")

    system_prompt = _build_recommend_system_base(request.weekly_summary)
    messages = [
        {"role": "system", "content": system_prompt},
        {
            "role": "user",
            "content": (
                f"[주간 운동 분석 데이터]\n{request.weekly_summary}\n\n"
                "[지시]\n위 분석 데이터를 바탕으로 다음 주 추천 루틴을 JSON으로 생성해주세요."
            ),
        },
    ]

    reply: Optional[str] = None
    try:
        chat_completion = app_deps.groq_client.chat.completions.create(
            messages=messages,
            model="llama-3.1-8b-instant",
            temperature=0.7,
            max_tokens=1024,
            response_format={"type": "json_object"},
        )
        reply = chat_completion.choices[0].message.content
        if not reply:
            raise HTTPException(status_code=500, detail="AI 응답이 비어 있습니다.")
        parsed_reply = json.loads(reply)
        routine = parsed_reply.get("routine")
        if routine is None:
            return {
                "routine": {
                    "title": "기본 추천 루틴",
                    "rationale": "분석 데이터 기반 기본 루틴입니다.",
                    "exercises": [],
                }
            }
        return {"routine": catalog.localize_routine_exercise_names(routine)}
    except json.JSONDecodeError:
        logger.error("JSON 파싱 실패: %s", reply)
        raise HTTPException(status_code=500, detail="AI 응답 파싱에 실패했습니다.") from None
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("루틴 추천 생성 중 오류")
        raise HTTPException(status_code=500, detail=str(e)) from e
