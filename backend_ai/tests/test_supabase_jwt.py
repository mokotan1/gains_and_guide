"""Supabase JWKS 설정 플래그 (네트워크 없음)."""

from __future__ import annotations

import os
import unittest


class TestSupabaseJwtConfig(unittest.TestCase):
    def tearDown(self) -> None:
        for k in ("SUPABASE_JWKS_URL", "SUPABASE_JWT_ISS", "SUPABASE_JWT_AUD"):
            os.environ.pop(k, None)

    def test_configured_only_when_both_set(self) -> None:
        from services.supabase_jwt import supabase_jwks_configured

        self.assertFalse(supabase_jwks_configured())
        os.environ["SUPABASE_JWKS_URL"] = "https://x.supabase.co/auth/v1/.well-known/jwks.json"
        self.assertFalse(supabase_jwks_configured())
        os.environ["SUPABASE_JWT_ISS"] = "https://x.supabase.co/auth/v1"
        self.assertTrue(supabase_jwks_configured())


if __name__ == "__main__":
    unittest.main()
