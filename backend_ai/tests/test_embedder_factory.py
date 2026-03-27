"""embedder_factory 환경 분기."""

from __future__ import annotations

import os
import unittest


class TestEmbedderFactoryEnv(unittest.TestCase):
    def tearDown(self) -> None:
        for k in (
            "EMBEDDING_BACKEND",
            "OPENAI_API_KEY",
            "HUGGINGFACE_API_TOKEN",
        ):
            os.environ.pop(k, None)

    def test_openai_ready_requires_key(self) -> None:
        from services.embedder_factory import embedding_credentials_ready

        os.environ.pop("OPENAI_API_KEY", None)
        os.environ["EMBEDDING_BACKEND"] = "openai"
        self.assertFalse(embedding_credentials_ready())
        os.environ["OPENAI_API_KEY"] = "sk-test"
        self.assertTrue(embedding_credentials_ready())

    def test_hf_ready_requires_token(self) -> None:
        from services.embedder_factory import embedding_credentials_ready

        os.environ["EMBEDDING_BACKEND"] = "huggingface"
        os.environ.pop("HUGGINGFACE_API_TOKEN", None)
        self.assertFalse(embedding_credentials_ready())
        os.environ["HUGGINGFACE_API_TOKEN"] = "hf_test"
        self.assertTrue(embedding_credentials_ready())


if __name__ == "__main__":
    unittest.main()
