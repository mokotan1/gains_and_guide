"""Strength competition API Pydantic schemas."""

from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class LiftType(str, Enum):
    squat = "squat"
    bench = "bench"
    deadlift = "deadlift"


class ProfileUpdateIn(BaseModel):
    display_alias: Optional[str] = Field(default=None, max_length=24)
    competition_opted_in: Optional[bool] = None
    leaderboard_opt_in: Optional[bool] = None
    body_weight_kg: Optional[float] = Field(default=None, ge=30, le=250)


class SubmitLiftIn(BaseModel):
    lift_type: LiftType
    weight_kg: float = Field(gt=0, le=500)
    reps: int = Field(ge=1, le=12)
    session_date: Optional[date] = None


class SeasonOut(BaseModel):
    id: str
    slug: str
    name: str
    starts_at: datetime
    ends_at: datetime
    is_active: bool


class ProfileOut(BaseModel):
    display_alias: str
    competition_opted_in: bool
    leaderboard_opt_in: bool
    opted_in_at: Optional[datetime] = None
    body_weight_kg: Optional[float] = None


class LiftEntryOut(BaseModel):
    id: str
    lift_type: str
    weight_kg: float
    reps: int
    estimated_1rm_kg: float
    source: str
    verification_status: str
    session_date: date
    submitted_at: datetime


class RecordsOut(BaseModel):
    squat_1rm_kg: Optional[float] = None
    bench_1rm_kg: Optional[float] = None
    deadlift_1rm_kg: Optional[float] = None
    total_1rm_kg: Optional[float] = None


class LeaderboardEntryOut(BaseModel):
    rank: int
    display_alias: str
    squat_1rm_kg: float
    bench_1rm_kg: float
    deadlift_1rm_kg: float
    total_1rm_kg: float


class CurrentSeasonResponse(BaseModel):
    season: Optional[SeasonOut] = None


class ProfileResponse(BaseModel):
    profile: Optional[ProfileOut] = None


class SubmitLiftResponse(BaseModel):
    entry: LiftEntryOut
    season: SeasonOut
    records: RecordsOut


class RecordsMeResponse(BaseModel):
    season: SeasonOut
    profile: Optional[ProfileOut] = None
    records: RecordsOut
    recent_entries: list[LiftEntryOut] = Field(default_factory=list)


class LeaderboardResponse(BaseModel):
    season: SeasonOut
    entries: list[LeaderboardEntryOut]
    limit: int
    offset: int
    total_eligible: int


class MyRankResponse(BaseModel):
    season: SeasonOut
    ranked: bool
    rank: Optional[int] = None
    display_alias: Optional[str] = None
    reason: Optional[str] = None
    records: RecordsOut
    total_participants: int = 0
