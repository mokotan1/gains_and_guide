"""SFT 검증기 단위 테스트."""

from __future__ import annotations

import json
import unittest

from finetune.validate_sft_samples import (
    validate_dataset,
    validate_gpt_content,
    validate_sharegpt_row,
)


class TestValidateSftSamples(unittest.TestCase):
    def test_coach_json_ok(self) -> None:
        sys = "[GainsCoach /chat]\nrules"
        gpt = json.dumps(
            {
                "response": "안녕 주인님",
                "routine": None,
                "progression": [{"name": "Barbell Squat", "increase": 2.5}],
            },
            ensure_ascii=False,
        )
        self.assertEqual(validate_gpt_content(sys, gpt), [])

    def test_recommend_json_ok(self) -> None:
        sys = "[GainsCoach /recommend]\nrules"
        gpt = json.dumps(
            {
                "routine": {
                    "title": "T",
                    "rationale": "R",
                    "exercises": [
                        {"name": "Barbell Squat", "sets": 3, "reps": 5, "weight": 0.0}
                    ],
                }
            },
            ensure_ascii=False,
        )
        self.assertEqual(validate_gpt_content(sys, gpt), [])

    def test_corpus_plain_allowed(self) -> None:
        sys = "한 문장으로만 답합니다. JSON이 아닌 평문"
        self.assertEqual(validate_gpt_content(sys, "이것은 한 문장 요약입니다."), [])

    def test_dataset_build_passes(self) -> None:
        from finetune.build_sft_dataset import build_dataset

        rows = build_dataset(seed=0)
        ok, fail, msgs = validate_dataset(rows)
        self.assertEqual(fail, 0, msg="; ".join(msgs))
        self.assertEqual(ok, len(rows))

    def test_sharegpt_bad_roles(self) -> None:
        row = {"conversations": [{"from": "human", "value": "x"}]}
        self.assertTrue(validate_sharegpt_row(row, index=0))


if __name__ == "__main__":
    unittest.main()
