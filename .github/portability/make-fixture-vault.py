#!/usr/bin/env python3
"""make-fixture-vault.py <dir> - the smallest MAKERS vault apply-to-vault.py accepts.

Every file the kit reads or edits, holding exactly the anchor and "before" sentences the kit
looks for, and nothing else. Built from the kit's own constants, so it cannot drift from them.
Written with LF endings, so any CR found afterwards was written by apply-to-vault.py.
"""
import importlib.util
import os
import sys
from pathlib import Path

kit = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("apply_to_vault", kit / "makers" / "apply-to-vault.py")
atv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(atv)

vault = Path(sys.argv[1])
content = {}
def add(rel, text):
    content.setdefault(rel, []).append(text)

for rel in atv.REQUIRED + atv.TOUCHED:
    content.setdefault(rel, [])
add("2-makers/morty/morty.md", atv.MORTY_ANCHOR)
for before, _after in (atv.MORTY_NINE_1, atv.MORTY_NINE_2, atv.MORTY_NINE_3):
    add("2-makers/morty/morty.md", before)
add("2-makers/vibecoder/vibecoder.md", atv.VIBECODER_CRAFT_FROM)
add(".claude/skills/absorb-the-owner/SKILL.md", atv.ABSORB_OWNER_FROM)
for rel, before, _after in atv.CRAFT_COUNT_FIXES:
    add(rel, before)
for rel, anchor, _add, _marker in atv.EDITS:
    if anchor is not None:
        add(rel, anchor)

for rel, parts in content.items():
    p = vault / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write("# " + rel + "\n\n" + "\n\n".join(parts) + "\n")
print(f"fixture vault: {len(content)} files in {vault}")
