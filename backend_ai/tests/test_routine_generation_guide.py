"""routine_generation_guide.json 구조 및 파싱 검증."""

import json
import os
import unittest


class TestRoutineGenerationGuide(unittest.TestCase):
    def _guide_path(self) -> str:
        root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        return os.path.join(root, "routine_generation_guide.json")

    def test_file_exists_and_valid_json(self) -> None:
        path = self._guide_path()
        self.assertTrue(os.path.isfile(path), f"missing {path}")
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        self.assertIn("meta", data)
        self.assertIn("version", data["meta"])
        self.assertIn("design_principles", data)
        self.assertIn("few_shot_examples", data)
        self.assertEqual(len(data["few_shot_examples"]), 3)

    def test_examples_have_profile_and_content(self) -> None:
        with open(self._guide_path(), encoding="utf-8") as f:
            data = json.load(f)
        for ex in data["few_shot_examples"]:
            self.assertIn("user_profile", ex)
            self.assertIn("목적", ex["user_profile"])
            self.assertTrue(
                "sessions" in ex or "circuit" in ex,
                "each example should define sessions or circuit",
            )


if __name__ == "__main__":
    unittest.main()
