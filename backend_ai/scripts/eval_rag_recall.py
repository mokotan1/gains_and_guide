#!/usr/bin/env python3
"""
골든 쿼리로 recall@k 측정. 로컬 vector_index.json + OpenAI 쿼리 임베딩 필요.

  python scripts/eval_rag_recall.py --index corpus/vector_index.json --k 5
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
    p = argparse.ArgumentParser()
    p.add_argument(
        "--golden",
        type=Path,
        default=_ROOT / "corpus" / "golden_queries.json",
    )
    p.add_argument(
        "--index",
        type=Path,
        default=_ROOT / "corpus" / "vector_index.json",
    )
    p.add_argument("--k", type=int, default=5)
    args = p.parse_args()

    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if not api_key:
        print("OPENAI_API_KEY required", file=sys.stderr)
        return 2
    if not args.index.is_file():
        print(f"index not found: {args.index} (run scripts/ingest_corpus.py first)", file=sys.stderr)
        return 2
    if not args.golden.is_file():
        print(f"golden file not found: {args.golden}", file=sys.stderr)
        return 2

    with args.golden.open(encoding="utf-8") as f:
        golden = json.load(f)
    cases = golden.get("cases", [])

    from services.embeddings import OpenAIEmbedder
    from services.vector_rag import LocalVectorRetriever

    embedder = OpenAIEmbedder(api_key=api_key)
    retriever = LocalVectorRetriever(
        index_path=args.index,
        embedder=embedder,
        expected_model=embedder.model,
        expected_dim=embedder.dimensions,
    )

    hits = 0
    for i, case in enumerate(cases):
        q = str(case.get("query", ""))
        expected = set(case.get("expected_ids", []))
        ns = case.get("namespace", "corpus")
        got = retriever.retrieve(q, top_k=args.k, namespace=ns)
        got_ids = {c.chunk_id for c in got}
        if expected & got_ids:
            hits += 1
        else:
            print(
                f"MISS [{i}] query={q!r} expected={expected} top_ids={[c.chunk_id for c in got]}",
                file=sys.stderr,
            )

    rate = hits / len(cases) if cases else 0.0
    print(f"recall@{args.k}: {hits}/{len(cases)} = {rate:.2%}")
    return 0 if hits == len(cases) else 1


if __name__ == "__main__":
    raise SystemExit(main())
