"""lib/core/data/exercise_name_ko.dart 에서 영문→한글 맵을 추출해 JSON으로 저장한다."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DART = ROOT / "lib" / "core" / "data" / "exercise_name_ko.dart"
OUT = Path(__file__).resolve().parents[1] / "exercise_name_ko.json"

text = DART.read_text(encoding="utf-8")
pattern = re.compile(r"'((?:\\'|[^'])*)':\s*'((?:\\'|[^'])*)'")
found: dict[str, str] = {}
for en_raw, ko_raw in pattern.findall(text):
    en = en_raw.replace("\\'", "'")
    ko = ko_raw.replace("\\'", "'")
    if en and not en.startswith("//") and len(en) > 1:
        found[en] = ko

OUT.write_text(json.dumps(found, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"wrote {len(found)} entries to {OUT}")
