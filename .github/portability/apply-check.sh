#!/bin/bash
# apply-check.sh <work-dir> - apply-to-vault.py on a fixture MAKERS vault (V1 item 8).
# Asserts: --check reports work, the apply succeeds, a second --check is clean, every file it
# edited keeps LF endings, and the scripts' .gitattributes landed. On Windows also that the
# Windows scheduler landed, and a negative control: the kit as it was on main writes CRLF.
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
  # Negative control: apply-to-vault.py as it is on main, run from the same place in the kit.
  if git -C "$KIT" show origin/main:makers/apply-to-vault.py > "$KIT/makers/apply-to-vault-main.py" 2>/dev/null; then
    "$PY" "$KIT/.github/portability/make-fixture-vault.py" "$W/vault-main" >/dev/null
    "$PY" "$KIT/makers/apply-to-vault-main.py" "$W/vault-main" > /dev/null 2>&1
    n="$(find "$W/vault-main" -type f -name '*.md' | while IFS= read -r f; do [ "$(crs "$f")" = 0 ] || echo "$f"; done | wc -l | tr -d ' ')"
    rm -f "$KIT/makers/apply-to-vault-main.py"
    [ "$n" -gt 0 ] && ok "negative control: main's apply-to-vault.py wrote CRLF into $n file(s) on Windows" || bad "negative control: main wrote no CRLF, so this check proves nothing"
  fi
else
  [ ! -e "$W/vault/.claude/scripts/windows" ] && ok "Mac: no Windows scheduler copied into the vault" || bad "Mac vault received windows/"
fi
echo "APPLY-CHECK $([ "$FAILS" = 0 ] && echo GREEN || echo "RED ($FAILS failed)")"
[ "$FAILS" = 0 ]
