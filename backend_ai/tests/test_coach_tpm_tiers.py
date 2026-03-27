"""레거시 챗: 3단계 TPM 재시도 후 429."""

from __future__ import annotations

import unittest
from unittest.mock import MagicMock, patch

from fastapi import HTTPException
from groq import APIStatusError

import prompts
from routers import coach as coach_mod
from routers.coach import ChatRequest


def _fake_tpm_error() -> APIStatusError:
    return APIStatusError(
        "tpm",
        response=MagicMock(status_code=413),
        body={
            "error": {
                "code": "rate_limit_exceeded",
                "message": "TPM",
            }
        },
    )


class TestCoachTpmTiers(unittest.TestCase):
    def test_legacy_raises_429_after_three_tpm_errors(self) -> None:
        client = MagicMock()
        client.chat.completions.create.side_effect = [
            _fake_tpm_error(),
            _fake_tpm_error(),
            _fake_tpm_error(),
        ]
        body = ChatRequest(message="hi", context="", user_id="")
        assets = prompts.PromptAssets(
            system_prompt="You are a coach.",
            routine_system_prompt="Routine coach.",
            routine_guide_text="",
        )

        with patch.object(coach_mod.app_deps, "assets", assets):
            with patch.object(coach_mod.app_deps, "rag", None):
                with self.assertRaises(HTTPException) as ctx:
                    coach_mod._invoke_legacy_chat_resolving_tpm(
                        client,
                        lambda t: coach_mod._chat_prompt_tier(body, "subj", t),
                    )
                self.assertEqual(ctx.exception.status_code, 429)
                self.assertEqual(client.chat.completions.create.call_count, 3)


if __name__ == "__main__":
    unittest.main()
