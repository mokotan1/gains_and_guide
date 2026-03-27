from __future__ import annotations

import logging
import os

from dotenv import load_dotenv
from fastapi import FastAPI
from groq import Groq

import catalog
import prompts
from graphs.coach_graph import build_coach_agent
from routers.coach import router as coach_router
from services.rag import RagService
from state import app_deps

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

catalog.load_catalog(BASE_DIR)
app_deps.assets = prompts.load_prompt_assets(BASE_DIR)

_chunks_path = os.path.join(BASE_DIR, "corpus", "chunks.jsonl")
app_deps.rag = RagService(_chunks_path)

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
if GROQ_API_KEY:
    app_deps.groq_api_key = GROQ_API_KEY
    app_deps.groq_client = Groq(api_key=GROQ_API_KEY)
    logger.info("✅ Groq API Key가 로드되었습니다. (Llama 3 활성화 완료)")
    try:
        app_deps.coach_agent = build_coach_agent(GROQ_API_KEY)
        logger.info("✅ LangGraph 코치 에이전트(도구 호출) 준비 완료")
    except Exception as e:
        logger.error("❌ 코치 에이전트 초기화 실패 — USE_LEGACY_CHAT 또는 키 확인: %s", e)
        app_deps.coach_agent = None
else:
    logger.error("❌ Groq API Key를 찾을 수 없습니다!")
    app_deps.groq_client = None
    app_deps.coach_agent = None

app = FastAPI()
app.include_router(coach_router)


@app.get("/")
def read_root() -> dict:
    return {
        "status": "online",
        "message": "Gains & Guide AI Coach Server is Running!",
        "features": {
            "rag_corpus": bool(app_deps.rag and app_deps.rag.chunk_count > 0),
            "agent": app_deps.coach_agent is not None,
        },
    }


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
