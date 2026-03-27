"""사용자 네임스페이스 안정성."""

from __future__ import annotations

import os
import unittest

from services.user_namespace import user_vector_namespace


class TestUserNamespace(unittest.TestCase):
    def tearDown(self) -> None:
        os.environ.pop("AUTH_NAMESPACE_SALT", None)
        os.environ.pop("AUTH_JWT_SECRET", None)

    def test_stable_for_same_subject(self) -> None:
        os.environ["AUTH_JWT_SECRET"] = "salt-fixed"
        a = user_vector_namespace("anon_abc")
        b = user_vector_namespace("anon_abc")
        self.assertEqual(a, b)
        self.assertTrue(a.startswith("u_"))

    def test_different_subjects_differ(self) -> None:
        os.environ["AUTH_JWT_SECRET"] = "salt-fixed"
        a = user_vector_namespace("anon_a")
        b = user_vector_namespace("anon_b")
        self.assertNotEqual(a, b)


if __name__ == "__main__":
    unittest.main()
