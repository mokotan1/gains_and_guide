"""응답용 루틴 운동명 한글 치환."""

import unittest

import main as main_module


class TestLocalizeRoutineExerciseNames(unittest.TestCase):
    def test_translates_known_english_name(self) -> None:
        routine = {
            "title": "t",
            "exercises": [
                {"name": "Barbell Squat", "sets": 3, "reps": 5, "weight": 60.0}
            ],
        }
        out = main_module._localize_routine_exercise_names(routine)
        assert out is not None
        self.assertEqual(out["exercises"][0]["name"], "바벨 스쿼트")

    def test_unknown_name_unchanged(self) -> None:
        routine = {"title": "t", "exercises": [{"name": "Unknown Lift XYZ"}]}
        out = main_module._localize_routine_exercise_names(routine)
        assert out is not None
        self.assertEqual(out["exercises"][0]["name"], "Unknown Lift XYZ")

    def test_none_routine(self) -> None:
        self.assertIsNone(main_module._localize_routine_exercise_names(None))


if __name__ == "__main__":
    unittest.main()
