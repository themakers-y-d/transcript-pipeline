#!/usr/bin/env python3
"""runbook-blocks.py <runbook.md> <out-dir> - write every ```bash block that is guarded to run
only on Windows (case "$(uname -s)" in MINGW*...) to its own file, skipping the ones that
install software (winget) or delete and re-clone, so CI can run the rest exactly as written."""
import re
import sys
from pathlib import Path

src, out = Path(sys.argv[1]), Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
n = 0
for block in re.findall(r"```bash\n(.*?)```", src.read_text(encoding="utf-8"), re.S):
    if "MINGW*|MSYS*|CYGWIN*" not in block or "winget" in block or "rm -rf" in block:
        continue
    n += 1
    (out / f"block{n:02d}.sh").write_bytes(block.encode("utf-8"))
print(f"{n} Windows-guarded block(s) from {src.name}")
