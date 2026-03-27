"""
free-exercise-db (https://github.com/yuhonas/free-exercise-db) 데이터를
gains_and_guide 프로젝트의 exercises.json 포맷으로 변환하는 스크립트.

Usage:
    python scripts/convert_exercises.py
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
SOURCE_PATH = SCRIPT_DIR / "source_exercises.json"
ASSET_OUTPUT = PROJECT_ROOT / "assets" / "data" / "exercises.json"
BACKEND_OUTPUT = PROJECT_ROOT / "backend_ai" / "exercises.json"

EQUIPMENT_MAP: dict[str | None, str] = {
    None: "none",
    "body only": "none",
    "kettlebells": "kettlebell",
    "e-z curl bar": "ez curl bar",
    "foam roll": "foam roll",
    "exercise ball": "exercise ball",
    "medicine ball": "medicine ball",
    "dumbbell": "dumbbell",
    "barbell": "barbell",
    "cable": "cable",
    "machine": "machine",
    "bands": "bands",
    "other": "other",
}

MUSCLE_MAP: dict[str, str] = {
    "abdominals": "abs",
    "abductors": "abductors",
    "adductors": "adductors",
    "biceps": "biceps",
    "calves": "calves",
    "chest": "chest",
    "forearms": "forearms",
    "glutes": "glutes",
    "hamstrings": "hamstrings",
    "lats": "lats",
    "lower back": "lower back",
    "middle back": "middle back",
    "neck": "neck",
    "quadriceps": "quadriceps",
    "shoulders": "shoulders",
    "traps": "traps",
    "triceps": "triceps",
}


def _map_equipment(raw: str | None) -> str:
    if raw is None:
        return "none"
    return EQUIPMENT_MAP.get(raw, raw)


def _map_muscles(raw_list: list[str]) -> list[str]:
    return [MUSCLE_MAP.get(m, m) for m in raw_list]


def convert_exercise(src: dict[str, Any]) -> dict[str, Any]:
    equipment_str = _map_equipment(src.get("equipment"))
    return {
        "name": src["name"],
        "category": src.get("category", ""),
        "equipment": [equipment_str],
        "primary_muscles": _map_muscles(src.get("primaryMuscles", [])),
        "secondary_muscles": _map_muscles(src.get("secondaryMuscles", [])),
        "instructions": src.get("instructions", []),
        "level": src.get("level", ""),
        "force": src.get("force") or "",
        "mechanic": src.get("mechanic") or "",
    }


def collect_unique_sorted(exercises: list[dict], key: str) -> list[str]:
    values: set[str] = set()
    for ex in exercises:
        val = ex[key]
        if isinstance(val, list):
            values.update(v for v in val if v)
        elif val:
            values.add(val)
    return sorted(values)


def main() -> None:
    if not SOURCE_PATH.exists():
        print(f"ERROR: Source file not found at {SOURCE_PATH}", file=sys.stderr)
        print("Download it first:", file=sys.stderr)
        print(
            '  Invoke-WebRequest -Uri "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json"'
            f' -OutFile "{SOURCE_PATH}"',
            file=sys.stderr,
        )
        sys.exit(1)

    with open(SOURCE_PATH, "r", encoding="utf-8") as f:
        source_data: list[dict[str, Any]] = json.load(f)

    print(f"Source exercises loaded: {len(source_data)}")

    converted = [convert_exercise(ex) for ex in source_data]

    seen_names: set[str] = set()
    deduplicated: list[dict[str, Any]] = []
    for ex in converted:
        norm = ex["name"].strip().lower()
        if norm not in seen_names:
            seen_names.add(norm)
            deduplicated.append(ex)

    duplicate_count = len(converted) - len(deduplicated)
    if duplicate_count > 0:
        print(f"Duplicates removed: {duplicate_count}")

    categories = collect_unique_sorted(deduplicated, "category")
    equipment = collect_unique_sorted(deduplicated, "equipment")

    output = {
        "categories": categories,
        "equipment": equipment,
        "exercises": deduplicated,
    }

    for out_path in (ASSET_OUTPUT, BACKEND_OUTPUT):
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(output, f, indent=2, ensure_ascii=False)
        print(f"Written: {out_path}  ({len(deduplicated)} exercises)")

    _print_stats(deduplicated, categories, equipment)


def _print_stats(exercises: list[dict], categories: list[str], equipment: list[str]) -> None:
    print(f"\n--- Conversion Stats ---")
    print(f"Total exercises: {len(exercises)}")
    print(f"Categories ({len(categories)}): {categories}")
    print(f"Equipment  ({len(equipment)}): {equipment}")

    levels = collect_unique_sorted(exercises, "level")
    forces = collect_unique_sorted(exercises, "force")
    mechanics = collect_unique_sorted(exercises, "mechanic")
    muscles = collect_unique_sorted(exercises, "primary_muscles")

    print(f"Levels     ({len(levels)}): {levels}")
    print(f"Forces     ({len(forces)}): {forces}")
    print(f"Mechanics  ({len(mechanics)}): {mechanics}")
    print(f"Muscles    ({len(muscles)}): {muscles}")

    null_force = sum(1 for e in exercises if not e["force"])
    null_mechanic = sum(1 for e in exercises if not e["mechanic"])
    print(f"\nNull force:    {null_force}/{len(exercises)}")
    print(f"Null mechanic: {null_mechanic}/{len(exercises)}")


if __name__ == "__main__":
    main()
