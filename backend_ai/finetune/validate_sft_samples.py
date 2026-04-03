#!/usr/bin/env python3
"""SFT ShareGPT 샘플의 assistant(JSON 계약) 검증 — 학습 전 스모크 테스트용."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, List, Tuple

_BACKEND_ROOT = Path(__file__).resolve().parent.parent


def _is_corpus_plaintext_row(system: str) -> bool:
    s = system.lower()
    return "평문" in system or "한 문장" in system or "json이 아닌" in s


def validate_gpt_content(system: str, gpt: str) -> List[str]:
    """위반 시 사람이 읽을 메시지 목록 반환. 빈 리스트면 통과."""
    errs: List[str] = []
    gpt = (gpt or "").strip()
    if not gpt:
        return ["empty gpt content"]

    if _is_corpus_plaintext_row(system):
        if gpt.startswith("{") or gpt.startswith("["):
            errs.append("corpus row: expected plain sentence, got JSON-like output")
        return errs

    try:
        data = json.loads(gpt)
    except json.JSONDecodeError as e:
        return [f"invalid JSON: {e}"]

    if not isinstance(data, dict):
        return ["root must be a JSON object"]

    # /recommend: { "routine": { title, rationale, exercises } }
    if "response" not in data and "routine" in data:
        return _validate_recommend_routine(data["routine"])

    # /chat: CoachChatResponse
    if "response" in data:
        return _validate_coach_chat(data)

    return ["unrecognized JSON shape (no response and no routine)"]


def _validate_coach_chat(data: dict[str, Any]) -> List[str]:
    errs: List[str] = []
    r = data.get("response")
    if not isinstance(r, str) or not r.strip():
        errs.append("chat: response must be non-empty string")

    routine = data.get("routine")
    if routine is not None and not isinstance(routine, dict):
        errs.append("chat: routine must be object or null")

    prog = data.get("progression")
    if prog is not None:
        if not isinstance(prog, list):
            errs.append("chat: progression must be array or null")
        else:
            for i, item in enumerate(prog):
                if not isinstance(item, dict):
                    errs.append(f"chat: progression[{i}] must be object")
                    continue
                if not str(item.get("name", "")).strip():
                    errs.append(f"chat: progression[{i}].name required")
                inc = item.get("increase")
                if not isinstance(inc, (int, float)) or isinstance(inc, bool):
                    errs.append(f"chat: progression[{i}].increase must be number")
    return errs


def _validate_recommend_routine(routine: Any) -> List[str]:
    errs: List[str] = []
    if not isinstance(routine, dict):
        return ["recommend: routine must be object"]
    if not str(routine.get("title", "")).strip():
        errs.append("recommend: routine.title required")
    if not str(routine.get("rationale", "")).strip():
        errs.append("recommend: routine.rationale required")
    ex = routine.get("exercises")
    if ex is None:
        errs.append("recommend: routine.exercises required")
    elif not isinstance(ex, list):
        errs.append("recommend: routine.exercises must be array")
    else:
        for i, e in enumerate(ex):
            if not isinstance(e, dict):
                errs.append(f"recommend: exercises[{i}] must be object")
                continue
            if not str(e.get("name", "")).strip():
                errs.append(f"recommend: exercises[{i}].name required")
            for k, t in (("sets", int), ("reps", int)):
                v = e.get(k)
                if not isinstance(v, int) or isinstance(v, bool):
                    errs.append(f"recommend: exercises[{i}].{k} must be int")
            w = e.get("weight", 0)
            if not isinstance(w, (int, float)):
                errs.append(f"recommend: exercises[{i}].weight must be number if set")
    return errs


def validate_sharegpt_row(row: dict[str, Any], *, index: int = 0) -> List[str]:
    errs: List[str] = []
    conv = row.get("conversations")
    if not isinstance(conv, list) or len(conv) != 3:
        return [f"row {index}: conversations must be length-3 list"]
    roles = [c.get("from") for c in conv]
    if roles != ["system", "human", "gpt"]:
        errs.append(f"row {index}: expected from order system,human,gpt got {roles}")
    system = str(conv[0].get("value") or "")
    gpt = str(conv[2].get("value") or "")
    errs.extend([f"row {index}: {m}" for m in validate_gpt_content(system, gpt)])
    return errs


def validate_dataset(rows: list[dict[str, Any]]) -> Tuple[int, int, List[str]]:
    """Returns (ok_count, fail_count, error_messages cap)."""
    ok = 0
    fail_msgs: List[str] = []
    for i, row in enumerate(rows):
        e = validate_sharegpt_row(row, index=i)
        if e:
            fail_msgs.extend(e)
        else:
            ok += 1
    fail = len(rows) - ok
    cap = fail_msgs[:24]
    if len(fail_msgs) > 24:
        cap.append(f"... and {len(fail_msgs) - 24} more messages")
    return ok, fail, cap


def _load_rows(path: Path) -> list[dict[str, Any]]:
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        return []
    if path.suffix.lower() == ".jsonl":
        rows = []
        for line in text.splitlines():
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))
        return rows
    data = json.loads(text)
    if isinstance(data, list):
        return data
    raise ValueError("JSON file must be array or JSONL")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "path",
        type=Path,
        nargs="?",
        default=_BACKEND_ROOT / "finetune" / "output" / "gains_coach_sft_sharegpt.json",
        help="ShareGPT JSON 배열 또는 JSONL",
    )
    args = parser.parse_args()
    if not args.path.is_file():
        print(f"missing file: {args.path}", file=sys.stderr)
        sys.exit(2)
    rows = _load_rows(args.path)
    ok, fail, msgs = validate_dataset(rows)
    print(f"validated {len(rows)} rows: ok={ok} fail={fail}")
    if msgs:
        for m in msgs:
            print(f"  - {m}", file=sys.stderr)
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
