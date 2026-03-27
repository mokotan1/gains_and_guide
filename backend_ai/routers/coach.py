"""코치 /chat·/recommend 엔드포인트."""

from __future__ import annotations

import asyncio
import json
import logging
import os
from typing import Any, Optional

from fastapi import APIRouter, HTTPException, Request
from groq import Groq
from pydantic import BaseModel, ValidationError

import catalog
import prompts
from graphs.coach_graph import COACH_SCHEMA_RETRY_USER_SUFFIX, run_coach_agent
from rate_limits import coach_rate_limit_string, limiter
from services.coach_response_schema import CoachChatResponse, coerce_raw_coach_dict
from services.rag import format_references
from state import app_deps

logger = logging.getLogger(__name__)

router = APIRouter()

_COACH_RATE_LIMIT = coach_rate_limit_string()


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


def _coach_timeout_sec() -> float:
    try:
        return float(os.getenv("COACH_REQUEST_TIMEOUT_SEC", "90"))
    except ValueError:
        return 90.0


def _expose_internal_errors() -> bool:
    return os.getenv("EXPOSE_INTERNAL_ERRORS", "").strip().lower() in ("1", "true", "yes")


def _public_error_message(exc: BaseException) -> str:
    if _expose_internal_errors():
        return str(exc)
    return "일시적인 오류가 발생했습니다. 잠시 후 다시 시도해 주세요."


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


def _coerce_chat_response(raw: dict[str, Any]) -> CoachChatResponse:
    return coerce_raw_coach_dict(raw)


async def _run_agent_with_timeout(
    system_prompt: str, user_content: str, *, user_suffix: str = ""
) -> dict[str, Any]:
    if not app_deps.coach_agent:
        raise RuntimeError("coach agent not configured")

    def _call() -> dict[str, Any]:
        return run_coach_agent(
            app_deps.coach_agent,
            system_block=system_prompt,
            user_block=user_content,
            user_suffix=user_suffix,
        )

    return await asyncio.wait_for(
        asyncio.to_thread(_call),
        timeout=_coach_timeout_sec(),
    )


@router.post("/chat")
@limiter.limit(_COACH_RATE_LIMIT)
async def chat_with_coach(request: Request, body: ChatRequest) -> dict[str, Any]:
    _ = request
    if not app_deps.groq_client or not app_deps.groq_api_key:
        raise HTTPException(status_code=500, detail="서버에 Groq API 키가 없습니다.")

    system_prompt = _build_chat_system_base(body.message)
    user_content = (
        f"[과거 운동 기록]\n{body.context}\n\n[질문]\n{body.message}"
    )

    if _use_legacy_chat() or not app_deps.coach_agent:
        try:
            raw = _legacy_chat_completion(
                app_deps.groq_client, system_prompt, user_content
            )
            try:
                v = _coerce_chat_response(raw)
            except ValidationError:
                v = CoachChatResponse(
                    response=str(raw.get("response", "응답을 처리하지 못했습니다.")),
                    routine=None,
                )
            return {
                "response": v.response,
                "routine": catalog.localize_routine_exercise_names(v.routine),
            }
        except Exception as e:
            logger.exception("legacy chat failed")
            raise HTTPException(
                status_code=500, detail=_public_error_message(e)
            ) from e

    try:
        parsed = await _run_agent_with_timeout(system_prompt, user_content)
        try:
            v = _coerce_chat_response(parsed)
        except ValidationError:
            logger.warning("agent output failed schema; retry once")
            parsed2 = await _run_agent_with_timeout(
                system_prompt,
                user_content,
                user_suffix=COACH_SCHEMA_RETRY_USER_SUFFIX,
            )
            try:
                v = _coerce_chat_response(parsed2)
            except ValidationError:
                logger.warning("agent retry failed schema; falling back to legacy JSON")
                raw = _legacy_chat_completion(
                    app_deps.groq_client, system_prompt, user_content
                )
                try:
                    v = _coerce_chat_response(raw)
                except ValidationError:
                    v = CoachChatResponse(
                        response=str(
                            parsed2.get("response", parsed.get("response", ""))
                        )
                        or "답변 형식을 확인하지 못했습니다.",
                        routine=None,
                    )
        return {
            "response": v.response,
            "routine": catalog.localize_routine_exercise_names(v.routine),
        }
    except asyncio.TimeoutError:
        logger.error("coach agent timeout after %ss", _coach_timeout_sec())
        raise HTTPException(
            status_code=504,
            detail="응답 생성이 시간 초과되었습니다. 짧은 질문으로 다시 시도해 주세요.",
        ) from None
    except Exception as e:
        logger.exception("agent chat failed, falling back to legacy JSON chat")
        try:
            raw = _legacy_chat_completion(
                app_deps.groq_client, system_prompt, user_content
            )
            try:
                v = _coerce_chat_response(raw)
            except ValidationError:
                v = CoachChatResponse(
                    response=str(raw.get("response", "응답을 처리하지 못했습니다.")),
                    routine=None,
                )
            return {
                "response": v.response,
                "routine": catalog.localize_routine_exercise_names(v.routine),
            }
        except Exception:
            raise HTTPException(
                status_code=500, detail=_public_error_message(e)
            ) from e


@router.post("/recommend")
@limiter.limit(_COACH_RATE_LIMIT)
async def recommend_routine(request: Request, body: RecommendRequest) -> dict[str, Any]:
    _ = request
    if not app_deps.groq_client:
        raise HTTPException(status_code=500, detail="서버에 Groq API 키가 없습니다.")

    system_prompt = _build_recommend_system_base(body.weekly_summary)
    messages = [
        {"role": "system", "content": system_prompt},
        {
            "role": "user",
            "content": (
                f"[주간 운동 분석 데이터]\n{body.weekly_summary}\n\n"
                "[지시]\n위 분석 데이터를 바탕으로 다음 주 추천 루틴을 JSON으로 생성해주세요."
            ),
        },
    ]

    reply: Optional[str] = None
    try:

        def _groq_call() -> Any:
            return app_deps.groq_client.chat.completions.create(
                messages=messages,
                model="llama-3.1-8b-instant",
                temperature=0.7,
                max_tokens=1024,
                response_format={"type": "json_object"},
            )

        chat_completion = await asyncio.wait_for(
            asyncio.to_thread(_groq_call),
            timeout=_coach_timeout_sec(),
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
        if not isinstance(routine, dict):
            raise HTTPException(
                status_code=500, detail="AI 루틴 형식이 올바르지 않습니다."
            )
        return {"routine": catalog.localize_routine_exercise_names(routine)}
    except asyncio.TimeoutError:
        logger.error("recommend timeout after %ss", _coach_timeout_sec())
        raise HTTPException(
            status_code=504,
            detail="루틴 생성이 시간 초과되었습니다. 잠시 후 다시 시도해 주세요.",
        ) from None
    except json.JSONDecodeError:
        logger.error("JSON 파싱 실패: %s", reply)
        raise HTTPException(status_code=500, detail="AI 응답 파싱에 실패했습니다.") from None
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("루틴 추천 생성 중 오류")
        raise HTTPException(status_code=500, detail=_public_error_message(e)) from e
