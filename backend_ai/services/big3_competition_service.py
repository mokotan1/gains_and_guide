"""3대 운동(Strength) 경쟁: 제출·집계·리더보드 — strength_* 스키마."""

from __future__ import annotations

import hashlib
import logging
import re
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from typing import Any, Literal, Optional
from uuid import UUID

from services.constants import EPLEY_DIVISOR

logger = logging.getLogger(__name__)

LiftType = Literal["squat", "bench", "deadlift"]
LiftSource = Literal["manual", "workout_log"]
VerificationStatus = Literal[
    "self_reported", "from_workout_log", "verified", "rejected"
]

LIFT_TYPES: tuple[LiftType, ...] = ("squat", "bench", "deadlift")

MAX_WEIGHT_KG: dict[LiftType, float] = {
    "squat": 400.0,
    "bench": 300.0,
    "deadlift": 400.0,
}
MAX_REPS_FOR_SCORE = 12
MAX_DAILY_SUBMISSIONS_PER_LIFT = 3
MAX_WEEKLY_IMPROVEMENT_RATIO = 1.10
MIN_ALIAS_LEN = 2
MAX_ALIAS_LEN = 24
_ALIAS_PATTERN = re.compile(r"^[가-힣A-Za-z0-9_-]+$")

COUNTABLE_VERIFICATION: tuple[str, ...] = ("self_reported", "verified")


def epley_one_rm_kg(weight_kg: float, reps: int) -> float:
    if weight_kg <= 0:
        raise ValueError("weight_kg must be positive")
    if reps < 1:
        raise ValueError("reps must be at least 1")
    return float(weight_kg) * (1.0 + float(reps) / EPLEY_DIVISOR)


@dataclass(frozen=True)
class StrengthSeasonRow:
    id: UUID
    slug: str
    name: str
    starts_at: datetime
    ends_at: datetime
    is_active: bool


@dataclass(frozen=True)
class ProfileUpdate:
    display_alias: Optional[str] = None
    competition_opted_in: Optional[bool] = None
    leaderboard_opt_in: Optional[bool] = None
    body_weight_kg: Optional[float] = None
    clear_body_weight: bool = False


@dataclass(frozen=True)
class MyRankResult:
    ranked: bool
    rank: Optional[int]
    display_alias: Optional[str]
    reason: Optional[str]
    total_participants: int


@dataclass(frozen=True)
class StrengthProfileRow:
    subject: str
    display_alias: str
    competition_opted_in: bool
    leaderboard_opt_in: bool
    opted_in_at: Optional[datetime]
    body_weight_kg: Optional[float] = None


@dataclass(frozen=True)
class StrengthLiftEntryRow:
    id: UUID
    lift_type: LiftType
    weight_kg: float
    reps: int
    estimated_1rm_kg: float
    source: str
    verification_status: str
    session_date: date
    submitted_at: datetime


class StrengthCompetitionError(ValueError):
    """도메인 검증 실패 (400)."""


Big3CompetitionError = StrengthCompetitionError


def default_display_alias(subject: str) -> str:
    digest = hashlib.sha256(f"gains-big3:{subject}".encode()).hexdigest()
    return f"리프터-{digest[:4].upper()}"


def normalize_display_alias(raw: str) -> str:
    alias = raw.strip()
    if not (MIN_ALIAS_LEN <= len(alias) <= MAX_ALIAS_LEN):
        raise StrengthCompetitionError(
            f"display_alias must be {MIN_ALIAS_LEN}..{MAX_ALIAS_LEN} characters"
        )
    if not _ALIAS_PATTERN.match(alias):
        raise StrengthCompetitionError(
            "display_alias may only contain Korean, letters, digits, _ or -"
        )
    return alias


def validate_submission_input(
    lift_type: str,
    weight_kg: float,
    reps: int,
) -> tuple[LiftType, float, int, float]:
    if lift_type not in LIFT_TYPES:
        raise StrengthCompetitionError(f"lift_type must be one of {LIFT_TYPES}")
    typed_lift: LiftType = lift_type  # type: ignore[assignment]

    if weight_kg <= 0:
        raise StrengthCompetitionError("weight_kg must be positive")
    cap = MAX_WEIGHT_KG[typed_lift]
    if weight_kg > cap:
        raise StrengthCompetitionError(f"weight_kg exceeds plausible cap ({cap} kg)")

    if reps < 1 or reps > 20:
        raise StrengthCompetitionError("reps must be between 1 and 20")
    if reps > MAX_REPS_FOR_SCORE:
        raise StrengthCompetitionError(
            f"reps above {MAX_REPS_FOR_SCORE} are not accepted for competition scoring"
        )

    est = round(epley_one_rm_kg(weight_kg, reps), 2)
    return typed_lift, float(weight_kg), int(reps), est


def _utc_now() -> datetime:
    return datetime.now(timezone.utc)


async def ensure_user_profile(pool: Any, subject: str) -> None:
    """strength_profiles.subject FK 선행 조건."""
    await pool.execute(
        """
        insert into public.user_profiles (subject, updated_at)
        values ($1, now())
        on conflict (subject) do update set updated_at = excluded.updated_at
        """,
        subject,
    )


async def fetch_current_season(pool: Any) -> Optional[StrengthSeasonRow]:
    row = await pool.fetchrow(
        """
        select id, slug, name, starts_at, ends_at, is_active
        from public.strength_seasons
        where is_active = true
          and starts_at <= now()
          and ends_at >= now()
        order by starts_at desc
        limit 1
        """
    )
    if row is None:
        return None
    return _season_from_row(row)


async def fetch_season_by_id(pool: Any, season_id: UUID) -> Optional[StrengthSeasonRow]:
    row = await pool.fetchrow(
        """
        select id, slug, name, starts_at, ends_at, is_active
        from public.strength_seasons
        where id = $1
        """,
        season_id,
    )
    if row is None:
        return None
    return _season_from_row(row)


def _season_from_row(row: Any) -> StrengthSeasonRow:
    return StrengthSeasonRow(
        id=row["id"],
        slug=row["slug"],
        name=row["name"],
        starts_at=row["starts_at"],
        ends_at=row["ends_at"],
        is_active=row["is_active"],
    )


async def resolve_season(
    pool: Any,
    season_id: Optional[UUID],
) -> Optional[StrengthSeasonRow]:
    if season_id is not None:
        return await fetch_season_by_id(pool, season_id)
    return await fetch_current_season(pool)


async def get_profile(pool: Any, subject: str) -> Optional[StrengthProfileRow]:
    row = await pool.fetchrow(
        """
        select subject, display_alias, competition_opted_in,
               leaderboard_opt_in, opted_in_at, body_weight_kg
        from public.strength_profiles
        where subject = $1
        """,
        subject,
    )
    if row is None:
        return None
    return _profile_from_row(row)


def _profile_from_row(row: Any) -> StrengthProfileRow:
    bw = row["body_weight_kg"]
    return StrengthProfileRow(
        subject=row["subject"],
        display_alias=row["display_alias"],
        competition_opted_in=row["competition_opted_in"],
        leaderboard_opt_in=row["leaderboard_opt_in"],
        opted_in_at=row["opted_in_at"],
        body_weight_kg=float(bw) if bw is not None else None,
    )


async def upsert_profile(
    pool: Any,
    subject: str,
    update: ProfileUpdate,
) -> StrengthProfileRow:
    await ensure_user_profile(pool, subject)
    existing = await get_profile(pool, subject)
    now = _utc_now()

    alias = existing.display_alias if existing else default_display_alias(subject)
    if update.display_alias is not None:
        raw = update.display_alias.strip()
        alias = normalize_display_alias(raw) if raw else default_display_alias(subject)

    opted_in = (
        update.competition_opted_in
        if update.competition_opted_in is not None
        else (existing.competition_opted_in if existing else False)
    )
    leaderboard = (
        update.leaderboard_opt_in
        if update.leaderboard_opt_in is not None
        else (existing.leaderboard_opt_in if existing else True)
    )

    if update.leaderboard_opt_in is not None and not opted_in:
        raise StrengthCompetitionError(
            "leaderboard visibility requires competition opt-in"
        )

    opted_in_at: Optional[datetime] = existing.opted_in_at if existing else None
    if opted_in and opted_in_at is None:
        opted_in_at = now
    if not opted_in:
        opted_in_at = None
        leaderboard = False

    body_weight: Optional[float]
    if update.clear_body_weight:
        body_weight = None
    elif update.body_weight_kg is not None:
        if not (30 <= update.body_weight_kg <= 250):
            raise StrengthCompetitionError("body_weight_kg must be between 30 and 250")
        body_weight = float(update.body_weight_kg)
    else:
        body_weight = existing.body_weight_kg if existing else None

    row = await pool.fetchrow(
        """
        insert into public.strength_profiles (
            subject, display_alias, competition_opted_in,
            leaderboard_opt_in, opted_in_at, body_weight_kg, updated_at
        )
        values ($1, $2, $3, $4, $5, $6, $7)
        on conflict (subject) do update set
            display_alias = excluded.display_alias,
            competition_opted_in = excluded.competition_opted_in,
            leaderboard_opt_in = excluded.leaderboard_opt_in,
            opted_in_at = excluded.opted_in_at,
            body_weight_kg = excluded.body_weight_kg,
            updated_at = excluded.updated_at
        returning subject, display_alias, competition_opted_in,
                  leaderboard_opt_in, opted_in_at, body_weight_kg
        """,
        subject,
        alias,
        opted_in,
        leaderboard,
        opted_in_at,
        body_weight,
        now,
    )
    return _profile_from_row(row)


async def opt_in(
    pool: Any,
    subject: str,
    display_alias: Optional[str] = None,
) -> StrengthProfileRow:
    await ensure_user_profile(pool, subject)
    alias = normalize_display_alias(display_alias or default_display_alias(subject))
    now = _utc_now()
    row = await pool.fetchrow(
        """
        insert into public.strength_profiles (
            subject, display_alias, competition_opted_in,
            leaderboard_opt_in, opted_in_at, updated_at
        )
        values ($1, $2, true, true, $3, $3)
        on conflict (subject) do update set
            display_alias = excluded.display_alias,
            competition_opted_in = true,
            leaderboard_opt_in = true,
            opted_in_at = coalesce(strength_profiles.opted_in_at, excluded.opted_in_at),
            updated_at = excluded.updated_at
        returning subject, display_alias, competition_opted_in,
                  leaderboard_opt_in, opted_in_at, body_weight_kg
        """,
        subject,
        alias,
        now,
    )
    return _profile_from_row(row)


async def opt_out(pool: Any, subject: str) -> StrengthProfileRow:
    await ensure_user_profile(pool, subject)
    now = _utc_now()
    row = await pool.fetchrow(
        """
        insert into public.strength_profiles (
            subject, display_alias, competition_opted_in,
            leaderboard_opt_in, updated_at
        )
        values ($1, $2, false, false, $3)
        on conflict (subject) do update set
            competition_opted_in = false,
            leaderboard_opt_in = false,
            opted_in_at = null,
            updated_at = excluded.updated_at
        returning subject, display_alias, competition_opted_in,
                  leaderboard_opt_in, opted_in_at, body_weight_kg
        """,
        subject,
        default_display_alias(subject),
        now,
    )
    return _profile_from_row(row)


async def set_leaderboard_visibility(
    pool: Any,
    subject: str,
    visible: bool,
) -> StrengthProfileRow:
    profile = await get_profile(pool, subject)
    if profile is None or not profile.competition_opted_in:
        raise StrengthCompetitionError(
            "competition opt-in required before changing leaderboard visibility"
        )
    row = await pool.fetchrow(
        """
        update public.strength_profiles
        set leaderboard_opt_in = $2, updated_at = now()
        where subject = $1
        returning subject, display_alias, competition_opted_in,
                  leaderboard_opt_in, opted_in_at, body_weight_kg
        """,
        subject,
        visible,
    )
    if row is None:
        raise StrengthCompetitionError("profile not found")
    return _profile_from_row(row)


async def _count_submissions_today(
    pool: Any,
    subject: str,
    season_id: UUID,
    lift_type: LiftType,
) -> int:
    return int(
        await pool.fetchval(
            """
            select count(*)::int
            from public.strength_lift_entries
            where subject = $1
              and season_id = $2
              and lift_type = $3
              and submitted_at >= date_trunc('day', now())
            """,
            subject,
            season_id,
            lift_type,
        )
        or 0
    )


async def _best_1rm_in_window(
    pool: Any,
    subject: str,
    season_id: UUID,
    lift_type: LiftType,
    days: int,
) -> Optional[float]:
    since = _utc_now() - timedelta(days=days)
    val = await pool.fetchval(
        """
        select max(estimated_1rm_kg)
        from public.strength_lift_entries
        where subject = $1
          and season_id = $2
          and lift_type = $3
          and verification_status = any($4::text[])
          and submitted_at >= $5
        """,
        subject,
        season_id,
        lift_type,
        list(COUNTABLE_VERIFICATION),
        since,
    )
    return float(val) if val is not None else None


async def submit_lift(
    pool: Any,
    *,
    subject: str,
    season_id: UUID,
    lift_type: LiftType,
    weight_kg: float,
    reps: int,
    estimated_1rm_kg: float,
    session_date: date,
) -> StrengthLiftEntryRow:
    profile = await get_profile(pool, subject)
    if profile is None or not profile.competition_opted_in:
        raise StrengthCompetitionError("opt-in required before submitting lifts")

    count_today = await _count_submissions_today(pool, subject, season_id, lift_type)
    if count_today >= MAX_DAILY_SUBMISSIONS_PER_LIFT:
        raise StrengthCompetitionError(
            f"maximum {MAX_DAILY_SUBMISSIONS_PER_LIFT} submissions per lift per day"
        )

    recent_best = await _best_1rm_in_window(pool, subject, season_id, lift_type, days=7)
    if recent_best is not None and recent_best > 0:
        max_allowed = recent_best * MAX_WEEKLY_IMPROVEMENT_RATIO
        if estimated_1rm_kg > max_allowed:
            raise StrengthCompetitionError(
                "estimated 1RM improvement exceeds safe weekly limit; "
                "verify weight and reps or wait before retrying"
            )

    row = await pool.fetchrow(
        """
        insert into public.strength_lift_entries (
            subject, season_id, lift_type, weight_kg, reps,
            estimated_1rm_kg, source, verification_status, session_date
        )
        values ($1, $2, $3, $4, $5, $6, 'manual', 'self_reported', $7)
        returning
            id, lift_type, weight_kg, reps, estimated_1rm_kg,
            source, verification_status, session_date, submitted_at
        """,
        subject,
        season_id,
        lift_type,
        weight_kg,
        reps,
        estimated_1rm_kg,
        session_date,
    )
    return _entry_from_row(row)


def _entry_from_row(row: Any) -> StrengthLiftEntryRow:
    return StrengthLiftEntryRow(
        id=row["id"],
        lift_type=row["lift_type"],
        weight_kg=float(row["weight_kg"]),
        reps=row["reps"],
        estimated_1rm_kg=float(row["estimated_1rm_kg"]),
        source=row["source"],
        verification_status=row["verification_status"],
        session_date=row["session_date"],
        submitted_at=row["submitted_at"],
    )


async def fetch_user_bests(
    pool: Any,
    subject: str,
    season_id: UUID,
) -> dict[str, Optional[float]]:
    rows = await pool.fetch(
        """
        select lift_type, max(estimated_1rm_kg) as best_1rm
        from public.strength_lift_entries
        where subject = $1
          and season_id = $2
          and verification_status = any($3::text[])
        group by lift_type
        """,
        subject,
        season_id,
        list(COUNTABLE_VERIFICATION),
    )
    bests: dict[str, Optional[float]] = dict.fromkeys(LIFT_TYPES)
    for row in rows:
        bests[row["lift_type"]] = float(row["best_1rm"])
    return bests


def compute_total_1rm(bests: dict[str, Optional[float]]) -> Optional[float]:
    values = [bests.get(lt) for lt in LIFT_TYPES]
    if any(v is None for v in values):
        return None
    return round(sum(float(v) for v in values if v is not None), 2)


def bests_to_records(bests: dict[str, Optional[float]]) -> dict[str, Any]:
    total = compute_total_1rm(bests)
    return {
        "squat_1rm_kg": bests.get("squat"),
        "bench_1rm_kg": bests.get("bench"),
        "deadlift_1rm_kg": bests.get("deadlift"),
        "total_1rm_kg": total,
    }


async def fetch_recent_entries(
    pool: Any,
    subject: str,
    season_id: UUID,
    limit: int,
) -> list[StrengthLiftEntryRow]:
    limit = max(0, min(limit, 20))
    if limit == 0:
        return []
    rows = await pool.fetch(
        """
        select
            id, lift_type, weight_kg, reps, estimated_1rm_kg,
            source, verification_status, session_date, submitted_at
        from public.strength_lift_entries
        where subject = $1 and season_id = $2
        order by submitted_at desc
        limit $3
        """,
        subject,
        season_id,
        limit,
    )
    return [_entry_from_row(r) for r in rows]


_LEADERBOARD_RANKED_CTE = """
    with per_lift as (
        select
            e.subject,
            e.lift_type,
            max(e.estimated_1rm_kg) as best_1rm
        from public.strength_lift_entries e
        inner join public.strength_profiles p
            on p.subject = e.subject
           and p.competition_opted_in = true
           and p.leaderboard_opt_in = true
        where e.season_id = $1
          and e.verification_status = any($2::text[])
        group by e.subject, e.lift_type
    ),
    pivoted as (
        select
            subject,
            max(case when lift_type = 'squat' then best_1rm end) as squat_1rm,
            max(case when lift_type = 'bench' then best_1rm end) as bench_1rm,
            max(case when lift_type = 'deadlift' then best_1rm end) as deadlift_1rm
        from per_lift
        group by subject
    ),
    ranked as (
        select
            pv.subject,
            p.display_alias,
            pv.squat_1rm,
            pv.bench_1rm,
            pv.deadlift_1rm,
            (pv.squat_1rm + pv.bench_1rm + pv.deadlift_1rm) as total_1rm,
            rank() over (
                order by (pv.squat_1rm + pv.bench_1rm + pv.deadlift_1rm) desc,
                         p.display_alias asc
            ) as rank
        from pivoted pv
        inner join public.strength_profiles p on p.subject = pv.subject
        where pv.squat_1rm is not null
          and pv.bench_1rm is not null
          and pv.deadlift_1rm is not null
    )
"""


async def count_leaderboard_eligible(pool: Any, season_id: UUID) -> int:
    val = await pool.fetchval(
        f"""
        {_LEADERBOARD_RANKED_CTE}
        select count(*)::int from ranked
        """,
        season_id,
        list(COUNTABLE_VERIFICATION),
    )
    return int(val or 0)


async def fetch_my_rank(
    pool: Any,
    subject: str,
    season_id: UUID,
) -> MyRankResult:
    profile = await get_profile(pool, subject)
    bests = await fetch_user_bests(pool, subject, season_id)
    total_participants = await count_leaderboard_eligible(pool, season_id)

    if profile is None or not profile.competition_opted_in:
        return MyRankResult(
            ranked=False,
            rank=None,
            display_alias=profile.display_alias if profile else None,
            reason="not_opted_in",
            total_participants=total_participants,
        )
    if not profile.leaderboard_opt_in:
        return MyRankResult(
            ranked=False,
            rank=None,
            display_alias=profile.display_alias,
            reason="leaderboard_hidden",
            total_participants=total_participants,
        )
    if compute_total_1rm(bests) is None:
        return MyRankResult(
            ranked=False,
            rank=None,
            display_alias=profile.display_alias,
            reason="incomplete_lifts",
            total_participants=total_participants,
        )

    row = await pool.fetchrow(
        f"""
        {_LEADERBOARD_RANKED_CTE}
        select rank, display_alias from ranked where subject = $3
        """,
        season_id,
        list(COUNTABLE_VERIFICATION),
        subject,
    )
    if row is None:
        return MyRankResult(
            ranked=False,
            rank=None,
            display_alias=profile.display_alias,
            reason="incomplete_lifts",
            total_participants=total_participants,
        )
    return MyRankResult(
        ranked=True,
        rank=int(row["rank"]),
        display_alias=str(row["display_alias"]),
        reason=None,
        total_participants=total_participants,
    )


async def fetch_leaderboard(
    pool: Any,
    season_id: UUID,
    *,
    limit: int = 50,
    offset: int = 0,
) -> list[dict[str, Any]]:
    limit = max(1, min(limit, 100))
    offset = max(0, offset)

    rows = await pool.fetch(
        f"""
        {_LEADERBOARD_RANKED_CTE}
        select display_alias, squat_1rm, bench_1rm, deadlift_1rm, total_1rm, rank
        from ranked
        order by rank asc
        limit $3 offset $4
        """,
        season_id,
        list(COUNTABLE_VERIFICATION),
        limit,
        offset,
    )
    return [
        {
            "rank": int(r["rank"]),
            "display_alias": r["display_alias"],
            "squat_1rm_kg": float(r["squat_1rm"]),
            "bench_1rm_kg": float(r["bench_1rm"]),
            "deadlift_1rm_kg": float(r["deadlift_1rm"]),
            "total_1rm_kg": float(r["total_1rm"]),
        }
        for r in rows
    ]


def season_to_dict(season: StrengthSeasonRow) -> dict[str, Any]:
    return {
        "id": str(season.id),
        "slug": season.slug,
        "name": season.name,
        "starts_at": season.starts_at.isoformat(),
        "ends_at": season.ends_at.isoformat(),
        "is_active": season.is_active,
    }


def profile_to_public_dict(profile: StrengthProfileRow) -> dict[str, Any]:
    return {
        "display_alias": profile.display_alias,
        "competition_opted_in": profile.competition_opted_in,
        "leaderboard_opt_in": profile.leaderboard_opt_in,
        "opted_in_at": profile.opted_in_at.isoformat() if profile.opted_in_at else None,
        "body_weight_kg": profile.body_weight_kg,
    }


def submission_to_dict(entry: StrengthLiftEntryRow) -> dict[str, Any]:
    return {
        "id": str(entry.id),
        "lift_type": entry.lift_type,
        "weight_kg": entry.weight_kg,
        "reps": entry.reps,
        "estimated_1rm_kg": entry.estimated_1rm_kg,
        "source": entry.source,
        "verification_status": entry.verification_status,
        "session_date": entry.session_date.isoformat(),
        "submitted_at": entry.submitted_at.isoformat(),
    }
