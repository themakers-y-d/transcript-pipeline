#!/usr/bin/env python3
"""make-fixture-vault.py <dir> [--no-vibecoder] - the smallest MAKERS vault apply-to-vault.py accepts.

Every file the kit reads or edits, holding exactly the anchor and "before" sentences the kit
looks for, and nothing else. Built from the kit's own constants, so it cannot drift from them.
Written with LF endings, so any CR found afterwards was written by apply-to-vault.py.

--no-vibecoder builds the vault MAKERS has shipped since 04.10.2026 (product 6e9a97e): no
2-makers/vibecoder/, and Morty's file counting eight makers. Without the flag it is a vault
from before that day, with the Vibecoder, byte for byte what this script always built.
"""
import importlib.util
import os
import sys
from pathlib import Path

kit = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("apply_to_vault", kit / "makers" / "apply-to-vault.py")
atv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(atv)

has_vibecoder = "--no-vibecoder" not in sys.argv[1:]
vault = Path([a for a in sys.argv[1:] if not a.startswith("--")][0])
t = atv.tables(has_vibecoder)
content = {}
def add(rel, text):
    content.setdefault(rel, []).append(text)

for rel in atv.REQUIRED + t["touched"]:
    content.setdefault(rel, [])
add("2-makers/morty/morty.md", atv.MORTY_ANCHOR)
# Each count's first "before" is the older wording (nine makers), the second the newer (eight).
for befores, _after in (atv.MORTY_NINE_1, atv.MORTY_NINE_2, atv.MORTY_NINE_3):
    add("2-makers/morty/morty.md", befores[0] if has_vibecoder else befores[1])
if has_vibecoder:
    add(atv.VIBECODER_FILE, atv.VIBECODER_CRAFT_FROM)
add(".claude/skills/absorb-the-owner/SKILL.md", atv.ABSORB_OWNER_FROM)
for rel, before, _after in t["fixes"]:
    add(rel, before)
for rel, anchor, _add, _marker in t["edits"]:
    if anchor is not None:
        add(rel, atv.anchors_of(anchor)[0])

for rel, parts in content.items():
    p = vault / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write("# " + rel + "\n\n" + "\n\n".join(parts) + "\n")
print(f"fixture vault: {len(content)} files in {vault}"
      + ("" if has_vibecoder else " (without the Vibecoder)"))
