"""페르소나·루틴 가이드 등 프롬프트 자산 로드."""

from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class PromptAssets:
    system_prompt: str
    routine_system_prompt: str
    routine_guide_text: str


def load_prompt_assets(base_dir: str) -> PromptAssets:
    persona_path = os.path.join(base_dir, "persona.txt")
    routine_persona_path = os.path.join(base_dir, "routine_persona.txt")
    routine_guide_path = os.path.join(base_dir, "routine_generation_guide.json")

    routine_guide_text = ""
    try:
        with open(routine_guide_path, "r", encoding="utf-8") as gf:
            routine_guide_text = json.dumps(
                json.load(gf), ensure_ascii=False, separators=(",", ":")
            )
        logger.info("✅ 루틴 생성 가이드 JSON을 로드했습니다.")
    except FileNotFoundError:
        logger.warning("⚠️ routine_generation_guide.json을 찾지 못해 가이드를 주입하지 않습니다.")
    except json.JSONDecodeError as e:
        logger.error("❌ 루틴 생성 가이드 JSON 파싱 실패: %s", e)
    except OSError as e:
        logger.error("❌ 루틴 생성 가이드 읽기 오류: %s", e)

    try:
        with open(persona_path, "r", encoding="utf-8") as f:
            system_prompt = f.read()
        logger.info("✅ 페르소나 파일을 성공적으로 읽었습니다.")
    except FileNotFoundError:
        system_prompt = "당신은 전문 헬스 트레이너입니다."
        logger.warning("⚠️ persona.txt를 찾지 못해 기본 페르소나를 사용합니다.")

    try:
        with open(routine_persona_path, "r", encoding="utf-8") as f:
            routine_system_prompt = f.read()
        logger.info("✅ 루틴 추천 페르소나 파일을 성공적으로 읽었습니다.")
    except FileNotFoundError:
        routine_system_prompt = (
            "당신은 주간 운동 데이터 분석 전문가이자 루틴 설계 코치입니다."
        )
        logger.warning("⚠️ routine_persona.txt를 찾지 못해 기본 페르소나를 사용합니다.")

    return PromptAssets(
        system_prompt=system_prompt,
        routine_system_prompt=routine_system_prompt,
        routine_guide_text=routine_guide_text,
    )


def korean_muscle_mapping_block() -> str:
    return (
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


def append_routine_guide(system: str, routine_guide_text: str) -> str:
    if not routine_guide_text.strip():
        return system
    return system + "\n\n[ROUTINE_GENERATION_GUIDE]\n" + routine_guide_text


def append_catalog(system: str, catalog_text: str) -> str:
    if not catalog_text.strip():
        return system
    return system + korean_muscle_mapping_block() + "\n" + catalog_text
