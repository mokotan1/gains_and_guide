"""도구 순수 로직 (Epley·경계값)."""

from __future__ import annotations

import json
import os
import unittest

import catalog
from services.tools import (
    build_progression_table_json,
    calculate_1rm,
    epley_one_rm_kg,
    match_exercise_catalog_name,
)


def _backend_ai_root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


class TestEpley(unittest.TestCase):
    def test_matches_dart_formula(self) -> None:
        # weight * (1 + reps/30)
        self.assertAlmostEqual(epley_one_rm_kg(100.0, 5), 100.0 * (1 + 5 / 30.0))

    def test_invalid_weight(self) -> None:
        with self.assertRaises(ValueError):
            epley_one_rm_kg(0, 5)

    def test_invalid_reps(self) -> None:
        with self.assertRaises(ValueError):
            epley_one_rm_kg(60, 0)


class TestLangchainToolsInvoke(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        catalog.load_catalog(_backend_ai_root())

    def test_calculate_1rm_tool(self) -> None:
        out = calculate_1rm.invoke({"weight_kg": 60.0, "reps": 5})
        data = json.loads(out)
        self.assertIn("estimated_1rm_kg", data)
        self.assertGreater(data["estimated_1rm_kg"], 60)

    def test_match_exercise_name_tool(self) -> None:
        out = match_exercise_catalog_name.invoke({"raw_name": "Barbell Squat"})
        data = json.loads(out)
        self.assertEqual(data["canonical_name"], "Barbell Squat")

    def test_progression_tool_weeks_bounds(self) -> None:
        bad = build_progression_table_json.invoke(
            {
                "exercise_name": "X",
                "weeks": 20,
                "start_weight_kg": 40,
                "sets": 3,
                "reps": 8,
                "weekly_increment_kg": 2.5,
            }
        )
        self.assertIn("error", json.loads(bad))


if __name__ == "__main__":
    unittest.main()
