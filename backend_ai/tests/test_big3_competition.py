"""3대 경쟁 도메인 순수 로직 테스트."""

from __future__ import annotations

import unittest

from services.big3_competition_service import (
    StrengthCompetitionError,
    bests_to_records,
    compute_total_1rm,
    default_display_alias,
    normalize_display_alias,
    validate_submission_input,
)

Big3CompetitionError = StrengthCompetitionError


class TestDisplayAlias(unittest.TestCase):
    def test_default_alias_is_deterministic(self) -> None:
        a = default_display_alias("anon_abc")
        b = default_display_alias("anon_abc")
        self.assertEqual(a, b)
        self.assertTrue(a.startswith("리프터-"))

    def test_normalize_valid(self) -> None:
        self.assertEqual(normalize_display_alias("  스쿼트킹 "), "스쿼트킹")

    def test_normalize_rejects_short(self) -> None:
        with self.assertRaises(Big3CompetitionError):
            normalize_display_alias("a")

    def test_normalize_rejects_special_chars(self) -> None:
        with self.assertRaises(Big3CompetitionError):
            normalize_display_alias("bad alias!")


class TestValidateSubmission(unittest.TestCase):
    def test_valid_squat(self) -> None:
        lift, w, r, est = validate_submission_input("squat", 100.0, 5)
        self.assertEqual(lift, "squat")
        self.assertEqual(w, 100.0)
        self.assertEqual(r, 5)
        self.assertAlmostEqual(est, 100.0 * (1 + 5 / 30.0), places=2)

    def test_rejects_unknown_lift(self) -> None:
        with self.assertRaises(Big3CompetitionError):
            validate_submission_input("ohp", 60, 5)

    def test_rejects_high_reps(self) -> None:
        with self.assertRaises(Big3CompetitionError):
            validate_submission_input("bench", 80, 15)

    def test_rejects_over_cap(self) -> None:
        with self.assertRaises(Big3CompetitionError):
            validate_submission_input("bench", 350, 1)


class TestBestsToRecords(unittest.TestCase):
    def test_maps_lift_keys(self) -> None:
        r = bests_to_records({"squat": 100.0, "bench": 80.0, "deadlift": 120.0})
        self.assertEqual(r["total_1rm_kg"], 300.0)
        self.assertEqual(r["squat_1rm_kg"], 100.0)


class TestComputeTotal(unittest.TestCase):
    def test_all_three_required(self) -> None:
        self.assertIsNone(
            compute_total_1rm({"squat": 100.0, "bench": 80.0, "deadlift": None})
        )

    def test_sums_bests(self) -> None:
        total = compute_total_1rm(
            {"squat": 100.0, "bench": 80.0, "deadlift": 120.0}
        )
        self.assertEqual(total, 300.0)


if __name__ == "__main__":
    unittest.main()
