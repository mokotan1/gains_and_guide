"""선택적 Supabase/Postgres 연결 풀 (DATABASE_URL)."""

from __future__ import annotations

import logging
import os
from typing import Any, Optional

logger = logging.getLogger(__name__)


async def init_db_pool(app: Any) -> None:
    url = os.getenv("DATABASE_URL", "").strip()
    if not url:
        app.state.db_pool = None
        logger.info("DATABASE_URL not set; skipping Postgres pool")
        return
    try:
        import asyncpg

        app.state.db_pool = await asyncpg.create_pool(
            dsn=url,
            min_size=1,
            max_size=5,
            statement_cache_size=0,
        )
        logger.info("Postgres connection pool ready")
    except Exception:
        logger.exception("Failed to create Postgres pool; continuing without DB")
        app.state.db_pool = None


async def close_db_pool(app: Any) -> None:
    pool = getattr(app.state, "db_pool", None)
    if pool is not None:
        await pool.close()
        app.state.db_pool = None


def get_pool(app: Any) -> Any:
    return getattr(app.state, "db_pool", None)
