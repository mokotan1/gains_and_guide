"""Groq 모델·max_tokens 환경 설정."""

from __future__ import annotations

import os
import unittest

from services.groq_settings import groq_max_completion_tokens, groq_model_name


class TestGroqSettings(unittest.TestCase):
    def test_model_default(self) -> None:
        old = os.environ.pop("GROQ_MODEL", None)
        try:
            self.assertEqual(groq_model_name(), "llama-3.1-8b-instant")
        finally:
            if old is not None:
                os.environ["GROQ_MODEL"] = old

    def test_max_completion_invalid_env_falls_back(self) -> None:
        old = os.environ.get("GROQ_MAX_COMPLETION_TOKENS")
        try:
            os.environ["GROQ_MAX_COMPLETION_TOKENS"] = "oops"
            self.assertEqual(groq_max_completion_tokens(), 1024)
        finally:
            if old is None:
                os.environ.pop("GROQ_MAX_COMPLETION_TOKENS", None)
            else:
                os.environ["GROQ_MAX_COMPLETION_TOKENS"] = old


if __name__ == "__main__":
    unittest.main()
