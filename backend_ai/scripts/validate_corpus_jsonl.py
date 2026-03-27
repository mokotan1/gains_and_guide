#!/usr/bin/env python3
"""corpus/chunks.jsonl 줄 단위 JSON 및 필수 키 검증."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REQUIRED = ("id", "namespace", "text", "source", "topic")


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument(
        "path",
        nargs="?",
        default=None,
        help="JSONL 경로 (기본: backend_ai/corpus/chunks.jsonl)",
    )
    args = p.parse_args()
    root = Path(__file__).resolve().parents[1]
    path = Path(args.path) if args.path else root / "corpus" / "chunks.jsonl"
    if not path.is_file():
        print(f"missing file: {path}", file=sys.stderr)
        return 2
    n = 0
    with path.open(encoding="utf-8") as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError as e:
                print(f"line {i}: JSON error: {e}", file=sys.stderr)
                return 1
            missing = [k for k in REQUIRED if k not in obj]
            if missing:
                print(f"line {i}: missing keys {missing}", file=sys.stderr)
                return 1
            n += 1
    print(f"OK: {n} chunks in {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
