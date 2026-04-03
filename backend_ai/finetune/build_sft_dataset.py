#!/usr/bin/env python3
"""레포 정적 자산에서 LLaMA-Factory ShareGPT 형식 학습 JSON을 생성한다."""

from __future__ import annotations

import argparse
import json
import random
import re
from pathlib import Path
from typing import Any, Iterator

# backend_ai 루트를 기준으로 리소스 탐색
_BACKEND_ROOT = Path(__file__).resolve().parent.parent


def _read_text(rel: str, *, max_chars: int | None = None) -> str:
    p = _BACKEND_ROOT / rel
    raw = p.read_text(encoding="utf-8")
    if max_chars is not None and len(raw) > max_chars:
        return raw[: max_chars - 20].rstrip() + "\n…[truncated]"
    return raw


def _load_json(rel: str) -> dict[str, Any]:
    with open(_BACKEND_ROOT / rel, encoding="utf-8") as f:
        return json.load(f)


def _sharegpt_row(system: str, human: str, gpt: str) -> dict[str, Any]:
    return {
        "conversations": [
            {"from": "system", "value": system.strip()},
            {"from": "human", "value": human.strip()},
            {"from": "gpt", "value": gpt.strip()},
        ]
    }


def _compress_design_principles(guide: dict[str, Any]) -> str:
    dp = guide.get("design_principles") or {}
    if not isinstance(dp, dict):
        return ""
    parts = [f"{k}: {v}" for k, v in sorted(dp.items())]
    return "\n".join(parts)


def _sessions_to_recommend_routine(
    title: str, rationale: str, sessions: list[dict[str, Any]]
) -> dict[str, Any]:
    exercises: list[dict[str, Any]] = []
    for block in sessions:
        for ex in block.get("exercises") or []:
            if not isinstance(ex, dict):
                continue
            name = ex.get("name")
            if not name:
                continue
            exercises.append(
                {
                    "name": str(name),
                    "sets": int(ex.get("sets") or 3),
                    "reps": int(ex.get("reps") or 10),
                    "weight": float(ex.get("weight", 0.0) or 0.0),
                }
            )
    return {
        "routine": {
            "title": title,
            "rationale": rationale,
            "exercises": exercises,
        }
    }


def _circuit_to_recommend_routine(
    title: str, rationale: str, circuit: dict[str, Any]
) -> dict[str, Any]:
    exercises: list[dict[str, Any]] = []
    rounds = int(circuit.get("rounds") or 3)
    for st in circuit.get("stations") or []:
        if not isinstance(st, dict):
            continue
        name = st.get("name")
        if not name:
            continue
        reps = st.get("reps") or st.get("reps_per_arm") or 15
        exercises.append(
            {
                "name": str(name),
                "sets": rounds,
                "reps": int(reps),
                "weight": 0.0,
            }
        )
    return {
        "routine": {
            "title": title,
            "rationale": rationale,
            "exercises": exercises,
        }
    }


def _profile_phrasings(profile: dict[str, Any]) -> list[str]:
    목적 = profile.get("목적", "")
    경력 = profile.get("경력", "")
    빈도 = profile.get("빈도", "")
    장비 = profile.get("장비", "")
    blob = json.dumps(profile, ensure_ascii=False)
    return [
        f"프로필에 맞는 주간 루틴을 JSON으로 제안해 줘.\n프로필: {blob}",
        f"목적: {목적}, 경력: {경력}, 빈도: {빈도}, 장비: {장비}. 루틴 추천해 줘. routine JSON만 포함해.",
        f"나는 {경력}이고 {빈도} {장비}로 {목적} 하고 싶어. 다음 주에 할 운동을 JSON routine으로 알려줘.",
        f"[프로필]\n목적 {목적}\n경력 {경력}\n빈도 {빈도}\n장비 {장비}\n\n위에 맞춰 recommend routine JSON 생성.",
        f"코치님, {목적} 목표로 {빈도} 쓸 수 있는 루틴 짜줘. 장비는 {장비}, 수준은 {경력}.",
        f"다음 주 루틴 설계 부탁해. 조건: {blob}",
        f"{빈도}만 운동 가능하고 {장비}만 있어. {목적}이 목표인데 {경력} 수준이야. JSON으로 루틴 줘.",
        f"운동 계획 세워줘 — {목적}, {경력}, {빈도}, 장비:{장비}. 출력은 JSON routine 형식.",
        f"내 상황: {blob}\n이에 맞는 추천 루틴을 영문 운동명으로 JSON에 담아줘.",
        f"{경력} 차원에서 {빈도} {장비} 루틴이 필요해. 목적은 {목적}. routine 키만 있는 JSON으로.",
    ]


def _chat_coach_reply_from_example(
    rationale: str, coaching_tip: str, rec: dict[str, Any]
) -> str:
    payload = {
        "response": f"{rationale} {coaching_tip}".strip(),
        "routine": rec.get("routine"),
        "progression": None,
    }
    return json.dumps(payload, ensure_ascii=False)


def _recommend_assistant_json(routine_root: dict[str, Any]) -> str:
    return json.dumps(routine_root, ensure_ascii=False)


def iter_dataset_rows(
    *,
    coach_system_max: int = 3200,
    routine_system_max: int = 2800,
    seed: int = 42,
) -> Iterator[dict[str, Any]]:
    rnd = random.Random(seed)
    guide = _load_json("routine_generation_guide.json")
    design_block = _compress_design_principles(guide)

    coach_sys = (
        "[GainsCoach /chat]\n"
        + _read_text("persona.txt", max_chars=coach_system_max)
        + "\n\n[설계 원칙 요약]\n"
        + design_block
        + "\n\n[출력] 오직 JSON 한 객체: "
        '{"response": string, "routine": object|null, "progression": array|null}\n'
        "routine.exercises[].name 은 카탈로그 영문명과 동일해야 한다."
    )

    routine_sys = (
        "[GainsCoach /recommend]\n"
        + _read_text("routine_persona.txt", max_chars=routine_system_max)
        + "\n\n[설계 원칙 요약]\n"
        + design_block
        + "\n\n[출력] 오직 JSON 한 객체: "
        '{"routine": {"title","rationale","exercises":[{"name","sets","reps","weight"}]}}\n'
    )

    few = guide.get("few_shot_examples") or []
    for ex in few:
        if not isinstance(ex, dict):
            continue
        profile = ex.get("user_profile") or {}
        rationale = str(ex.get("rationale") or "")
        tip = str(ex.get("coaching_tip") or "")
        title = f"{profile.get('목적', '루틴')} — {profile.get('빈도', '')}"

        if "sessions" in ex:
            rec = _sessions_to_recommend_routine(title, rationale, ex["sessions"])
        elif "circuit" in ex:
            rec = _circuit_to_recommend_routine(
                title, rationale, ex["circuit"]
            )
        else:
            continue

        # /recommend 스타일
        for phrase in _profile_phrasings(profile):
            yield _sharegpt_row(
                routine_sys,
                f"[주간 운동 분석 데이터]\n{phrase}\n\n[지시] 다음 주 추천 루틴을 JSON으로 생성.",
                _recommend_assistant_json(rec),
            )

        # /chat 스타일 (동일 few-shot을 챗 계약으로)
        routine_only = rec.get("routine")
        chat_out = _chat_coach_reply_from_example(rationale, tip, rec)
        ctx = "[과거 운동 기록]\n(없음)\n"
        for phrase in _profile_phrasings(profile):
            human = f"{ctx}\n[질문]\n{phrase}"
            yield _sharegpt_row(coach_sys, human, chat_out)

        # 증량 제안 예시 (합성)
        if rnd.random() < 0.5 and routine_only and routine_only.get("exercises"):
            first = routine_only["exercises"][0]
            name = first.get("name")
            if name:
                prog = {
                    "response": f"지난 세션 {name} 5x5 완수. 소폭 증량을 제안합니다, 주인님.",
                    "routine": None,
                    "progression": [{"name": str(name), "increase": 2.5}],
                }
                yield _sharegpt_row(
                    coach_sys,
                    f"{ctx}\n[질문]\n지난번 {name} 다 성공했어. 증량 어떻게 할까?",
                    json.dumps(prog, ensure_ascii=False),
                )

    # corpus chunks → 짧은 Q&A
    chunks_path = _BACKEND_ROOT / "corpus" / "chunks.jsonl"
    if chunks_path.is_file():
        for line in chunks_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            text = (row.get("text") or "").strip()
            if len(text) < 10:
                continue
            topic = str(row.get("topic") or "coaching")
            summary_sys = (
                "당신은 헬스 코치입니다. 한 문장으로만 답합니다. "
                "JSON이 아닌 평문 한 문장."
            )
            yield _sharegpt_row(
                summary_sys,
                f"다음 규칙을 한 문장으로 요약해 줘:\n{text}",
                _one_sentence_summary(text, topic, rnd),
            )


def _one_sentence_summary(text: str, topic: str, rnd: random.Random) -> str:
    """규칙 기반 짧은 요약 (외부 LLM 없음)."""
    t = re.sub(r"\s+", " ", text)[:200]
    starters = [
        f"핵심은 {topic} 관점에서 ",
        "요지는 ",
        "한 줄로 말하면 ",
    ]
    return f"{rnd.choice(starters)}{t}… 라는 점입니다."


def build_dataset(
    *,
    coach_system_max: int = 3200,
    routine_system_max: int = 2800,
    seed: int = 42,
) -> list[dict[str, Any]]:
    return list(
        iter_dataset_rows(
            coach_system_max=coach_system_max,
            routine_system_max=routine_system_max,
            seed=seed,
        )
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--out",
        type=Path,
        default=_BACKEND_ROOT / "finetune" / "output" / "gains_coach_sft_sharegpt.json",
        help="출력 JSON (배열) 경로",
    )
    parser.add_argument("--jsonl", action="store_true", help="JSONL로 저장 (한 줄 한 샘플)")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument(
        "--validate",
        action="store_true",
        help="저장 후 validate_sft_samples 로 assistant JSON 계약 검사",
    )
    args = parser.parse_args()

    rows = build_dataset(seed=args.seed)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    if args.jsonl:
        with args.out.open("w", encoding="utf-8") as f:
            for r in rows:
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
    else:
        args.out.write_text(
            json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8"
        )
    print(f"wrote {len(rows)} samples -> {args.out}")

    if args.validate:
        from finetune.validate_sft_samples import validate_dataset

        ok, fail, msgs = validate_dataset(rows)
        print(f"validate: ok={ok} fail={fail}")
        if msgs:
            for m in msgs:
                print(f"  ! {m}")
        if fail:
            raise SystemExit(1)


if __name__ == "__main__":
    main()
