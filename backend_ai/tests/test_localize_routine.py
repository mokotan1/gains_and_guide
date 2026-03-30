"""응답용 루틴 운동명 한글 치환."""

import os
import unittest

import catalog


def _backend_ai_root() -> str:
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


class TestLocalizeRoutineExerciseNames(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        catalog.load_catalog(_backend_ai_root())

    def test_translates_known_english_name(self) -> None:
        routine = {
            "title": "t",
            "exercises": [
                {"name": "Barbell Squat", "sets": 3, "reps": 5, "weight": 60.0}
            ],
        }
        out = catalog.localize_routine_exercise_names(routine)
        assert out is not None
        self.assertEqual(out["exercises"][0]["name"], "백 스쿼트")

    def test_unknown_name_unchanged(self) -> None:
        routine = {"title": "t", "exercises": [{"name": "Unknown Lift XYZ"}]}
        out = catalog.localize_routine_exercise_names(routine)
        assert out is not None
        self.assertEqual(out["exercises"][0]["name"], "Unknown Lift XYZ")

    def test_none_routine(self) -> None:
        self.assertIsNone(catalog.localize_routine_exercise_names(None))


if __name__ == "__main__":
    unittest.main()
