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


if __name__ == "__main__":
    unittest.main()
