"""resolve_request_subject 동작."""

from __future__ import annotations

import os
import unittest

from fastapi import FastAPI, Request
from fastapi.testclient import TestClient

from routers.auth_deps import resolve_request_subject
from services.auth_jwt import issue_anonymous_token


def _make_app() -> FastAPI:
    app = FastAPI()

    @app.get("/who")
    def who(request: Request, user_id: str = "") -> dict[str, str]:
        sub = resolve_request_subject(request, user_id)
        return {"subject": sub}

    return app


class TestResolveSubject(unittest.TestCase):
    def tearDown(self) -> None:
        os.environ.pop("AUTH_JWT_SECRET", None)

    def test_legacy_body_only(self) -> None:
        app = _make_app()
        with TestClient(app) as c:
            r = c.get("/who", params={"user_id": "legacy_u1"})
            self.assertEqual(r.status_code, 200)
            self.assertEqual(r.json()["subject"], "legacy_u1")

    def test_legacy_missing_user_id_401(self) -> None:
        app = _make_app()
        with TestClient(app) as c:
            r = c.get("/who", params={"user_id": ""})
            self.assertEqual(r.status_code, 401)

    def test_jwt_bearer(self) -> None:
        os.environ["AUTH_JWT_SECRET"] = "tsec"
        token, sub = issue_anonymous_token("tsec")
        app = _make_app()
        with TestClient(app) as c:
            r = c.get(
                "/who",
                params={"user_id": ""},
                headers={"Authorization": f"Bearer {token}"},
            )
            self.assertEqual(r.status_code, 200)
            self.assertEqual(r.json()["subject"], sub)

    def test_jwt_mismatch_body_403(self) -> None:
        os.environ["AUTH_JWT_SECRET"] = "tsec2"
        token, _ = issue_anonymous_token("tsec2")
        app = _make_app()
        with TestClient(app) as c:
            r = c.get(
                "/who",
                params={"user_id": "other"},
                headers={"Authorization": f"Bearer {token}"},
            )
            self.assertEqual(r.status_code, 403)


if __name__ == "__main__":
    unittest.main()
