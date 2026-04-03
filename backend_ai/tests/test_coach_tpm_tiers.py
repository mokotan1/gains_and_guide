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


def _fake_payload_413_error() -> APIStatusError:
    """게이트/페이로드 등 rate_limit 코드 없이 413만 오는 경우."""
    return APIStatusError(
        "payload too large",
        response=MagicMock(status_code=413),
        body={"error": {"message": "Request entity too large"}},
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
            cardio_analysis_prompt="Cardio expert.",
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

    def test_legacy_plain_413_also_retries_tiers(self) -> None:
        client = MagicMock()
        client.chat.completions.create.side_effect = [
            _fake_payload_413_error(),
            _fake_payload_413_error(),
            _fake_payload_413_error(),
        ]
        body = ChatRequest(message="hi", context="", user_id="")
        assets = prompts.PromptAssets(
            system_prompt="You are a coach.",
            routine_system_prompt="Routine coach.",
            routine_guide_text="",
            cardio_analysis_prompt="Cardio expert.",
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

    def test_shrink_retry_true_for_plain_413(self) -> None:
        self.assertTrue(
            coach_mod._should_shrink_prompt_and_retry(_fake_payload_413_error())
        )


if __name__ == "__main__":
    unittest.main()
