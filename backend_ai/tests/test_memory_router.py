"""유저 메모리 라우터 (목 서비스)."""

from __future__ import annotations

import os
import unittest
from unittest.mock import MagicMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from rate_limits import limiter
from routers import memory as memory_mod
from services.auth_jwt import issue_anonymous_token


class TestMemoryRouter(unittest.TestCase):
    def setUp(self) -> None:
        self._prev_secret = os.environ.get("AUTH_JWT_SECRET")
        self._prev_mem = os.environ.get("MEMORY_API_ENABLED")
        os.environ["AUTH_JWT_SECRET"] = "mem-router-test-secret"
        os.environ["MEMORY_API_ENABLED"] = "1"
        memory_mod._memory_service_loaded = False
        memory_mod._memory_service = None

    def tearDown(self) -> None:
        memory_mod._memory_service_loaded = False
        memory_mod._memory_service = None
        if self._prev_secret is None:
            os.environ.pop("AUTH_JWT_SECRET", None)
        else:
            os.environ["AUTH_JWT_SECRET"] = self._prev_secret
        if self._prev_mem is None:
            os.environ.pop("MEMORY_API_ENABLED", None)
        else:
            os.environ["MEMORY_API_ENABLED"] = self._prev_mem

    def _app(self) -> TestClient:
        app = FastAPI()
        app.state.limiter = limiter  # 다른 라우트·미들웨어와 일관성
        app.include_router(memory_mod.router)
        return TestClient(app)

    @patch.object(memory_mod, "build_user_memory_service")
    def test_post_chunks_requires_auth(self, mock_build: MagicMock) -> None:
        mock_build.return_value = MagicMock()
        mock_build.return_value.upsert_for_subject.return_value = 1
        with self._app() as c:
            r = c.post("/memory/chunks", json={"chunks": [{"text": "hi"}]})
            self.assertEqual(r.status_code, 401)

    @patch.object(memory_mod, "build_user_memory_service")
    def test_post_chunks_ok(self, mock_build: MagicMock) -> None:
        svc = MagicMock()
        svc.upsert_for_subject.return_value = 1
        mock_build.return_value = svc
        token, _ = issue_anonymous_token("mem-router-test-secret")
        with self._app() as c:
            r = c.post(
                "/memory/chunks",
                json={"chunks": [{"text": "hello chunk"}]},
                headers={"Authorization": f"Bearer {token}"},
            )
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()["stored"], 1)
        svc.upsert_for_subject.assert_called_once()

    @patch.object(memory_mod, "build_user_memory_service")
    def test_delete_ok(self, mock_build: MagicMock) -> None:
        svc = MagicMock()
        mock_build.return_value = svc
        token, _ = issue_anonymous_token("mem-router-test-secret")
        with self._app() as c:
            r = c.delete(
                "/memory",
                headers={"Authorization": f"Bearer {token}"},
            )
        self.assertEqual(r.status_code, 200)
        svc.delete_all_for_subject.assert_called_once()


if __name__ == "__main__":
    unittest.main()
