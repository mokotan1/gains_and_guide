"""정산 분할용 coach_focus: 루틴 가이드·카탈로그 주입 완화."""

from __future__ import annotations

import unittest
from unittest.mock import patch

import prompts
from routers import coach as coach_mod
from routers.coach import ChatRequest


class TestCoachFocus(unittest.TestCase):
    def test_weights_minimal_skips_routine_guide_in_tier0(self) -> None:
        calls: list[str] = []

        def spy_append_routine(s: str, guide: str) -> str:
            calls.append(guide)
            return s + "[RG]"

        assets = prompts.PromptAssets(
            system_prompt="SYS",
            routine_system_prompt="R",
            routine_guide_text="HUGE_JSON",
            cardio_analysis_prompt="CARDIO",
        )
        body = ChatRequest(
            message="m",
            context="ctx",
            user_id="",
            coach_focus="weights_minimal",
        )
        with patch.object(coach_mod.app_deps, "assets", assets):
            with patch.object(coach_mod.app_deps, "rag", None):
                with patch.object(
                    coach_mod.prompts,
                    "append_routine_guide",
                    side_effect=spy_append_routine,
                ):
                    with patch.object(coach_mod.catalog, "exercise_catalog_text", "CAT"):
                        sp, _ = coach_mod._chat_prompt_tier(body, "subj", 0)
        self.assertEqual(calls, [])
        self.assertNotIn("HUGE_JSON", sp)
        self.assertIn("CAT", sp)

    def test_cardio_only_skips_catalog_tier0(self) -> None:
        calls: list[str] = []

        def spy_append_cat(s: str, cat: str) -> str:
            calls.append(cat)
            return s + "[CAT]"

        assets = prompts.PromptAssets(
            system_prompt="SYS",
            routine_system_prompt="R",
            routine_guide_text="G",
            cardio_analysis_prompt="CARDIO",
        )
        body = ChatRequest(
            message="m",
            context="[유산소 운동 데이터]\nline",
            user_id="",
            coach_focus="cardio_only",
        )
        with patch.object(coach_mod.app_deps, "assets", assets):
            with patch.object(coach_mod.app_deps, "rag", None):
                with patch.object(
                    coach_mod.prompts,
                    "append_catalog",
                    side_effect=spy_append_cat,
                ):
                    with patch.object(coach_mod.prompts, "append_routine_guide", lambda s, g: s):
                        sp, _ = coach_mod._chat_prompt_tier(body, "subj", 0)
        self.assertEqual(calls, [])
        self.assertIn("CARDIO", sp)

    def test_legacy_empty_coach_focus_keeps_routine_guide_tier0(self) -> None:
        calls: list[str] = []

        def spy_append_routine(s: str, guide: str) -> str:
            calls.append(guide)
            return s + "[RG]"

        assets = prompts.PromptAssets(
            system_prompt="SYS",
            routine_system_prompt="R",
            routine_guide_text="G",
            cardio_analysis_prompt="",
        )
        body = ChatRequest(message="m", context="ctx", user_id="", coach_focus="")
        with patch.object(coach_mod.app_deps, "assets", assets):
            with patch.object(coach_mod.app_deps, "rag", None):
                with patch.object(
                    coach_mod.prompts,
                    "append_routine_guide",
                    side_effect=spy_append_routine,
                ):
                    with patch.object(coach_mod.prompts, "append_catalog", lambda s, c: s + c):
                        coach_mod._chat_prompt_tier(body, "subj", 0)
        self.assertEqual(calls, ["G"])


if __name__ == "__main__":
    unittest.main()
