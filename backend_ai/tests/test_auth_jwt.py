"""JWT 익명 토큰 발급·검증."""

from __future__ import annotations

import unittest

from services.auth_jwt import issue_anonymous_token, verify_bearer_token


class TestAuthJwt(unittest.TestCase):
    def test_issue_and_verify_roundtrip(self) -> None:
        secret = "unit-test-secret-key"
        token, sub = issue_anonymous_token(secret)
        self.assertTrue(sub.startswith("anon_"))
        got = verify_bearer_token(token, secret)
        self.assertEqual(got, sub)

    def test_wrong_secret_fails(self) -> None:
        token, _ = issue_anonymous_token("secret-a")
        with self.assertRaises(Exception):
            verify_bearer_token(token, "secret-b")


if __name__ == "__main__":
    unittest.main()
