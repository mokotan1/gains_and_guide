"""유저 메모리 업로드·삭제 (Pinecone 네임스페이스)."""

from __future__ import annotations

import logging
from typing import Any, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from routers.auth_deps import require_memory_subject
from services.user_memory_service import (
    UserMemoryService,
    build_user_memory_service,
    memory_api_enabled,
    validate_chunks,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/memory", tags=["memory"])

_memory_service: UserMemoryService | None = None
_memory_service_loaded = False


def get_user_memory_service() -> Optional[UserMemoryService]:
    global _memory_service, _memory_service_loaded
    if not _memory_service_loaded:
        _memory_service = build_user_memory_service()
        _memory_service_loaded = True
    return _memory_service


class MemoryChunkItem(BaseModel):
    text: str
    source: str = ""
    topic: str = ""
    client_chunk_id: str = ""


class MemoryChunksBody(BaseModel):
    chunks: list[MemoryChunkItem] = Field(default_factory=list)


@router.post("/chunks")
async def post_memory_chunks(
    request: Request,
    payload: MemoryChunksBody,
    subject: str = Depends(require_memory_subject),
) -> dict[str, Any]:
    _ = request
    if not memory_api_enabled():
        raise HTTPException(status_code=503, detail="Memory API is disabled")
    svc = get_user_memory_service()
    if svc is None:
        raise HTTPException(
            status_code=503,
            detail="User memory storage is not configured (Pinecone + OpenAI required)",
        )
    try:
        validated = validate_chunks([c.model_dump() for c in payload.chunks])
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    try:
        n = svc.upsert_for_subject(subject, validated)
    except Exception as e:
        logger.exception("memory upsert failed")
        raise HTTPException(status_code=500, detail="Failed to store memory chunks") from e
    return {"stored": n, "subject": subject}


@router.delete("")
async def delete_user_memory(
    request: Request,
    subject: str = Depends(require_memory_subject),
) -> dict[str, str]:
    _ = request
    if not memory_api_enabled():
        raise HTTPException(status_code=503, detail="Memory API is disabled")
    svc = get_user_memory_service()
    if svc is None:
        raise HTTPException(
            status_code=503,
            detail="User memory storage is not configured (Pinecone + OpenAI required)",
        )
    try:
        svc.delete_all_for_subject(subject)
    except Exception as e:
        logger.exception("memory delete failed")
        raise HTTPException(status_code=500, detail="Failed to delete memory") from e
    return {"status": "ok", "subject": subject}
