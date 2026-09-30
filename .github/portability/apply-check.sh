#!/bin/bash
# apply-check.sh <work-dir> - apply-to-vault.py on a fixture MAKERS vault (V1 item 8).
# Asserts: --check reports work, the apply succeeds, a second --check is clean, every file it
# edited keeps LF endings, and the scripts' .gitattributes landed. On Windows also that the
# Windows scheduler landed, and a negative control: the kit as it was before the Windows port (0fedf23) writes CRLF.
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
W="$1"; rm -rf "$W"; mkdir -p "$W"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WIN=1 ;; *) WIN=0 ;; esac
PY=""; for c in python3 python py; do "$c" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1 && { PY="$c"; break; }; done
FAILS=0; ok() { echo "PASS  $1"; }; bad() { echo "FAIL  $1"; FAILS=$((FAILS+1)); }

"$PY" "$KIT/.github/portability/make-fixture-vault.py" "$W/vault"
"$PY" "$KIT/makers/apply-to-vault.py" "$W/vault" --check > "$W/check1.txt" 2>&1; rc1=$?
"$PY" "$KIT/makers/apply-to-vault.py" "$W/vault" > "$W/apply.txt" 2>&1; rc2=$?
"$PY" "$KIT/makers/apply-to-vault.py" "$W/vault" --check > "$W/check2.txt" 2>&1; rc3=$?
cat "$W/apply.txt"
[ "$rc1" = 1 ] && grep -q "change(s) outstanding" "$W/check1.txt" && ok "--check on a fresh vault reports outstanding changes" || bad "--check before (rc $rc1)"
[ "$rc2" = 0 ] && ok "apply exits 0" || bad "apply (rc $rc2)"
[ "$rc3" = 0 ] && grep -q "Everything is already in place" "$W/check2.txt" && ok "second --check: everything in place" || { bad "--check after (rc $rc3)"; cat "$W/check2.txt"; }
crs() { tr -cd '\r' < "$1" | wc -c | tr -d ' '; }
CR_FILES="$(find "$W/vault" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.py' -o -name '.gitattributes' \) | while IFS= read -r f; do [ "$(crs "$f")" = 0 ] || echo "$f"; done)"
[ -z "$CR_FILES" ] && ok "no edited or copied text file carries a CR" || { bad "files with CR:"; echo "$CR_FILES"; }
[ -f "$W/vault/.claude/scripts/.gitattributes" ] && ok ".claude/scripts/.gitattributes landed" || bad ".gitattributes missing"
if [ "$WIN" = 1 ]; then
  [ -f "$W/vault/.claude/scripts/windows/schedule.ps1" ] && ok "Windows: .claude/scripts/windows/schedule.ps1 landed" || bad "schedule.ps1 missing"
  # Negative control: apply-to-vault.py as it was before the port (0fedf23), run from the same place in the kit.
  if git -C "$KIT" show 0fedf23:makers/apply-to-vault.py > "$KIT/makers/apply-to-vault-main.py" 2>/dev/null; then
    "$PY" "$KIT/.github/portability/make-fixture-vault.py" "$W/vault-main" >/dev/null
    "$PY" "$KIT/makers/apply-to-vault-main.py" "$W/vault-main" > /dev/null 2>&1
    n="$(find "$W/vault-main" -type f -name '*.md' | while IFS= read -r f; do [ "$(crs "$f")" = 0 ] || echo "$f"; done | wc -l | tr -d ' ')"
    rm -f "$KIT/makers/apply-to-vault-main.py"
    [ "$n" -gt 0 ] && ok "negative control: the pre-port apply-to-vault.py wrote CRLF into $n file(s) on Windows" || bad "negative control: the pre-port kit wrote no CRLF, so this check proves nothing"
  fi
else
  [ ! -e "$W/vault/.claude/scripts/windows" ] && ok "Mac: no Windows scheduler copied into the vault" || bad "Mac vault received windows/"
fi
# A first-cohort vault: /check-the-system from before check 15 and the born-later paragraph.
# The kit must refresh it from its baseline and finish; with a line the owner wrote in it, it
# must stop and leave the file untouched until --refresh-check-the-system is passed.
C=".claude/skills/check-the-system/SKILL.md"
mk_old() {
  "$PY" "$KIT/.github/portability/make-fixture-vault.py" "$1" >/dev/null
  "$PY" - "$KIT/makers/baseline/check-the-system.SKILL.md" "$1/$C" <<'EOF'
import sys
drop = ("**Three paths are born later", "**15. Makers nothing", "**Skip the finding while",
        "Past that, a maker carrying", "⛔ **Never report a maker")
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
open(sys.argv[2], "w", encoding="utf-8", newline="\n").write("\n".join(l for l in lines if not l.startswith(drop)))
EOF
}
mk_old "$W/old"
"$PY" "$KIT/makers/apply-to-vault.py" "$W/old" --check > "$W/old1.txt" 2>&1; o1=$?
"$PY" "$KIT/makers/apply-to-vault.py" "$W/old" > /dev/null 2>&1; o2=$?
"$PY" "$KIT/makers/apply-to-vault.py" "$W/old" --check > "$W/old3.txt" 2>&1; o3=$?
[ "$o1" = 1 ] && grep -q "refresh: $C" "$W/old1.txt" && ok "older check-the-system: --check reports a refresh" || { bad "older check-the-system --check (rc $o1)"; cat "$W/old1.txt"; }
[ "$o2" = 0 ] && [ "$o3" = 0 ] && [ "$(grep -c 'A fourth is born later\|16. Recordings that skipped\|Four makers ship' "$W/old/$C")" = 3 ] \
  && ok "older check-the-system: refreshed, all three edits landed, second --check clean" || bad "older check-the-system apply (rc $o2/$o3)"
mk_old "$W/own"; echo "My own note: also check the Canva folder." >> "$W/own/$C"; cp "$W/own/$C" "$W/own.before"
"$PY" "$KIT/makers/apply-to-vault.py" "$W/own" > "$W/own1.txt" 2>&1; w1=$?
[ "$w1" = 1 ] && grep -q "My own note" "$W/own1.txt" && cmp -s "$W/own/$C" "$W/own.before" && [ ! -e "$W/own/2-makers/scribe" ] \
  && ok "owner line in an older check-the-system: stops, prints it, writes nothing" || bad "owner line guard (rc $w1)"
"$PY" "$KIT/makers/apply-to-vault.py" "$W/own" --refresh-check-the-system > /dev/null 2>&1; w2=$?
[ "$w2" = 0 ] && ok "--refresh-check-the-system replaces it once the owner has seen the line" || bad "refresh flag (rc $w2)"
# The same, on a real first-cohort copy (product 4a1d291, 20.08), which is not a subset of the
# baseline: its check 8 is an older wording. It must refresh with no flag.
"$PY" "$KIT/.github/portability/make-fixture-vault.py" "$W/real" >/dev/null
cp "$KIT/.github/portability/fixtures/check-the-system-4a1d291.md" "$W/real/$C"
"$PY" "$KIT/makers/apply-to-vault.py" "$W/real" > "$W/real1.txt" 2>&1; r1=$?
"$PY" "$KIT/makers/apply-to-vault.py" "$W/real" --check > /dev/null 2>&1; r2=$?
[ "$r1" = 0 ] && [ "$r2" = 0 ] && grep -q "refresh: $C" "$W/real1.txt" \
  && ok "real first-cohort check-the-system (4a1d291): refreshed with no flag, second --check clean" || { bad "real 4a1d291 (rc $r1/$r2)"; cat "$W/real1.txt"; }
CR_OLD="$(for v in old own real; do find "$W/$v" -type f -name '*.md' | while IFS= read -r f; do [ "$(crs "$f")" = 0 ] || echo "$f"; done; done)"
[ -z "$CR_OLD" ] && ok "refreshed vaults carry no CR" || { bad "CR after refresh:"; echo "$CR_OLD"; }

echo "APPLY-CHECK $([ "$FAILS" = 0 ] && echo GREEN || echo "RED ($FAILS failed)")"
[ "$FAILS" = 0 ]
