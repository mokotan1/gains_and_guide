from __future__ import annotations

import logging
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI, Request
from groq import Groq
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

import catalog
import prompts
from graphs.coach_graph import build_coach_agent
from rate_limits import limiter
from routers.auth import router as auth_router
from routers.coach import router as coach_router
from routers.memory import router as memory_router
from services.rag import create_rag_service
from state import app_deps

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

load_dotenv()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

catalog.load_catalog(BASE_DIR)
app_deps.assets = prompts.load_prompt_assets(BASE_DIR)

app_deps.rag = create_rag_service(BASE_DIR)

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


@asynccontextmanager
async def lifespan(app: FastAPI):
    from services.database import close_db_pool, init_db_pool

    await init_db_pool(app)
    try:
        yield
    finally:
        await close_db_pool(app)


app = FastAPI(lifespan=lifespan)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.include_router(coach_router)
app.include_router(auth_router)
app.include_router(memory_router)


@app.get("/")
def read_root(request: Request) -> dict:
    from services.database import get_pool

    pool = get_pool(request.app)
    return {
        "status": "online",
        "message": "Gains & Guide AI Coach Server is Running!",
        "features": {
            "rag_corpus": bool(app_deps.rag and app_deps.rag.chunk_count > 0),
            "rag_mode": getattr(app_deps.rag, "mode", "token"),
            "agent": app_deps.coach_agent is not None,
            "auth_jwt": bool(os.getenv("AUTH_JWT_SECRET", "").strip()),
            "supabase_jwt": bool(
                os.getenv("SUPABASE_JWKS_URL", "").strip()
                and os.getenv("SUPABASE_JWT_ISS", "").strip()
            ),
            "database": pool is not None,
            "memory_api": os.getenv("MEMORY_API_ENABLED", "1").strip().lower()
            in ("1", "true", "yes"),
        },
    }


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
