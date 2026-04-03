"""코치 /chat·/recommend 엔드포인트."""

from __future__ import annotations

import asyncio
import json
import logging
import os
from collections.abc import Callable
from typing import Any, Optional

from fastapi import APIRouter, HTTPException, Request
from groq import APIError, APIStatusError
from pydantic import BaseModel, ValidationError

import catalog
import prompts
from graphs.coach_graph import COACH_SCHEMA_RETRY_USER_SUFFIX, run_coach_agent
from rate_limits import coach_rate_limit_string, limiter
from services.coach_response_schema import CoachChatResponse, coerce_raw_coach_dict
from routers.auth_deps import resolve_request_subject
from services.groq_settings import groq_max_completion_tokens
from services.llm_completion import chat_completion_create
from services.hybrid_retrieval import hybrid_rag_config_from_env, retrieve_corpus_and_user
from services.rag import format_references
from services.user_namespace import user_vector_namespace
from state import app_deps

logger = logging.getLogger(__name__)

router = APIRouter()

_COACH_RATE_LIMIT = coach_rate_limit_string()


class ChatRequest(BaseModel):
    user_id: str = ""
    message: str
    context: str = ""


class RecommendRequest(BaseModel):
    user_id: str = ""
    weekly_summary: str


def _corpus_namespace() -> str:
    return os.getenv("PINECONE_NAMESPACE", "corpus").strip() or "corpus"


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


# Groq 무료/on_demand: TPM·요청 과대(413) 시 단계적 축소 (0=기본, 1=컴팩트, 2=비상: RAG·가이드·카탈로그 생략)
_COMPACT_RAG_SNIPPET_CHARS = 200
_COMPACT_LONG_FIELD_MAX_CHARS = 2000
_EMERGENCY_CONTEXT_MAX_CHARS = 800
_EMERGENCY_MAX_COMPLETION_TOKENS = 384
# on_demand: 전체 카탈로그·컨텍스트가 입력 토큰을 쉽게 채움 — 티어별 문자 상한
_DEFAULT_CATALOG_CHARS_TIER0 = 7_500
_DEFAULT_CATALOG_CHARS_TIER1 = 3_500
_DEFAULT_COACH_CONTEXT_CHARS = 2_200
_DEFAULT_COACH_USER_MESSAGE_CHARS = 3_500
_DEFAULT_RAG_QUERY_CHARS = 2_500

_CHAT_EMERGENCY_JSON_SUFFIX = (
    "\n\n[출력]\n오직 JSON 한 객체: {\"response\": string, \"routine\": object|null, "
    "\"progression\": array|null}. "
    "progression 원소는 {\"name\": string, \"increase\": number}; 증량 제안이 없으면 null. "
    "routine이 있으면 exercises[].name은 가능한 한 영문 운동명을 사용한다.\n"
)


def _long_text_field_cap() -> int | None:
    """과거 기록·주간 요약 등 사용자 컨텍스트 최대 길이. 미설정 시 기본 상한(토큰 예산)."""
    raw = os.getenv("COACH_LONG_FIELD_MAX_CHARS", "").strip().lower()
    if raw in ("0", "none", "unlimited"):
        return None
    if not raw:
        return max(200, _DEFAULT_COACH_CONTEXT_CHARS)
    try:
        return max(200, int(raw))
    except ValueError:
        return max(200, _DEFAULT_COACH_CONTEXT_CHARS)


def _user_message_max_chars() -> int:
    raw = os.getenv("COACH_USER_MESSAGE_MAX_CHARS", "").strip()
    if not raw:
        return max(200, _DEFAULT_COACH_USER_MESSAGE_CHARS)
    try:
        return max(200, int(raw))
    except ValueError:
        return max(200, _DEFAULT_COACH_USER_MESSAGE_CHARS)


def _rag_query_max_chars() -> int:
    raw = os.getenv("COACH_RAG_QUERY_MAX_CHARS", "").strip()
    if not raw:
        return max(200, _DEFAULT_RAG_QUERY_CHARS)
    try:
        return max(200, int(raw))
    except ValueError:
        return max(200, _DEFAULT_RAG_QUERY_CHARS)


def _truncate_chat_request(body: ChatRequest) -> ChatRequest:
    cap = _user_message_max_chars()
    if len(body.message) <= cap:
        return body
    t = body.message[: max(1, cap - 24)].rstrip() + "\n...[truncated]"
    if hasattr(body, "model_copy"):
        return body.model_copy(update={"message": t})
    return body.copy(update={"message": t})  # type: ignore[no-any-return, union-attr]


def _truncate_rag_query(q: str) -> str:
    cap = _rag_query_max_chars()
    if len(q) <= cap:
        return q
    return q[: max(1, cap - 20)].rstrip() + "\n...[truncated]"


def _catalog_injection_max_chars(tier: int) -> int | None:
    """
    운동 카탈로그 블록 최대 문자 수. None 이면 잘라내지 않음.
    COACH_CATALOG_UNLIMITED=1 이면 항상 None.
    """
    if os.getenv("COACH_CATALOG_UNLIMITED", "").strip().lower() in (
        "1",
        "true",
        "yes",
    ):
        return None
    raw = os.getenv("COACH_CATALOG_MAX_CHARS", "").strip()
    if raw:
        try:
            v = int(raw)
            return None if v <= 0 else v
        except ValueError:
            pass
    if tier >= 1:
        return _DEFAULT_CATALOG_CHARS_TIER1
    return _DEFAULT_CATALOG_CHARS_TIER0


def _truncate_catalog_for_prompt(
    catalog_text: str, max_chars: int | None
) -> str:
    if not catalog_text or not catalog_text.strip():
        return catalog_text
    if max_chars is None or len(catalog_text) <= max_chars:
        return catalog_text
    return (
        catalog_text[: max(1, max_chars - 48)].rstrip()
        + "\n...[catalog truncated for token budget]"
    )


def _truncate_coach_long_field(
    text: str, *, override_cap: int | None = None
) -> str:
    cap = override_cap if override_cap is not None else _long_text_field_cap()
    if cap is None or len(text) <= cap:
        return text
    return text[: max(1, cap - 22)].rstrip() + "\n...[truncated]"


def _groq_body_rate_limit_exceeded(body: object) -> bool:
    if not isinstance(body, dict):
        return False
    err = body.get("error")
    return isinstance(err, dict) and err.get("code") == "rate_limit_exceeded"


def _is_groq_tpm_rate_limit(exc: BaseException) -> bool:
    if isinstance(exc, APIStatusError):
        if exc.status_code == 429:
            return True
        if exc.status_code == 413:
            if _groq_body_rate_limit_exceeded(getattr(exc, "body", None)):
                return True
            low = str(exc).lower()
            if "rate_limit" in low or "tokens per minute" in low:
                return True
    if isinstance(exc, APIError) and _groq_body_rate_limit_exceeded(
        getattr(exc, "body", None)
    ):
        return True
    msg = str(exc).lower()
    if "rate_limit_exceeded" in msg or "tokens per minute" in msg:
        return True
    cause = getattr(exc, "__cause__", None)
    if cause is not None and cause is not exc:
        return _is_groq_tpm_rate_limit(cause)
    return False


def _groq_error_text(exc: BaseException) -> str:
    parts: list[str] = [str(exc)]
    b = getattr(exc, "body", None)
    if isinstance(b, dict):
        try:
            parts.append(json.dumps(b, ensure_ascii=False))
        except (TypeError, ValueError):
            parts.append(repr(b))
    elif isinstance(b, str):
        parts.append(b)
    return " ".join(parts).lower()


def _is_groq_request_too_large(exc: BaseException) -> bool:
    """
    요청 본문/컨텍스트가 커서 실패한 경우(순수 413, context length 등).
    Groq는 TPM 한도를 413+rate_limit으로 주기도 하고, 페이로드 과대만으로 413이 나기도 한다.
    """
    if isinstance(exc, APIStatusError):
        if exc.status_code == 413 and not _groq_body_rate_limit_exceeded(
            getattr(exc, "body", None)
        ):
            return True
        if exc.status_code == 400:
            blob = _groq_error_text(exc)
            if "context_length" in blob or "context length" in blob:
                return True
            if "token" in blob and (
                "too many" in blob
                or "maximum" in blob
                or "exceed" in blob
                or "reduce" in blob
            ):
                return True
            if "request too large" in blob or "payload too large" in blob:
                return True
    cause = getattr(exc, "__cause__", None)
    if cause is not None and cause is not exc:
        return _is_groq_request_too_large(cause)
    return False


def _should_shrink_prompt_and_retry(exc: BaseException) -> bool:
    return _is_groq_tpm_rate_limit(exc) or _is_groq_request_too_large(exc)


def _emergency_completion_cap() -> int:
    return max(256, min(_EMERGENCY_MAX_COMPLETION_TOKENS, groq_max_completion_tokens()))


def _invoke_legacy_chat_resolving_tpm(
    client: Any,
    get_prompts: Callable[[int], tuple[str, str]],
) -> dict[str, Any]:
    emergency_cap = _emergency_completion_cap()
    last_err: BaseException | None = None
    for tier in (0, 1, 2):
        sp, uc = get_prompts(tier)
        mt = emergency_cap if tier == 2 else None
        try:
            return _legacy_chat_completion(client, sp, uc, max_completion_tokens=mt)
        except Exception as e:
            last_err = e
            if not _should_shrink_prompt_and_retry(e):
                raise
            if tier == 2:
                logger.error("Groq TPM persists after tier-2 minimal prompt")
                raise HTTPException(
                    status_code=429,
                    detail=(
                        "AI 분당 토큰 한도를 초과했습니다. 잠시 후 다시 시도하거나 "
                        "짧은 메시지로 요청해 주세요."
                    ),
                ) from e
            logger.warning(
                "Groq prompt limit — legacy retry tier %s (TPM or oversized request)",
                tier + 1,
            )
    raise RuntimeError("legacy TPM loop exhausted") from last_err


def _chat_prompt_tier(
    body: ChatRequest, user_subject: str, tier: int
) -> tuple[str, str]:
    if tier == 0:
        system_prompt = _build_chat_system_base(
            body.message,
            user_subject,
            rag_snippet_max=None,
            skip_rag=False,
            include_routine_guide=True,
            include_catalog=True,
            catalog_max_chars=_catalog_injection_max_chars(0),
            chat_context=body.context,
        )
        field_cap = _long_text_field_cap()
    elif tier == 1:
        system_prompt = _build_chat_system_base(
            body.message,
            user_subject,
            rag_snippet_max=_COMPACT_RAG_SNIPPET_CHARS,
            skip_rag=False,
            include_routine_guide=True,
            include_catalog=True,
            catalog_max_chars=_catalog_injection_max_chars(1),
            chat_context=body.context,
        )
        field_cap = _COMPACT_LONG_FIELD_MAX_CHARS
    else:
        system_prompt = _build_chat_system_base(
            body.message,
            user_subject,
            rag_snippet_max=None,
            skip_rag=True,
            include_routine_guide=False,
            include_catalog=False,
            catalog_max_chars=None,
            chat_context=body.context,
        )
        system_prompt += _CHAT_EMERGENCY_JSON_SUFFIX
        field_cap = _EMERGENCY_CONTEXT_MAX_CHARS

    user_content = _chat_user_content(
        body.context, body.message, field_cap=field_cap
    )
    return system_prompt, user_content


def _chat_user_content(
    context: str, message: str, *, field_cap: int | None = None
) -> str:
    ctx = _truncate_coach_long_field(context, override_cap=field_cap)
    return f"[과거 운동 기록]\n{ctx}\n\n[질문]\n{message}"


def _rag_reference_appendix(
    query: str,
    user_subject: str,
    *,
    rag_snippet_max: int | None = None,
) -> str:
    """Pinecone·임베딩 오류 시 전체 /chat 이 500이 되지 않도록 참조 블록만 생략한다."""
    if not app_deps.rag:
        return ""
    try:
        q = _truncate_rag_query(query)
        cfg = hybrid_rag_config_from_env()
        user_ns = user_vector_namespace(user_subject)
        corp_ns = _corpus_namespace()
        corpus_chunks, user_chunks = retrieve_corpus_and_user(
            app_deps.rag,
            q,
            user_namespace=user_ns,
            cfg=cfg,
            corpus_namespace=corp_ns,
        )
        parts: list[str] = []
        if corpus_chunks:
            parts.append(
                "\n\n[References — 코퍼스 RAG]\n"
                + format_references(corpus_chunks, max_snippet_chars=rag_snippet_max)
            )
        if user_chunks:
            parts.append(
                "\n\n[References — 내 메모리]\n"
                + format_references(user_chunks, max_snippet_chars=rag_snippet_max)
            )
        return "".join(parts)
    except Exception:
        logger.exception(
            "RAG retrieve failed (query_len=%s); continuing without references",
            len(query),
        )
        return ""


def _build_chat_system_base(
    user_message: str,
    user_subject: str,
    *,
    rag_snippet_max: int | None = None,
    skip_rag: bool = False,
    include_routine_guide: bool = True,
    include_catalog: bool = True,
    catalog_max_chars: int | None = None,
    chat_context: str = "",
) -> str:
    if not app_deps.assets:
        raise HTTPException(status_code=500, detail="프롬프트 자산이 로드되지 않았습니다.")
    s = app_deps.assets.system_prompt
    if include_routine_guide:
        s = prompts.append_routine_guide(s, app_deps.assets.routine_guide_text)
    if include_catalog:
        cat = _truncate_catalog_for_prompt(
            catalog.exercise_catalog_text, catalog_max_chars
        )
        s = prompts.append_catalog(s, cat)
    if not skip_rag:
        s += _rag_reference_appendix(
            user_message, user_subject, rag_snippet_max=rag_snippet_max
        )
    s = _append_cardio_analysis_guide(s, chat_context)
    return s


def _append_cardio_analysis_guide(system_prompt: str, chat_context: str) -> str:
    """주간 레포트 등 컨텍스트에 유산소 블록이 있으면 유산소 전용 지침을 시스템에 병합한다."""
    if "[유산소 운동 데이터]" not in chat_context:
        return system_prompt
    if not app_deps.assets:
        return system_prompt
    cap = (app_deps.assets.cardio_analysis_prompt or "").strip()
    if not cap:
        return system_prompt
    return system_prompt + "\n\n[CARDIO_ANALYSIS_GUIDE]\n" + cap


def _build_recommend_system_base(
    weekly_summary: str,
    user_subject: str,
    *,
    rag_snippet_max: int | None = None,
    skip_rag: bool = False,
    include_routine_guide: bool = True,
    include_catalog: bool = True,
    catalog_max_chars: int | None = None,
) -> str:
    if not app_deps.assets:
        raise HTTPException(status_code=500, detail="프롬프트 자산이 로드되지 않았습니다.")
    s = app_deps.assets.routine_system_prompt
    if include_routine_guide:
        s = prompts.append_routine_guide(s, app_deps.assets.routine_guide_text)
    if include_catalog:
        cat = _truncate_catalog_for_prompt(
            catalog.exercise_catalog_text, catalog_max_chars
        )
        s = prompts.append_catalog(s, cat)
    if not skip_rag:
        s += _rag_reference_appendix(
            weekly_summary, user_subject, rag_snippet_max=rag_snippet_max
        )
    return s


def _legacy_chat_completion(
    client: Any,
    system_prompt: str,
    user_content: str,
    *,
    max_completion_tokens: int | None = None,
) -> dict[str, Any]:
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_content},
    ]
    chat_completion = chat_completion_create(
        client,
        messages,
        provider=app_deps.llm_chat_provider,
        max_completion_tokens=max_completion_tokens,
    )
    reply = chat_completion.choices[0].message.content
    if not reply:
        return {"response": "빈 응답", "routine": None, "progression": None}
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
            "progression": parsed_reply.get("progression"),
        }
    except json.JSONDecodeError:
        return {"response": reply, "routine": None, "progression": None}


def _coerce_chat_response(raw: dict[str, Any]) -> CoachChatResponse:
    return coerce_raw_coach_dict(raw)


def _progression_for_json(v: CoachChatResponse) -> list[dict[str, Any]] | None:
    if v.progression is None:
        return None
    return [item.model_dump() for item in v.progression]


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


def _recommend_messages(
    body: RecommendRequest, user_subject: str, tier: int
) -> list[dict[str, str]]:
    if tier == 0:
        field_cap = _long_text_field_cap()
        rag_max = None
        skip_rag = False
        irg, icat = True, True
    elif tier == 1:
        field_cap = _COMPACT_LONG_FIELD_MAX_CHARS
        rag_max = _COMPACT_RAG_SNIPPET_CHARS
        skip_rag = False
        irg, icat = True, True
    else:
        field_cap = _EMERGENCY_CONTEXT_MAX_CHARS
        rag_max = None
        skip_rag = True
        irg, icat = False, False

    summary = _truncate_coach_long_field(
        body.weekly_summary, override_cap=field_cap
    )
    cat_limit = _catalog_injection_max_chars(tier) if icat else None
    system_prompt = _build_recommend_system_base(
        summary,
        user_subject,
        rag_snippet_max=rag_max,
        skip_rag=skip_rag,
        include_routine_guide=irg,
        include_catalog=icat,
        catalog_max_chars=cat_limit,
    )
    if tier == 2:
        system_prompt += (
            "\n\n[출력]\n다음 주 추천 루틴을 JSON 한 객체로 생성한다. "
            '루트 키 "routine": { title, rationale, exercises 등 }.\n'
        )
    user_blob = (
        f"[주간 운동 분석 데이터]\n{summary}\n\n"
        "[지시]\n위 분석 데이터를 바탕으로 다음 주 추천 루틴을 JSON으로 생성해주세요."
    )
    return [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_blob},
    ]


@router.post("/chat")
@limiter.limit(_COACH_RATE_LIMIT)
async def chat_with_coach(request: Request, body: ChatRequest) -> dict[str, Any]:
    body = _truncate_chat_request(body)
    user_subject = resolve_request_subject(request, body.user_id)
    if not app_deps.chat_completion_client:
        raise HTTPException(
            status_code=500,
            detail="LLM 이 설정되지 않았습니다. GROQ_API_KEY 또는 OPENAI_COMPAT_BASE_URL 을 확인하세요.",
        )

    if _use_legacy_chat() or not app_deps.coach_agent:
        try:
            raw = _invoke_legacy_chat_resolving_tpm(
                app_deps.chat_completion_client,
                lambda t: _chat_prompt_tier(body, user_subject, t),
            )
            try:
                v = _coerce_chat_response(raw)
            except ValidationError:
                v = CoachChatResponse(
                    response=str(raw.get("response", "응답을 처리하지 못했습니다.")),
                    routine=None,
                    progression=None,
                )
            return {
                "response": v.response,
                "routine": catalog.localize_routine_exercise_names(v.routine),
                "progression": _progression_for_json(v),
            }
        except HTTPException:
            raise
        except Exception as e:
            logger.exception("legacy chat failed")
            raise HTTPException(
                status_code=500, detail=_public_error_message(e)
            ) from e

    sp, uc = _chat_prompt_tier(body, user_subject, 0)
    try:
        try:
            parsed = await _run_agent_with_timeout(sp, uc)
        except Exception as e:
            if _should_shrink_prompt_and_retry(e):
                logger.warning("coach agent: prompt/TPM limit — tier 1")
                sp, uc = _chat_prompt_tier(body, user_subject, 1)
                try:
                    parsed = await _run_agent_with_timeout(sp, uc)
                except Exception as e2:
                    if _should_shrink_prompt_and_retry(e2):
                        logger.warning("coach agent: prompt/TPM limit — tier 2 minimal")
                        sp, uc = _chat_prompt_tier(body, user_subject, 2)
                        parsed = await _run_agent_with_timeout(sp, uc)
                    else:
                        raise e2
            else:
                raise

        try:
            v = _coerce_chat_response(parsed)
        except ValidationError:
            logger.warning("agent output failed schema; retry once")
            parsed2 = await _run_agent_with_timeout(
                sp,
                uc,
                user_suffix=COACH_SCHEMA_RETRY_USER_SUFFIX,
            )
            try:
                v = _coerce_chat_response(parsed2)
            except ValidationError:
                logger.warning("agent retry failed schema; falling back to legacy JSON")
                raw = _invoke_legacy_chat_resolving_tpm(
                    app_deps.chat_completion_client,
                    lambda t: _chat_prompt_tier(body, user_subject, t),
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
                        progression=None,
                    )
        return {
            "response": v.response,
            "routine": catalog.localize_routine_exercise_names(v.routine),
            "progression": _progression_for_json(v),
        }
    except asyncio.TimeoutError:
        logger.error("coach agent timeout after %ss", _coach_timeout_sec())
        raise HTTPException(
            status_code=504,
            detail="응답 생성이 시간 초과되었습니다. 짧은 질문으로 다시 시도해 주세요.",
        ) from None
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("agent chat failed, falling back to legacy JSON chat")
        try:
            raw = _invoke_legacy_chat_resolving_tpm(
                app_deps.chat_completion_client,
                lambda t: _chat_prompt_tier(body, user_subject, t),
            )
            try:
                v = _coerce_chat_response(raw)
            except ValidationError:
                v = CoachChatResponse(
                    response=str(raw.get("response", "응답을 처리하지 못했습니다.")),
                    routine=None,
                    progression=None,
                )
            return {
                "response": v.response,
                "routine": catalog.localize_routine_exercise_names(v.routine),
                "progression": _progression_for_json(v),
            }
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(
                status_code=500, detail=_public_error_message(e)
            ) from e


@router.post("/recommend")
@limiter.limit(_COACH_RATE_LIMIT)
async def recommend_routine(request: Request, body: RecommendRequest) -> dict[str, Any]:
    user_subject = resolve_request_subject(request, body.user_id)
    if not app_deps.chat_completion_client:
        raise HTTPException(
            status_code=500,
            detail="LLM 이 설정되지 않았습니다. GROQ_API_KEY 또는 OPENAI_COMPAT_BASE_URL 을 확인하세요.",
        )

    emergency_cap = _emergency_completion_cap()
    chat_completion: Any = None
    reply: Optional[str] = None
    try:
        for tier in (0, 1, 2):
            messages = _recommend_messages(body, user_subject, tier)
            mt = emergency_cap if tier == 2 else None

            def _llm_call(
                m: list[dict[str, str]] = messages, tok: int | None = mt
            ) -> Any:
                return chat_completion_create(
                    app_deps.chat_completion_client,
                    m,
                    provider=app_deps.llm_chat_provider,
                    max_completion_tokens=tok,
                )

            try:
                chat_completion = await asyncio.wait_for(
                    asyncio.to_thread(_llm_call),
                    timeout=_coach_timeout_sec(),
                )
                break
            except Exception as e:
                if not _should_shrink_prompt_and_retry(e):
                    raise
                if tier == 2:
                    logger.error("recommend: Groq limit after tier-2 minimal prompt")
                    raise HTTPException(
                        status_code=429,
                        detail=(
                            "AI 분당 토큰 한도를 초과했습니다. 잠시 후 다시 시도하거나 "
                            "요약 길이를 줄여 주세요."
                        ),
                    ) from e
                logger.warning(
                    "recommend: Groq prompt/TPM — retry tier %s", tier + 1
                )

        if chat_completion is None:
            raise HTTPException(
                status_code=500, detail="AI 호출에 실패했습니다."
            ) from None

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
