"""카탈로그 캐노니컬화 및 한글 표시."""

import unittest

import main as main_module


class TestCanonicalizeExerciseName(unittest.TestCase):
    def test_lunges_alias(self) -> None:
        self.assertEqual(
            main_module._canonicalize_exercise_name("Lunges"),
            "Dumbbell Lunges",
        )

    def test_bodyweight_deadlift_alias(self) -> None:
        self.assertEqual(
            main_module._canonicalize_exercise_name("Bodyweight Deadlift"),
            "Hyperextensions (Back Extensions)",
        )

    def test_fuzzy_tricep_extension(self) -> None:
        c = main_module._canonicalize_exercise_name("Dumbbell Tricep Extension")
        self.assertIn("Dumbbell Tricep Extension", c)
        self.assertIn("Tricep", c)

    def test_barbell_squat_exact(self) -> None:
        self.assertEqual(
            main_module._canonicalize_exercise_name("Barbell Squat"),
            "Barbell Squat",
        )


class TestLocalizeRoutineAllKorean(unittest.TestCase):
    def test_mixed_ai_names_become_korean(self) -> None:
        routine = {
            "title": "t",
            "exercises": [
                {"name": "Lunges", "sets": 3, "reps": 12, "weight": 0},
                {"name": "Bodyweight Deadlift", "sets": 3, "reps": 12, "weight": 0},
                {"name": "Dumbbell Tricep Extension", "sets": 3, "reps": 12, "weight": 5},
            ],
        }
        out = main_module._localize_routine_exercise_names(routine)
        assert out is not None
        names = [e["name"] for e in out["exercises"]]
        for n in names:
            self.assertTrue(
                any("\uac00" <= ch <= "\ud7a3" for ch in n),
                f"expected Korean in name: {n!r}",
            )


if __name__ == "__main__":
    unittest.main()
