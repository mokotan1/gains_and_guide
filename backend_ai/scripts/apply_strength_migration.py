"""Apply supabase/migrations/006_strength_competition.sql and verify season seed.

Usage (from repo root):
  set DATABASE_URL=postgresql://...
  python backend_ai/scripts/apply_strength_migration.py

Or with backend_ai/.env containing DATABASE_URL:
  python backend_ai/scripts/apply_strength_migration.py
"""

from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MIGRATION_PATH = REPO_ROOT / "supabase" / "migrations" / "006_strength_competition.sql"
ENV_PATH = REPO_ROOT / "backend_ai" / ".env"


def _load_database_url() -> str:
    try:
        from dotenv import load_dotenv

        load_dotenv(ENV_PATH)
    except ImportError:
        pass

    url = os.getenv("DATABASE_URL", "").strip()
    if not url:
        print(
            "DATABASE_URL is not set.\n"
            "Add it to backend_ai/.env or export it in the shell, then retry.",
            file=sys.stderr,
        )
        sys.exit(1)
    return url


async def _run() -> None:
    if not MIGRATION_PATH.is_file():
        print(f"Migration file not found: {MIGRATION_PATH}", file=sys.stderr)
        sys.exit(1)

    import asyncpg

    url = _load_database_url()
    sql = MIGRATION_PATH.read_text(encoding="utf-8")

    conn = await asyncpg.connect(dsn=url)
    try:
        exists = await conn.fetchval(
            """
            select exists (
              select 1
              from information_schema.tables
              where table_schema = 'public'
                and table_name = 'strength_seasons'
            )
            """
        )
        if exists:
            print("strength_seasons already exists — skipping migration apply.")
        else:
            print(f"Applying {MIGRATION_PATH.name} ...")
            await conn.execute(sql)
            print("Migration applied.")

        season_count = await conn.fetchval(
            "select count(*)::int from public.strength_seasons"
        )
        active_slug = await conn.fetchval(
            """
            select slug
            from public.strength_seasons
            where is_active = true
              and now() between starts_at and ends_at
            order by starts_at desc
            limit 1
            """
        )
        print(f"strength_seasons rows: {season_count}")
        print(f"current active season slug: {active_slug or '(none)'}")
        if season_count == 0:
            print("Warning: no seasons seeded. Check migration output.", file=sys.stderr)
            sys.exit(2)
    finally:
        await conn.close()


def main() -> None:
    asyncio.run(_run())


if __name__ == "__main__":
    main()
