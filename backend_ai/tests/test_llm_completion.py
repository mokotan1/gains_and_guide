"""LLM 클라이언트 빌더 환경 분기."""

from __future__ import annotations

import os
import unittest

from services import llm_completion as llm_mod


class TestLlmCompletion(unittest.TestCase):
    def test_default_groq_when_key_set(self) -> None:
        old_g = os.environ.get("GROQ_API_KEY")
        old_p = os.environ.get("LLM_CHAT_PROVIDER")
        old_b = os.environ.get("OPENAI_COMPAT_BASE_URL")
        try:
            os.environ.pop("LLM_CHAT_PROVIDER", None)
            os.environ.pop("OPENAI_COMPAT_BASE_URL", None)
            os.environ["GROQ_API_KEY"] = "test-key-for-build-only"
            client, prov = llm_mod.build_chat_completion_client()
            self.assertEqual(prov, "groq")
            self.assertIsNotNone(client)
        finally:
            if old_g is None:
                os.environ.pop("GROQ_API_KEY", None)
            else:
                os.environ["GROQ_API_KEY"] = old_g
            if old_p is not None:
                os.environ["LLM_CHAT_PROVIDER"] = old_p
            if old_b is not None:
                os.environ["OPENAI_COMPAT_BASE_URL"] = old_b

    def test_openai_compat_when_configured(self) -> None:
        old_g = os.environ.get("GROQ_API_KEY")
        old_p = os.environ.get("LLM_CHAT_PROVIDER")
        old_b = os.environ.get("OPENAI_COMPAT_BASE_URL")
        try:
            os.environ["LLM_CHAT_PROVIDER"] = "openai_compat"
            os.environ["OPENAI_COMPAT_BASE_URL"] = "http://127.0.0.1:11434/v1"
            os.environ.pop("GROQ_API_KEY", None)
            client, prov = llm_mod.build_chat_completion_client()
            self.assertEqual(prov, "openai_compat")
            self.assertIsNotNone(client)
        finally:
            if old_g is not None:
                os.environ["GROQ_API_KEY"] = old_g
            else:
                os.environ.pop("GROQ_API_KEY", None)
            if old_p is None:
                os.environ.pop("LLM_CHAT_PROVIDER", None)
            else:
                os.environ["LLM_CHAT_PROVIDER"] = old_p
            if old_b is None:
                os.environ.pop("OPENAI_COMPAT_BASE_URL", None)
            else:
                os.environ["OPENAI_COMPAT_BASE_URL"] = old_b


if __name__ == "__main__":
    unittest.main()
