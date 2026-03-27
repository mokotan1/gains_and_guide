"""유저 메모리 청크 검증."""

from __future__ import annotations

import unittest

from services.user_memory_service import validate_chunks


class TestValidateChunks(unittest.TestCase):
    def test_valid_minimal(self) -> None:
        rows = [{"text": "hello memory"}]
        out = validate_chunks(rows)
        self.assertEqual(len(out), 1)
        self.assertEqual(out[0].text, "hello memory")

    def test_rejects_empty_text(self) -> None:
        with self.assertRaises(ValueError):
            validate_chunks([{"text": "  "}])

    def test_rejects_too_many_chunks(self) -> None:
        rows = [{"text": f"x{i}"} for i in range(50)]
        with self.assertRaises(ValueError):
            validate_chunks(rows)


if __name__ == "__main__":
    unittest.main()
