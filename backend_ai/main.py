from __future__ import annotations

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os
from groq import Groq
from dotenv import load_dotenv
import logging
import json
import re
from difflib import SequenceMatcher, get_close_matches
from typing import Any, Optional

# 카탈로그 전체 운동명 (캐노니컬화용)
ALL_CATALOG_EXERCISE_NAMES: tuple[str, ...] = ()
CATALOG_NAME_SET: frozenset[str] = frozenset()
LOWER_TO_CANONICAL: dict[str, str] = {}
KO_TO_EN: dict[str, str] = {}
EXERCISE_NAME_ALIASES: dict[str, str] = {}

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

app = FastAPI()

# 1. GROQ_API_KEY 설정
GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if GROQ_API_KEY:
    client = Groq(api_key=GROQ_API_KEY)
    logger.info("✅ Groq API Key가 로드되었습니다. (Llama 3 활성화 완료)")
else:
    logger.error("❌ Groq API Key를 찾을 수 없습니다!")
    client = None

# 2. 페르소나 및 운동 카탈로그 로드
current_dir = os.path.dirname(os.path.abspath(__file__))
persona_path = os.path.join(current_dir, "persona.txt")
exercises_json_path = os.path.join(current_dir, "exercises.json")

routine_persona_path = os.path.join(current_dir, "routine_persona.txt")
routine_guide_path = os.path.join(current_dir, "routine_generation_guide.json")

ROUTINE_GUIDE_TEXT = ""
try:
    with open(routine_guide_path, "r", encoding="utf-8") as gf:
        # 컴팩트 직렬화로 시스템 프롬프트 토큰 절약 (Groq 등 저TPM 티어 대응)
        ROUTINE_GUIDE_TEXT = json.dumps(
            json.load(gf), ensure_ascii=False, separators=(",", ":")
        )
    logger.info("✅ 루틴 생성 가이드 JSON을 로드했습니다.")
except FileNotFoundError:
    logger.warning("⚠️ routine_generation_guide.json을 찾지 못해 가이드를 주입하지 않습니다.")
except json.JSONDecodeError as e:
    logger.error(f"❌ 루틴 생성 가이드 JSON 파싱 실패: {e}")
except OSError as e:
    logger.error(f"❌ 루틴 생성 가이드 읽기 오류: {e}")

try:
    with open(persona_path, "r", encoding="utf-8") as f:
        SYSTEM_PROMPT = f.read()
    logger.info("✅ 페르소나 파일을 성공적으로 읽었습니다.")
except FileNotFoundError:
    SYSTEM_PROMPT = "당신은 전문 헬스 트레이너입니다."
    logger.warning("⚠️ persona.txt를 찾지 못해 기본 페르소나를 사용합니다.")

try:
    with open(routine_persona_path, "r", encoding="utf-8") as f:
        ROUTINE_SYSTEM_PROMPT = f.read()
    logger.info("✅ 루틴 추천 페르소나 파일을 성공적으로 읽었습니다.")
except FileNotFoundError:
    ROUTINE_SYSTEM_PROMPT = "당신은 주간 운동 데이터 분석 전문가이자 루틴 설계 코치입니다."
    logger.warning("⚠️ routine_persona.txt를 찾지 못해 기본 페르소나를 사용합니다.")

# 운동 카탈로그 로드 및 텍스트화
# 저TPM API 대비: 부위당 최대 N개만 주입 (0 또는 미설정=전체). 정렬·중복 제거 후 앞쪽 N개.
_EXERCISE_CATALOG_MAX_PER_MUSCLE_RAW = os.getenv("EXERCISE_CATALOG_MAX_PER_MUSCLE", "12")
try:
    EXERCISE_CATALOG_MAX_PER_MUSCLE = int(_EXERCISE_CATALOG_MAX_PER_MUSCLE_RAW)
except ValueError:
    EXERCISE_CATALOG_MAX_PER_MUSCLE = 12

exercise_catalog_text = ""
try:
    if os.path.exists(exercises_json_path):
        with open(exercises_json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            exercises = data.get("exercises", [])

            _uniq_names = sorted(
                {ex.get("name") for ex in exercises if ex.get("name")}
            )
            ALL_CATALOG_EXERCISE_NAMES = tuple(_uniq_names)
            CATALOG_NAME_SET = frozenset(_uniq_names)
            LOWER_TO_CANONICAL = {n.lower(): n for n in _uniq_names}

            # primary_muscles 기준으로 그룹화 + 장비(equipment) 정보 추가
            grouped = {}
            for ex in exercises:
                muscles = ex.get("primary_muscles", ["unknown"])
                name = ex.get("name", "Unknown Exercise")
                # 장비 정보 가져오기 (리스트일 경우 첫 번째 값 또는 문자열)
                equipment = ex.get("equipment", ["none"])
                if isinstance(equipment, list) and len(equipment) > 0:
                    eq_str = equipment[0]
                else:
                    eq_str = str(equipment)

                # 이름 뒤에 [장비] 태그 붙이기 (예: Lat Pulldown[machine])
                entry = f"{name}[{eq_str}]"

                for muscle in muscles:
                    if muscle not in grouped:
                        grouped[muscle] = []
                    grouped[muscle].append(entry)

            # 텍스트 생성
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
        logger.warning(f"⚠️ {exercises_json_path} 파일이 없어 카탈로그를 로드하지 못했습니다.")
except Exception as e:
    logger.error(f"❌ 운동 카탈로그 로드 중 오류 발생: {e}")

# 영문 카탈로그명 → 한글 표시명 (앱 exercise_name_ko.dart 와 동기화, scripts/export_exercise_name_ko.py 로 갱신)
exercise_name_ko_path = os.path.join(current_dir, "exercise_name_ko.json")
EXERCISE_NAME_EN_TO_KO: dict[str, str] = {}
try:
    with open(exercise_name_ko_path, "r", encoding="utf-8") as kof:
        EXERCISE_NAME_EN_TO_KO = json.load(kof)
    logger.info("✅ exercise_name_ko.json (%d개) 로드", len(EXERCISE_NAME_EN_TO_KO))
except FileNotFoundError:
    logger.warning("⚠️ exercise_name_ko.json 없음 — 루틴 name 한글 변환 생략")
except (json.JSONDecodeError, OSError) as e:
    logger.error("❌ exercise_name_ko.json 로드 실패: %s", e)

# 한글 표시명 → 영문 카탈로그명 (첫 매핑 우선)
for _en, _ko in EXERCISE_NAME_EN_TO_KO.items():
    if _ko not in KO_TO_EN:
        KO_TO_EN[_ko] = _en

exercise_name_aliases_path = os.path.join(current_dir, "exercise_name_aliases.json")
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


def _contains_hangul(s: str) -> bool:
    return any("\uac00" <= c <= "\ud7a3" for c in s)


def _canonicalize_exercise_name(raw: Optional[str]) -> str:
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

    alias_target = EXERCISE_NAME_ALIASES.get(s) or EXERCISE_NAME_ALIASES.get(
        s.lower()
    )
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


def _strip_mixed_parenthetical_english(display: str) -> str:
    """표시명 끝의 '(Barbell ...)' 형태 영문 괄호를 제거한다."""
    return re.sub(r"\s*\([A-Za-z][^)]*\)\s*$", "", display).strip()


def _english_to_korean_display(canonical_en: str) -> str:
    """카탈로그 영문명 → 한글 표시. 직접 매핑 없으면 매우 유사한 등록명의 한글만 사용."""
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


def _localize_routine_exercise_names(routine: Optional[dict]) -> Optional[dict]:
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
            canonical = _canonicalize_exercise_name(name_val)
            ex["name"] = _strip_mixed_parenthetical_english(
                _english_to_korean_display(canonical)
            )
        new_items.append(ex)
    out["exercises"] = new_items
    return out


class ChatRequest(BaseModel):
    user_id: str
    message: str
    context: str = ""

class RecommendRequest(BaseModel):
    user_id: str
    weekly_summary: str

@app.get("/")
def read_root():
    return {"status": "online", "message": "Gains & Guide AI Coach Server is Running!"}

@app.post("/chat")
async def chat_with_coach(request: ChatRequest):
    if not client:
        raise HTTPException(status_code=500, detail="서버에 Groq API 키가 없습니다.")

    try:
        full_system_prompt = SYSTEM_PROMPT
        if ROUTINE_GUIDE_TEXT:
            full_system_prompt += "\n\n[ROUTINE_GENERATION_GUIDE]\n" + ROUTINE_GUIDE_TEXT
        if exercise_catalog_text:
            # 👇 핵심 추가: AI가 한국어 부위를 영어 카탈로그와 매칭할 수 있도록 번역/매칭 가이드 주입
            korean_mapping_guide = (
                "\n\n[부위 매칭 참고 가이드]\n"
                "사용자가 한국어로 특정 부위를 요청하면 아래 영어 부위명과 매칭하여 카탈로그에서 운동을 찾으세요:\n"
                "- 등: lats, middle back, lower back\n"
                "- 이두: biceps\n"
                "- 가슴: chest\n"
                "- 어깨: shoulders\n"
                "- 하체: quadriceps, hamstrings, glutes, calves\n"
                "- 삼두: triceps\n"
                "- 복근: abs\n"
            )
            full_system_prompt += f"{korean_mapping_guide}\n{exercise_catalog_text}"

        messages = [
            {"role": "system", "content": full_system_prompt},
            {"role": "user", "content": f"[과거 운동 기록]\n{request.context}\n\n[질문]\n{request.message}"}
        ]

        chat_completion = client.chat.completions.create(
            messages=messages,
            model="llama-3.1-8b-instant",
            temperature=0.7,
            max_tokens=1024,
            response_format={"type": "json_object"}
        )

        reply = chat_completion.choices[0].message.content

        try:
            parsed_reply = json.loads(reply)
            text_response = parsed_reply.get("response") or parsed_reply.get("message") or "답변 내용을 찾을 수 없습니다."

            return {
                "response": text_response,
                "routine": _localize_routine_exercise_names(
                    parsed_reply.get("routine")
                ),
            }
        except json.JSONDecodeError:
            return {"response": reply, "routine": None}

    except Exception as e:
        logger.exception("❌ 답변 생성 중 오류 발생:")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/recommend")
async def recommend_routine(request: RecommendRequest):
    if not client:
        raise HTTPException(status_code=500, detail="서버에 Groq API 키가 없습니다.")

    try:
        full_system_prompt = ROUTINE_SYSTEM_PROMPT
        if ROUTINE_GUIDE_TEXT:
            full_system_prompt += "\n\n[ROUTINE_GENERATION_GUIDE]\n" + ROUTINE_GUIDE_TEXT
        if exercise_catalog_text:
            korean_mapping_guide = (
                "\n\n[부위 매칭 참고 가이드]\n"
                "- 등: lats, middle back, lower back\n"
                "- 이두: biceps\n"
                "- 가슴: chest\n"
                "- 어깨: shoulders\n"
                "- 하체: quadriceps, hamstrings, glutes, calves\n"
                "- 삼두: triceps\n"
                "- 복근: abs\n"
            )
            full_system_prompt += f"{korean_mapping_guide}\n{exercise_catalog_text}"

        messages = [
            {"role": "system", "content": full_system_prompt},
            {"role": "user", "content": f"[주간 운동 분석 데이터]\n{request.weekly_summary}\n\n[지시]\n위 분석 데이터를 바탕으로 다음 주 추천 루틴을 JSON으로 생성해주세요."}
        ]

        chat_completion = client.chat.completions.create(
            messages=messages,
            model="llama-3.1-8b-instant",
            temperature=0.7,
            max_tokens=1024,
            response_format={"type": "json_object"}
        )

        reply = chat_completion.choices[0].message.content

        try:
            parsed_reply = json.loads(reply)
            routine = parsed_reply.get("routine")

            if routine is None:
                return {"routine": {"title": "기본 추천 루틴", "rationale": "분석 데이터 기반 기본 루틴입니다.", "exercises": []}}

            return {"routine": _localize_routine_exercise_names(routine)}
        except json.JSONDecodeError:
            logger.error(f"JSON 파싱 실패: {reply}")
            raise HTTPException(status_code=500, detail="AI 응답 파싱에 실패했습니다.")

    except HTTPException:
        raise
    except Exception as e:
        logger.exception("❌ 루틴 추천 생성 중 오류 발생:")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)