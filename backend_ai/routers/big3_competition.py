"""3대 운동 경쟁 API (opt-in, 제출, 리더보드)."""

from __future__ import annotations

import logging
from datetime import date
from typing import Any, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field

from routers.auth_deps import require_memory_subject
from services.big3_competition_service import (
    Big3CompetitionError,
    compute_total_1rm,
    fetch_current_season,
    fetch_leaderboard,
    fetch_season_by_id,
    fetch_user_bests,
    get_profile,
    opt_in,
    opt_out,
    profile_to_public_dict,
    season_to_dict,
    set_leaderboard_visibility,
    submission_to_dict,
    submit_lift,
    validate_submission_input,
)
from services.database import get_pool

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/competition", tags=["competition"])


def _require_pool(request: Request) -> Any:
    pool = get_pool(request.app)
    if pool is None:
        raise HTTPException(
            status_code=503,
            detail="Competition API requires DATABASE_URL (Postgres pool)",
        )
    return pool


class OptInBody(BaseModel):
    display_alias: str = ""


class SubmitLiftBody(BaseModel):
    lift_type: str
    weight_kg: float = Field(gt=0)
    reps: int = Field(ge=1, le=20)
    session_date: Optional[str] = None


class LeaderboardVisibilityBody(BaseModel):
    visible: bool


@router.get("/seasons/current")
async def get_current_season(
    request: Request,
    _: str = Depends(require_memory_subject),
) -> dict[str, Any]:
    pool = _require_pool(request)
    season = await fetch_current_season(pool)
    if season is None:
        return {"season": None}
    return {"season": season_to_dict(season)}


@router.get("/profile/me")
async def get_my_profile(
    request: Request,
    subject: str = Depends(require_memory_subject),
) -> dict[str, Any]:
    pool = _require_pool(request)
    profile = await get_profile(pool, subject)
    if profile is None:
        return {"profile": None}
    return {"profile": profile_to_public_dict(profile)}


@router.post("/opt-in")
async def post_opt_in(
    request: Request,
    body: OptInBody,
    subject: str = Depends(require_memory_subject),
) -> dict[str, Any]:
    pool = _require_pool(request)
    try:
        alias = body.display_alias.strip() or None
        profile = await opt_in(pool, subject, alias)
    except Big3CompetitionError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except Exception as e:
        if "unique" in str(e).lower() or "duplicate" in str(e).lower():
            raise HTTPException(status_code=409, detail="display_alias already taken") from e
        logger.exception("opt-in failed")
        raise HTTPException(status_code=500, detail="Failed to opt in") from e
    return {"profile": profile_to_public_dict(profile)}


@router.post("/opt-out")
async def post_opt_out(
    request: Request,
    subject: str = Depends(require_memory_subject),
) -> dict[str, Any]:
    pool = _require_pool(request)
    try:
        profile = await opt_out(pool, subject)
    except Exception as e:
        logger.exception("opt-out failed")
        raise HTTPException(status_code=500, detail="Failed to opt out") from e
    return {"profile": profile_to_public_dict(profile)}


@router.post("/leaderboard-visibility")
async def post_leaderboard_visibility(
    request: Request,
    body: LeaderboardVisibilityBody,
    subject: str = Depends(require_memory_subject),
) -> dict[str, Any]:
    pool = _require_pool(request)
    try:
        profile = await set_leaderboard_visibility(pool, subject, body.visible)
    except Big3CompetitionError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except Exception as e:
        logger.exception("leaderboard visibility update failed")
        raise HTTPException(status_code=500, detail="Failed to update visibility") from e
    return {"profile": profile_to_public_dict(profile)}


@router.post("/submit")
async def post_submit_lift(
    request: Request,
    body: SubmitLiftBody,
    subject: str = Depends(require_memory_subject),
) -> dict[str, Any]:
    pool = _require_pool(request)
    season = await fetch_current_season(pool)
    if season is None:
        raise HTTPException(status_code=404, detail="No active competition season")

    try:
        lift_type, weight_kg, reps, est = validate_submission_input(
            body.lift_type, body.weight_kg, body.reps
        )
        session_date = date.today()
        if body.session_date:
            session_date = date.fromisoformat(body.session_date)
        submission = await submit_lift(
            pool,
            subject=subject,
            season_id=season.id,
            lift_type=lift_type,
            weight_kg=weight_kg,
            reps=reps,
            estimated_1rm_kg=est,
            session_date=session_date,
        )
    except Big3CompetitionError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except Exception as e:
        logger.exception("submit failed")
        raise HTTPException(status_code=500, detail="Failed to submit lift") from e

    bests = await fetch_user_bests(pool, subject, season.id)
    return {
        "submission": submission_to_dict(submission),
        "season": season_to_dict(season),
        "bests": bests,
        "total_1rm_kg": compute_total_1rm(bests),
    }


@router.get("/me/stats")
async def get_my_stats(
    request: Request,
    season_id: Optional[str] = Query(default=None),
    subject: str = Depends(require_memory_subject),
) -> dict[str, Any]:
    pool = _require_pool(request)
    if season_id:
        try:
            sid = UUID(season_id)
        except ValueError as e:
            raise HTTPException(status_code=400, detail="invalid season_id") from e
        season = await fetch_season_by_id(pool, sid)
    else:
        season = await fetch_current_season(pool)

    if season is None:
        raise HTTPException(status_code=404, detail="Season not found")

    profile = await get_profile(pool, subject)
    bests = await fetch_user_bests(pool, subject, season.id)
    return {
        "season": season_to_dict(season),
        "profile": profile_to_public_dict(profile) if profile else None,
        "bests": bests,
        "total_1rm_kg": compute_total_1rm(bests),
    }


@router.get("/leaderboard")
async def get_leaderboard(
    request: Request,
    season_id: Optional[str] = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    _: str = Depends(require_memory_subject),
) -> dict[str, Any]:
    pool = _require_pool(request)
    if season_id:
        try:
            sid = UUID(season_id)
        except ValueError as e:
            raise HTTPException(status_code=400, detail="invalid season_id") from e
        season = await fetch_season_by_id(pool, sid)
    else:
        season = await fetch_current_season(pool)

    if season is None:
        raise HTTPException(status_code=404, detail="Season not found")

    entries = await fetch_leaderboard(pool, season.id, limit=limit, offset=offset)
    return {
        "season": season_to_dict(season),
        "entries": entries,
        "limit": limit,
        "offset": offset,
    }
