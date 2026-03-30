"""코치 응답 Pydantic 스키마."""

from __future__ import annotations

import unittest

from pydantic import ValidationError

from services.coach_response_schema import CoachChatResponse, coerce_raw_coach_dict


class TestCoachChatResponse(unittest.TestCase):
    def test_message_alias(self) -> None:
        v = coerce_raw_coach_dict({"message": "안녕", "routine": None})
        self.assertEqual(v.response, "안녕")
        self.assertIsNone(v.routine)

    def test_routine_must_be_object(self) -> None:
        with self.assertRaises(ValidationError):
            CoachChatResponse.model_validate({"response": "x", "routine": []})

    def test_response_non_empty(self) -> None:
        with self.assertRaises(ValidationError):
            CoachChatResponse.model_validate({"response": "   ", "routine": None})

    def test_progression_null(self) -> None:
        v = coerce_raw_coach_dict(
            {"response": "ok", "routine": None, "progression": None}
        )
        self.assertIsNone(v.progression)

    def test_progression_valid_list(self) -> None:
        v = coerce_raw_coach_dict(
            {
                "response": "ok",
                "routine": None,
                "progression": [{"name": "Squat", "increase": 2.5}],
            }
        )
        self.assertIsNotNone(v.progression)
        self.assertEqual(v.progression[0].name, "Squat")
        self.assertEqual(v.progression[0].increase, 2.5)

    def test_progression_int_increase_coerced(self) -> None:
        v = coerce_raw_coach_dict(
            {
                "response": "ok",
                "routine": None,
                "progression": [{"name": "Bench", "increase": 2}],
            }
        )
        self.assertIsNotNone(v.progression)
        self.assertEqual(v.progression[0].increase, 2.0)

    def test_progression_dict_not_list_raises(self) -> None:
        with self.assertRaises(ValidationError):
            coerce_raw_coach_dict(
                {"response": "ok", "routine": None, "progression": {"name": "x"}}
            )

    def test_progression_element_not_object_raises(self) -> None:
        with self.assertRaises(ValidationError):
            coerce_raw_coach_dict(
                {"response": "ok", "routine": None, "progression": ["Squat"]}
            )

    def test_progression_increase_not_number_raises(self) -> None:
        with self.assertRaises(ValidationError):
            coerce_raw_coach_dict(
                {
                    "response": "ok",
                    "routine": None,
                    "progression": [{"name": "Squat", "increase": "2.5"}],
                }
            )

    def test_progression_bool_increase_rejected(self) -> None:
        with self.assertRaises(ValidationError):
            coerce_raw_coach_dict(
                {
                    "response": "ok",
                    "routine": None,
                    "progression": [{"name": "Squat", "increase": True}],
                }
            )

    def test_progression_empty_name_raises(self) -> None:
        with self.assertRaises(ValidationError):
            coerce_raw_coach_dict(
                {
                    "response": "ok",
                    "routine": None,
                    "progression": [{"name": "  ", "increase": 1}],
                }
            )


if __name__ == "__main__":
    unittest.main()
