"""SFT 데이터셋 빌더 스모크 테스트."""

from __future__ import annotations

import json
import unittest

from finetune.build_sft_dataset import build_dataset


class TestBuildSftDataset(unittest.TestCase):
    def test_build_non_empty_sharegpt_rows(self) -> None:
        rows = build_dataset(seed=0)
        self.assertGreater(len(rows), 5)
        first = rows[0]
        self.assertIn("conversations", first)
        conv = first["conversations"]
        self.assertEqual(len(conv), 3)
        roles = {c["from"] for c in conv}
        self.assertEqual(roles, {"system", "human", "gpt"})
        # assistant must be valid JSON for coach/recommend samples (skip corpus summary rows)
        gpt_val = conv[2]["value"]
        if gpt_val.startswith("{"):
            data = json.loads(gpt_val)
            self.assertTrue(
                "response" in data or "routine" in data,
                msg="expected coach or recommend JSON keys",
            )


if __name__ == "__main__":
    unittest.main()
