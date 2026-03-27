"""LangChain 도구: 1RM·운동명 캐노니컬화 (앱 도메인과 동일 공식)."""

from __future__ import annotations

import json
from typing import Annotated

from langchain_core.tools import tool

from catalog import canonicalize_exercise_name
from services.constants import EPLEY_DIVISOR


def epley_one_rm_kg(weight_kg: float, reps: int) -> float:
    """Epley 추정 1RM(kg). weight<=0 또는 reps<1 이면 ValueError."""
    if weight_kg <= 0:
        raise ValueError("weight_kg must be positive")
    if reps < 1:
        raise ValueError("reps must be at least 1")
    return float(weight_kg) * (1.0 + float(reps) / EPLEY_DIVISOR)


@tool
def calculate_1rm(
    weight_kg: Annotated[float, "세트 무게(kg)"],
    reps: Annotated[int, "해당 무게로 수행한 반복 수(1 이상)"],
) -> str:
    """Epley 공식으로 예상 1RM(kg)을 계산한다. 숫자 추측 대신 이 도구를 사용하라."""
    try:
        est = epley_one_rm_kg(weight_kg, reps)
    except ValueError as e:
        return json.dumps({"error": str(e)}, ensure_ascii=False)
    return json.dumps(
        {
            "estimated_1rm_kg": round(est, 2),
            "formula": f"weight * (1 + reps / {EPLEY_DIVISOR})",
        },
        ensure_ascii=False,
    )


@tool
def match_exercise_catalog_name(
    raw_name: Annotated[str, "사용자 또는 AI가 쓴 운동 이름(한글·영문·별칭)"],
) -> str:
    """exercises.json 카탈로그의 정확한 영문 운동명으로 맞춘다. 루틴 JSON의 name 필드에 쓸 값."""
    canonical = canonicalize_exercise_name(raw_name)
    return json.dumps({"canonical_name": canonical}, ensure_ascii=False)


@tool
def build_progression_table_json(
    exercise_name: Annotated[str, "카탈로그 운동명(영문)"],
    weeks: Annotated[int, "제안할 주 수(1~8)"],
    start_weight_kg: Annotated[float, "시작 무게(kg)"],
    sets: Annotated[int, "세트 수"],
    reps: Annotated[int, "목표 반복"],
    weekly_increment_kg: Annotated[float, "주당 증량(kg)"],
) -> str:
    """단순 선형 증량 표를 JSON으로 반환한다. LLM은 이 결과를 설명만 한다."""
    if weeks < 1 or weeks > 8:
        return json.dumps({"error": "weeks must be 1..8"}, ensure_ascii=False)
    if sets < 1 or reps < 1:
        return json.dumps({"error": "sets and reps must be >= 1"}, ensure_ascii=False)
    rows = []
    for w in range(weeks):
        rows.append(
            {
                "week_index": w + 1,
                "weight_kg": round(start_weight_kg + weekly_increment_kg * w, 2),
                "sets": sets,
                "reps": reps,
            }
        )
    return json.dumps(
        {"exercise_name": exercise_name, "progression": rows}, ensure_ascii=False
    )


COACH_TOOLS = [
    calculate_1rm,
    match_exercise_catalog_name,
    build_progression_table_json,
]
