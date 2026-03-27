#!/usr/bin/env python3
"""
청크 JSONL → 임베딩(EMBEDDING_BACKEND) → 로컬 vector_index.json 또는 Pinecone upsert.

사전 준비:
  - EMBEDDING_BACKEND=openai + OPENAI_API_KEY (기본)
  - 또는 EMBEDDING_BACKEND=huggingface + HUGGINGFACE_API_TOKEN (Pinecone 인덱스 차원=모델 차원)
  - Pinecone 사용 시: PINECONE_API_KEY, PINECONE_INDEX_NAME

예:
  python scripts/ingest_corpus.py --out corpus/vector_index.json
  python scripts/ingest_corpus.py --pinecone
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

# 실행 시 backend_ai 루트를 path 에 넣음
_ROOT = Path(__file__).resolve().parents[1]
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))


def _load_jsonl(path: Path) -> list[dict]:
    rows: list[dict] = []
    with path.open(encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError as e:
                raise SystemExit(f"{path}:{i}: JSON error: {e}") from e
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Embed corpus chunks for RAG")
    parser.add_argument(
        "--chunks",
        type=Path,
        default=_ROOT / "corpus" / "chunks.jsonl",
        help="입력 JSONL",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=_ROOT / "corpus" / "vector_index.json",
        help="로컬 인덱스 출력 경로 (--pinecone 없을 때)",
    )
    parser.add_argument("--pinecone", action="store_true", help="Pinecone upsert")
    parser.add_argument(
        "--pinecone-namespace",
        default=os.getenv("PINECONE_NAMESPACE", "corpus"),
        help="Pinecone namespace",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=64,
        help="임베딩 API 배치 크기",
    )
    args = parser.parse_args()

    load_dotenv(_ROOT / ".env")

    from services.embedder_factory import build_embedder, embedding_credentials_ready

    if not embedding_credentials_ready():
        print(
            "Set OPENAI_API_KEY or HUGGINGFACE_API_TOKEN (and EMBEDDING_BACKEND if not openai)",
            file=sys.stderr,
        )
        return 2

    try:
        embedder = build_embedder(batch_size=args.batch_size)
    except (ValueError, RuntimeError) as e:
        print(str(e), file=sys.stderr)
        return 2

    if not args.chunks.is_file():
        print(f"chunks file not found: {args.chunks}", file=sys.stderr)
        return 2

    chunks = _load_jsonl(args.chunks)
    if not chunks:
        print("no chunks in file", file=sys.stderr)
        return 2

    texts = [str(c.get("text", "")) for c in chunks]
    vectors = embedder.embed_batch(texts)
    if len(vectors) != len(chunks):
        print("embedding count mismatch", file=sys.stderr)
        return 1

    dim = len(vectors[0]) if vectors else 0

    if args.pinecone:
        pc_key = os.getenv("PINECONE_API_KEY", "").strip()
        index_name = os.getenv("PINECONE_INDEX_NAME", "").strip()
        if not pc_key or not index_name:
            print("Pinecone mode needs PINECONE_API_KEY and PINECONE_INDEX_NAME", file=sys.stderr)
            return 2
        from pinecone import Pinecone

        from services.pinecone_batch import upsert_vector_batches

        pc = Pinecone(api_key=pc_key)
        index = pc.Index(index_name)
        ns = (args.pinecone_namespace or "corpus").strip()
        upsert_rows: list[dict] = []
        for c, vec in zip(chunks, vectors):
            cid = str(c.get("id", ""))
            if not cid:
                continue
            text = str(c.get("text", ""))[:35000]
            meta = {
                "text": text,
                "source": str(c.get("source", "")),
                "topic": str(c.get("topic", "")),
                "namespace": str(c.get("namespace", "corpus")),
                "license": str(c.get("license", "")),
            }
            upsert_rows.append({"id": cid, "values": vec, "metadata": meta})
        upsert_vector_batches(index, ns, upsert_rows)
        print(f"Upserted {len(upsert_rows)} vectors to Pinecone index={index_name!r} namespace={ns!r}")
        return 0

    records = []
    for c, vec in zip(chunks, vectors):
        cid = str(c.get("id", ""))
        records.append(
            {
                "id": cid,
                "values": vec,
                "text": str(c.get("text", "")),
                "source": str(c.get("source", "")),
                "topic": str(c.get("topic", "")),
                "namespace": str(c.get("namespace", "corpus")),
                "license": str(c.get("license", "")),
            }
        )

    payload = {
        "embedding_model": embedder.model,
        "embedding_dimensions": dim,
        "records": records,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
    print(f"Wrote {len(records)} records to {args.out} (dim={dim}, model={embedder.model})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
