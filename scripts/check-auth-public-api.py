#!/usr/bin/env python3
"""Small declaration baseline: preserve selectors/types/nullability without tools.

Comments and whitespace may change; declarations and preprocessor directives may
not. Swift imported spellings are additionally compiled by the consumer fixture.
Update a snapshot only after reviewing the intentional contract change.
"""
from pathlib import Path
import difflib
import re
import sys

root = Path(__file__).resolve().parents[1]
actual = root / "Sources/USPAuthKit/include"
baseline = root / "Tests/APIBaseline/USPAuthKit"


def declarations(path):
    text = path.read_text()
    text = re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S)
    return re.sub(r"\s+", " ", text).strip()


failed = False
names = {p.name for p in actual.glob("*.h")} | {p.name for p in baseline.glob("*.h")}
for name in sorted(names):
    source, saved = actual / name, baseline / name
    if not source.exists() or not saved.exists():
        print(f"Public header added/removed: {name}", file=sys.stderr)
        failed = True
        continue
    expected, observed = declarations(saved), declarations(source)
    if expected != observed:
        failed = True
        print(f"Public declarations changed: {name}", file=sys.stderr)
        print("\n".join(difflib.unified_diff([expected], [observed], fromfile="baseline", tofile="current")))
if failed:
    sys.exit(1)
print(f"USPAuthKit public declaration baseline: {len(names)} headers unchanged.")
