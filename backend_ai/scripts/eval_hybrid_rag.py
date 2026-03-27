#!/usr/bin/env python3
"""
하이브리드 RAG(코퍼스 + 유저 네임스페이스) 스모크 평가.

로컬 토큰 RAG 또는 Pinecone(OPENAI+PINECONE 환경)에서 golden 케이스를 실행한다.

  python scripts/eval_hybrid_rag.py
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parents[1]
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))


def main() -> int:
    parser = argparse.ArgumentParser(description="Hybrid RAG eval smoke")
    parser.add_argument(
        "--golden",
        type=Path,
        default=_ROOT / "corpus" / "hybrid_golden_queries.json",
        help="JSON with cases: query, optional user_namespace, expect_corpus_ids, expect_user_ids",
    )
    args = parser.parse_args()

    if not args.golden.is_file():
        print(f"golden file not found: {args.golden}", file=sys.stderr)
        return 2

    with args.golden.open(encoding="utf-8") as f:
        data = json.load(f)
    cases = data.get("cases", [])
    if not cases:
        print("no cases", file=sys.stderr)
        return 2

    from services.hybrid_retrieval import hybrid_rag_config_from_env, retrieve_corpus_and_user
    from services.rag import create_rag_service

    base_dir = str(_ROOT)
    rag = create_rag_service(base_dir)
    cfg = hybrid_rag_config_from_env()
    corp_ns = os.getenv("PINECONE_NAMESPACE", "corpus").strip() or "corpus"

    failed = 0
    for i, case in enumerate(cases):
        q = case.get("query", "")
        user_ns = case.get("user_namespace")
        ec = set(case.get("expect_corpus_ids", []))
        eu = set(case.get("expect_user_ids", []))
        corp, usr = retrieve_corpus_and_user(
            rag,
            q,
            user_namespace=user_ns,
            cfg=cfg,
            corpus_namespace=corp_ns,
        )
        got_c = {h.chunk_id for h in corp}
        got_u = {h.chunk_id for h in usr}
        if ec and not ec.issubset(got_c):
            print(f"case {i}: corpus want subset {ec} got {got_c}", file=sys.stderr)
            failed += 1
        if eu and not eu.issubset(got_u):
            print(f"case {i}: user want subset {eu} got {got_u}", file=sys.stderr)
            failed += 1

    if failed:
        return 1
    print(f"OK {len(cases)} hybrid cases (mode={rag.mode})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
