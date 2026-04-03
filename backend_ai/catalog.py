"""운동 카탈로그 로드 및 운동명 캐노니컬화/한글 표시."""

from __future__ import annotations

import json
import logging
import os
import re
from difflib import SequenceMatcher, get_close_matches
from typing import Any, Optional

logger = logging.getLogger(__name__)

ALL_CATALOG_EXERCISE_NAMES: tuple[str, ...] = ()
CATALOG_NAME_SET: frozenset[str] = frozenset()
LOWER_TO_CANONICAL: dict[str, str] = {}
KO_TO_EN: dict[str, str] = {}
EXERCISE_NAME_ALIASES: dict[str, str] = {}
EXERCISE_NAME_EN_TO_KO: dict[str, str] = {}
exercise_catalog_text: str = ""
EXERCISE_CATALOG_MAX_PER_MUSCLE: int = 6

_CATALOG_LOADED: bool = False


def load_catalog(base_dir: str) -> None:
    """카탈로그·별칭·한글 매핑을 로드한다. 테스트에서는 base_dir 를 backend_ai 루트로 넘긴다."""
    global ALL_CATALOG_EXERCISE_NAMES, CATALOG_NAME_SET, LOWER_TO_CANONICAL
    global KO_TO_EN, EXERCISE_NAME_ALIASES, EXERCISE_NAME_EN_TO_KO
    global exercise_catalog_text, EXERCISE_CATALOG_MAX_PER_MUSCLE, _CATALOG_LOADED

    exercises_json_path = os.path.join(base_dir, "exercises.json")
    exercise_name_ko_path = os.path.join(base_dir, "exercise_name_ko.json")
    exercise_name_aliases_path = os.path.join(base_dir, "exercise_name_aliases.json")

    _EXERCISE_CATALOG_MAX_PER_MUSCLE_RAW = os.getenv(
        "EXERCISE_CATALOG_MAX_PER_MUSCLE", "6"
    )
    try:
        EXERCISE_CATALOG_MAX_PER_MUSCLE = int(_EXERCISE_CATALOG_MAX_PER_MUSCLE_RAW)
    except ValueError:
        EXERCISE_CATALOG_MAX_PER_MUSCLE = 6

    exercise_catalog_text = ""
    try:
        if os.path.exists(exercises_json_path):
            with open(exercises_json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                exercises = data.get("exercises", [])

                _uniq_names = sorted({ex.get("name") for ex in exercises if ex.get("name")})
                ALL_CATALOG_EXERCISE_NAMES = tuple(_uniq_names)
                CATALOG_NAME_SET = frozenset(_uniq_names)
                LOWER_TO_CANONICAL = {n.lower(): n for n in _uniq_names}

                grouped: dict[str, list[str]] = {}
                for ex in exercises:
                    muscles = ex.get("primary_muscles", ["unknown"])
                    name = ex.get("name", "Unknown Exercise")
                    equipment = ex.get("equipment", ["none"])
                    if isinstance(equipment, list) and len(equipment) > 0:
                        eq_str = equipment[0]
                    else:
                        eq_str = str(equipment)

                    entry = f"{name}[{eq_str}]"

                    for muscle in muscles:
                        if muscle not in grouped:
                            grouped[muscle] = []
                        grouped[muscle].append(entry)

                catalog_lines = ["[Available Exercise Catalog]"]
                if EXERCISE_CATALOG_MAX_PER_MUSCLE <= 0:
                    for muscle, names in sorted(grouped.items()):
                        catalog_lines.append(f"- {muscle}: {', '.join(sorted(set(names)))}")
                else:
                    for muscle, names in sorted(grouped.items()):
                        unique_sorted = sorted(set(names))
                        if len(unique_sorted) > EXERCISE_CATALOG_MAX_PER_MUSCLE:
                            picked = unique_sorted[: EXERCISE_CATALOG_MAX_PER_MUSCLE]
                            catalog_lines.append(
                                f"- {muscle}: {', '.join(picked)} "
                                f"(이 부위는 총 {len(unique_sorted)}개 중 상위 {EXERCISE_CATALOG_MAX_PER_MUSCLE}개만 표시)"
                            )
                        else:
                            catalog_lines.append(f"- {muscle}: {', '.join(unique_sorted)}")
                    catalog_lines.append(
                        f"[카탈로그 주입] 부위당 최대 {EXERCISE_CATALOG_MAX_PER_MUSCLE}개. "
                        "루틴의 name은 반드시 위에 나온 문자열과 완전 일치해야 한다."
                    )
                exercise_catalog_text = "\n".join(catalog_lines)
                logger.info("✅ 운동 카탈로그(장비 정보 포함)를 성공적으로 로드했습니다.")
        else:
            logger.warning("⚠️ %s 파일이 없어 카탈로그를 로드하지 못했습니다.", exercises_json_path)
    except Exception as e:
        logger.error("❌ 운동 카탈로그 로드 중 오류 발생: %s", e)

    EXERCISE_NAME_EN_TO_KO = {}
    try:
        with open(exercise_name_ko_path, "r", encoding="utf-8") as kof:
            EXERCISE_NAME_EN_TO_KO = json.load(kof)
        logger.info("✅ exercise_name_ko.json (%d개) 로드", len(EXERCISE_NAME_EN_TO_KO))
    except FileNotFoundError:
        logger.warning("⚠️ exercise_name_ko.json 없음 — 루틴 name 한글 변환 생략")
    except (json.JSONDecodeError, OSError) as e:
        logger.error("❌ exercise_name_ko.json 로드 실패: %s", e)

    KO_TO_EN = {}
    for _en, _ko in EXERCISE_NAME_EN_TO_KO.items():
        if _ko not in KO_TO_EN:
            KO_TO_EN[_ko] = _en

    EXERCISE_NAME_ALIASES = {}
    try:
        with open(exercise_name_aliases_path, "r", encoding="utf-8") as af:
            EXERCISE_NAME_ALIASES = json.load(af)
        if not isinstance(EXERCISE_NAME_ALIASES, dict):
            EXERCISE_NAME_ALIASES = {}
        logger.info("✅ exercise_name_aliases.json (%d개)", len(EXERCISE_NAME_ALIASES))
    except FileNotFoundError:
        logger.warning("⚠️ exercise_name_aliases.json 없음")
    except (json.JSONDecodeError, OSError, TypeError) as e:
        logger.error("❌ exercise_name_aliases.json 로드 실패: %s", e)

    _CATALOG_LOADED = True


def _contains_hangul(s: str) -> bool:
    return any("\uac00" <= c <= "\ud7a3" for c in s)


def canonicalize_exercise_name(raw: Optional[str]) -> str:
    """AI/사용자 문자열을 exercises.json 의 정확한 name 으로 맞춘다."""
    if not isinstance(raw, str):
        return str(raw) if raw is not None else ""
    s = raw.strip()
    if not s:
        return s
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"\[[^\]]+\]\s*$", "", s).strip()

    if _contains_hangul(s) and KO_TO_EN:
        en_from_ko = KO_TO_EN.get(s)
        if en_from_ko:
            s = en_from_ko
        else:
            _ko_keys = list(KO_TO_EN.keys())
            _close_ko = get_close_matches(s, _ko_keys, n=1, cutoff=0.88)
            if _close_ko:
                s = KO_TO_EN[_close_ko[0]]
            else:
                _best_ko: Optional[str] = None
                _best_kr = 0.0
                for _kk in _ko_keys:
                    _kr = SequenceMatcher(None, s, _kk).ratio()
                    if _kr > _best_kr:
                        _best_kr, _best_ko = _kr, _kk
                if _best_ko is not None and _best_kr >= 0.82:
                    s = KO_TO_EN[_best_ko]

    alias_target = EXERCISE_NAME_ALIASES.get(s) or EXERCISE_NAME_ALIASES.get(s.lower())
    if alias_target:
        s = alias_target

    if not ALL_CATALOG_EXERCISE_NAMES:
        return s

    if s in CATALOG_NAME_SET:
        return s
    low = s.lower()
    if low in LOWER_TO_CANONICAL:
        return LOWER_TO_CANONICAL[low]

    close = get_close_matches(s, ALL_CATALOG_EXERCISE_NAMES, n=1, cutoff=0.82)
    if close:
        return close[0]

    try:
        min_ratio = float(os.getenv("EXERCISE_NAME_FUZZY_MIN_RATIO", "0.76"))
    except ValueError:
        min_ratio = 0.76
    sl = s.lower()
    best_name: Optional[str] = None
    best_r = 0.0
    for c in ALL_CATALOG_EXERCISE_NAMES:
        r = SequenceMatcher(None, sl, c.lower()).ratio()
        if r > best_r:
            best_r, best_name = r, c
    if best_name is not None and best_r >= min_ratio:
        return best_name
    return raw.strip()


def strip_mixed_parenthetical_english(display: str) -> str:
    """표시명 끝의 '(Barbell ...)' 형태 영문 괄호를 제거한다."""
    return re.sub(r"\s*\([A-Za-z][^)]*\)\s*$", "", display).strip()


def english_to_korean_display(canonical_en: str) -> str:
    """카탈로그 영문명 → 한글 표시."""
    if not canonical_en:
        return canonical_en
    if canonical_en in EXERCISE_NAME_EN_TO_KO:
        return EXERCISE_NAME_EN_TO_KO[canonical_en]
    try:
        ko_min = float(os.getenv("EXERCISE_NAME_KO_FUZZY_MIN", "0.94"))
    except ValueError:
        ko_min = 0.94
    sl = canonical_en.lower()
    best_ko: Optional[str] = None
    best_r = 0.0
    for en, ko in EXERCISE_NAME_EN_TO_KO.items():
        r = SequenceMatcher(None, sl, en.lower()).ratio()
        if r > best_r:
            best_r, best_ko = r, ko
    if best_ko is not None and best_r >= ko_min:
        return best_ko
    return canonical_en


def localize_routine_exercise_names(routine: Optional[dict]) -> Optional[dict]:
    """exercises[].name 을 카탈로그에 맞춘 뒤 한글 표기로 바꾼 복사본을 반환한다."""
    if not routine or not isinstance(routine, dict):
        return routine
    out = {k: v for k, v in routine.items() if k != "exercises"}
    items = routine.get("exercises")
    if not isinstance(items, list):
        return routine
    new_items: list[Any] = []
    for raw in items:
        if not isinstance(raw, dict):
            new_items.append(raw)
            continue
        ex = dict(raw)
        name_val = ex.get("name")
        if isinstance(name_val, str):
            canonical = canonicalize_exercise_name(name_val)
            ex["name"] = strip_mixed_parenthetical_english(
                english_to_korean_display(canonical)
            )
        new_items.append(ex)
    out["exercises"] = new_items
    return out


# 테스트·레거시 import 호환
def _canonicalize_exercise_name(raw: Optional[str]) -> str:
    return canonicalize_exercise_name(raw)


def _localize_routine_exercise_names(routine: Optional[dict]) -> Optional[dict]:
    return localize_routine_exercise_names(routine)


def _strip_mixed_parenthetical_english(display: str) -> str:
    return strip_mixed_parenthetical_english(display)


def _english_to_korean_display(canonical_en: str) -> str:
    return english_to_korean_display(canonical_en)
