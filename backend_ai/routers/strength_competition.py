"""3대 운동 Strength competition API (/strength/*)."""

from __future__ import annotations

import logging
from datetime import date
from typing import Any, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status

from routers.auth_deps import require_memory_subject
from services.big3_competition_service import (
    ProfileUpdate,
    StrengthCompetitionError,
    bests_to_records,
    fetch_current_season,
    fetch_leaderboard,
    fetch_my_rank,
    fetch_recent_entries,
    fetch_user_bests,
    get_profile,
    count_leaderboard_eligible,
    resolve_season,
    profile_to_public_dict,
    submission_to_dict,
    submit_lift,
    upsert_profile,
    validate_submission_input,
)
from services.database import get_pool
from services.strength_competition_schema import (
    CurrentSeasonResponse,
    LeaderboardEntryOut,
    LeaderboardResponse,
    LiftEntryOut,
    MyRankResponse,
    ProfileOut,
    ProfileResponse,
    ProfileUpdateIn,
    RecordsMeResponse,
    RecordsOut,
    SeasonOut,
    SubmitLiftIn,
    SubmitLiftResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/strength", tags=["strength"])


def _require_pool(request: Request) -> Any:
    pool = get_pool(request.app)
    if pool is None:
        raise HTTPException(
            status_code=503,
            detail="Strength API requires DATABASE_URL (Postgres pool)",
        )
    return pool


def _parse_season_id(season_id: Optional[str]) -> Optional[UUID]:
    if not season_id:
        return None
    try:
        return UUID(season_id)
    except ValueError as e:
        raise HTTPException(status_code=400, detail="invalid season_id") from e


def _season_out(season_row: Any) -> SeasonOut:
    return SeasonOut(
        id=str(season_row.id),
        slug=season_row.slug,
        name=season_row.name,
        starts_at=season_row.starts_at,
        ends_at=season_row.ends_at,
        is_active=season_row.is_active,
    )


def _profile_out(profile: Any) -> ProfileOut:
    d = profile_to_public_dict(profile)
    return ProfileOut(**d)


def _entry_out(entry: Any) -> LiftEntryOut:
    d = submission_to_dict(entry)
    return LiftEntryOut(**d)


def _records_out(bests: dict[str, Optional[float]]) -> RecordsOut:
    r = bests_to_records(bests)
    return RecordsOut(**r)


def _duplicate_alias_error(exc: Exception) -> bool:
    msg = str(exc).lower()
    return "unique" in msg or "duplicate" in msg


@router.get("/seasons/current", response_model=CurrentSeasonResponse)
async def get_current_season(
    request: Request,
    _: str = Depends(require_memory_subject),
) -> CurrentSeasonResponse:
    pool = _require_pool(request)
    season = await fetch_current_season(pool)
    if season is None:
        return CurrentSeasonResponse(season=None)
    return CurrentSeasonResponse(season=_season_out(season))


@router.get("/profile/me", response_model=ProfileResponse)
async def get_my_profile(
    request: Request,
    subject: str = Depends(require_memory_subject),
) -> ProfileResponse:
    pool = _require_pool(request)
    profile = await get_profile(pool, subject)
    if profile is None:
        return ProfileResponse(profile=None)
    return ProfileResponse(profile=_profile_out(profile))


@router.put("/profile/me", response_model=ProfileResponse)
async def put_my_profile(
    request: Request,
    body: ProfileUpdateIn,
    subject: str = Depends(require_memory_subject),
) -> ProfileResponse:
    pool = _require_pool(request)
    try:
        update = ProfileUpdate(
            display_alias=body.display_alias,
            competition_opted_in=body.competition_opted_in,
            leaderboard_opt_in=body.leaderboard_opt_in,
            body_weight_kg=body.body_weight_kg,
        )
        profile = await upsert_profile(pool, subject, update)
    except StrengthCompetitionError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except Exception as e:
        if _duplicate_alias_error(e):
            raise HTTPException(status_code=409, detail="display_alias already taken") from e
        logger.exception("profile upsert failed")
        raise HTTPException(status_code=500, detail="Failed to update profile") from e
    return ProfileResponse(profile=_profile_out(profile))


@router.post("/lifts", response_model=SubmitLiftResponse, status_code=status.HTTP_201_CREATED)
async def post_lift(
    request: Request,
    body: SubmitLiftIn,
    subject: str = Depends(require_memory_subject),
) -> SubmitLiftResponse:
    pool = _require_pool(request)
    season = await fetch_current_season(pool)
    if season is None:
        raise HTTPException(status_code=404, detail="No active strength season")

    try:
        lift_type, weight_kg, reps, est = validate_submission_input(
            body.lift_type.value, body.weight_kg, body.reps
        )
        session_date = body.session_date or date.today()
        entry = await submit_lift(
            pool,
            subject=subject,
            season_id=season.id,
            lift_type=lift_type,
            weight_kg=weight_kg,
            reps=reps,
            estimated_1rm_kg=est,
            session_date=session_date,
        )
    except StrengthCompetitionError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except Exception as e:
        logger.exception("lift submit failed")
        raise HTTPException(status_code=500, detail="Failed to submit lift") from e

    bests = await fetch_user_bests(pool, subject, season.id)
    return SubmitLiftResponse(
        entry=_entry_out(entry),
        season=_season_out(season),
        records=_records_out(bests),
    )


@router.get("/records/me", response_model=RecordsMeResponse)
async def get_my_records(
    request: Request,
    season_id: Optional[str] = Query(default=None),
    recent_limit: int = Query(default=0, ge=0, le=20),
    subject: str = Depends(require_memory_subject),
) -> RecordsMeResponse:
    pool = _require_pool(request)
    sid = _parse_season_id(season_id)
    season = await resolve_season(pool, sid)
    if season is None:
        raise HTTPException(status_code=404, detail="Season not found")

    profile = await get_profile(pool, subject)
    bests = await fetch_user_bests(pool, subject, season.id)
    recent = await fetch_recent_entries(pool, subject, season.id, recent_limit)

    return RecordsMeResponse(
        season=_season_out(season),
        profile=_profile_out(profile) if profile else None,
        records=_records_out(bests),
        recent_entries=[_entry_out(e) for e in recent],
    )


@router.get("/leaderboard", response_model=LeaderboardResponse)
async def get_leaderboard(
    request: Request,
    season_id: Optional[str] = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    _: str = Depends(require_memory_subject),
) -> LeaderboardResponse:
    pool = _require_pool(request)
    sid = _parse_season_id(season_id)
    season = await resolve_season(pool, sid)
    if season is None:
        raise HTTPException(status_code=404, detail="Season not found")

    entries = await fetch_leaderboard(pool, season.id, limit=limit, offset=offset)
    total = await count_leaderboard_eligible(pool, season.id)
    return LeaderboardResponse(
        season=_season_out(season),
        entries=[LeaderboardEntryOut(**e) for e in entries],
        limit=limit,
        offset=offset,
        total_eligible=total,
    )


@router.get("/rank/me", response_model=MyRankResponse)
async def get_my_rank(
    request: Request,
    season_id: Optional[str] = Query(default=None),
    subject: str = Depends(require_memory_subject),
) -> MyRankResponse:
    pool = _require_pool(request)
    sid = _parse_season_id(season_id)
    season = await resolve_season(pool, sid)
    if season is None:
        raise HTTPException(status_code=404, detail="Season not found")

    bests = await fetch_user_bests(pool, subject, season.id)
    rank_result = await fetch_my_rank(pool, subject, season.id)

    return MyRankResponse(
        season=_season_out(season),
        ranked=rank_result.ranked,
        rank=rank_result.rank,
        display_alias=rank_result.display_alias,
        reason=rank_result.reason,
        records=_records_out(bests),
        total_participants=rank_result.total_participants,
    )
