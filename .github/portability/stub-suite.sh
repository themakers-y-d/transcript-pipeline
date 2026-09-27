#!/bin/bash
# stub-suite.sh - run the real uploader and absorber end to end against a throwaway git vault,
# with a stub in place of `claude` (stub_claude.py). Mac and Windows (Git Bash) alike.
#
#   bash stub-suite.sh <kit-dir> <work-dir>
#
# Environment:
#   SUITE_FIXED_TIME=1   pin `date` and the git dates, so two runs (before and after a change)
#                        produce byte-identical calls, state files and commits. Mac only.
#   SUITE_FAKE_PY3=1     put a broken `python3` first on PATH, like the Microsoft Store stub
#                        that answers every call with "Python was not found" and exit 9009.
#   CHUNK_CHAR_LIMIT     passed through to the uploader when set.
#
# Everything the run produced is collected in <work-dir>/out, and every assertion prints
# PASS or FAIL. Exit 1 if any assertion failed.
#
# It writes a `claude` stub into $HOME/.local/bin. Run it with a throwaway HOME, or on a
# machine where no real claude lives there (it refuses to overwrite one).
set -u
KIT="$(cd "$1" && pwd)"
W="$2"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rm -rf "$W"; mkdir -p "$W"; W="$(cd "$W" && pwd)"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WIN=1 ;; *) WIN=0 ;; esac
m() { if [ "$WIN" = 1 ]; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

OUT="$W/out"; ROOT="$W/stub"; V="$W/vault"; BIN="$W/bin"
mkdir -p "$OUT" "$ROOT/fixtures/bodies" "$ROOT/log" "$BIN"

# --- a Python 3 for the stub itself, never the fake one ---
SPY=""
for c in python3 python py; do
  "$c" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1 && { SPY="$(command -v "$c")"; break; }
done
[ -n "$SPY" ] || { echo "no python 3 for the stub"; exit 2; }

# --- the claude stub, where the scripts look for claude ---
mkdir -p "$HOME/.local/bin"
if [ -e "$HOME/.local/bin/claude" ] && [ ! -e "$HOME/.local/bin/.claude-is-portability-stub" ]; then
  echo "refusing: $HOME/.local/bin/claude exists and is not this suite's stub"; exit 2
fi
cat > "$HOME/.local/bin/claude" <<EOF
#!/bin/bash
exec "$SPY" "$(m "$HERE/stub_claude.py")" "$(m "$ROOT")" "\$@"
EOF
chmod +x "$HOME/.local/bin/claude"; : > "$HOME/.local/bin/.claude-is-portability-stub"

# --- osascript and (optionally) date stubs, first on PATH ---
cat > "$BIN/osascript" <<EOF
#!/bin/bash
printf '%s\n' "\$*" >> "$OUT/osascript.log"
EOF
chmod +x "$BIN/osascript"
if [ "${SUITE_FIXED_TIME:-0}" = 1 ]; then
  printf '#!/bin/bash\nexec /bin/date -r 1790000000 "$@"\n' > "$BIN/date"; chmod +x "$BIN/date"
  export GIT_AUTHOR_DATE="2026-09-21T12:00:00+0300" GIT_COMMITTER_DATE="2026-09-21T12:00:00+0300"
fi
if [ "${SUITE_FAKE_PY3:-0}" = 1 ]; then
  printf '#!/bin/bash\necho "Python was not found; run without arguments to install from the Microsoft Store." >&2\nexit 49\n' > "$BIN/python3"
  chmod +x "$BIN/python3"
fi
export PATH="$BIN:$PATH"
export GIT_AUTHOR_NAME=suite GIT_AUTHOR_EMAIL=suite@example.invalid GIT_COMMITTER_NAME=suite GIT_COMMITTER_EMAIL=suite@example.invalid
[ "$WIN" = 0 ] && mkdir -p "$HOME/Library/Logs"      # a real Mac always has it
if [ "$WIN" = 1 ]; then LOGD="$(cygpath -m "$LOCALAPPDATA")/transcript-pipeline/logs"; else LOGD="$HOME/Library/Logs"; fi

# --- fixtures ---
TAB="$(printf '\t')"
line() { local n="$1" w="$2"; printf 'דובר %s: %s\n' "$n" "$w"; }
{
  for i in $(seq 1 520); do line $((i % 2 + 1)) "משפט ארוך מספר $i על התוכנית, רו\"ח אמר שצריך לבדוק את המספרים ואת הלוח זמנים שוב"; done
} > "$ROOT/fixtures/bodies/m-long.txt"
{ for i in $(seq 1 25); do line 1 "שיחה רגילה, שורה $i, עם לקוח שרוצה להבין את ההצעה והמחיר"; done; } > "$ROOT/fixtures/bodies/m-normal.txt"
{ for i in $(seq 1 18); do line 2 "פגישה בלי כותרת, שורה $i, על המשך העבודה והשלבים הבאים"; done; } > "$ROOT/fixtures/bodies/m-notitle.txt"
printf 'דובר 1: בדיקה אחת שתיים\n' > "$ROOT/fixtures/bodies/m-short.txt"
printf 'EMPTY\n' > "$ROOT/fixtures/bodies/m-empty.txt"
{
  printf 'm-long%s2026-09-20T07:15:00Z%strue%sפגישת אסטרטגיה ארוכה\n' "$TAB" "$TAB" "$TAB"
  printf 'm-normal%s2026-09-21T09:00:00.000Z%strue%sשיחה עם לקוח\n' "$TAB" "$TAB" "$TAB"
  printf 'm-short%s2026-09-21T10:00:00Z%strue%sבדיקה\n' "$TAB" "$TAB" "$TAB"
  printf 'm-empty%s2026-09-21T11:00:00Z%strue%sהקלטה ריקה\n' "$TAB" "$TAB" "$TAB"
  printf 'm-notx%s2026-09-21T12:00:00Z%sfalse%sבלי תמלול\n' "$TAB" "$TAB" "$TAB"
  printf 'm-notitle%s2026-09-22T08:30:00Z%strue\n' "$TAB" "$TAB"
} > "$ROOT/fixtures/meetings.tsv"
printf 'd-001%sתמלול א\nd-002%sתמלול ב\nd-003%sתמלול ג\n' "$TAB" "$TAB" "$TAB" > "$ROOT/fixtures/docs.txt"
printf 'd-004\n' > "$ROOT/fixtures/absorb-done.txt"

# --- the vault, MAKERS layout: the scripts live inside it, so both commits are exercised ---
mkdir -p "$V/memory" "$V/transcripts/reports" "$V/.claude/scripts"
printf '# פרופיל\n\n## יומן\n' > "$V/memory/profile.md"
cp "$KIT/transcript-protocol.md" "$V/.claude/transcript-protocol.md"
for f in transcript-uploader.sh transcript-absorber.sh build-parts.py empty-register.py config.example.sh; do
  cp "$KIT/scripts/$f" "$V/.claude/scripts/$f"
done
cp "$V/.claude/scripts/config.example.sh" "$V/.claude/scripts/config.sh"
# On Windows VAULT is written the way Git Bash's pwd says it (/c/...), which the scripts must
# turn into C:/... themselves.
cat >> "$V/.claude/scripts/config.sh" <<EOF
VAULT="$V"
DRIVE_FOLDER_ID="folder-123"
WISPR_TOOL_PREFIX="mcp__wisprflow__"
DRIVE_TOOL_PREFIX="mcp__claude_ai_Google_Drive__"
LABEL_PREFIX="com.portability.transcript"
OWNED_PATHS="
memory/*.md
transcripts/reports/*
.claude/scripts/absorber-state.txt
"
EOF
git -C "$V" init -q && git -C "$V" add -A && git -C "$V" commit -q -m "vault before the pipeline"

up() { local name="$1"; shift; ( cd "$W" && env "$@" bash "$V/.claude/scripts/transcript-uploader.sh" ) > "$OUT/$name.log" 2>&1; echo $? > "$OUT/$name.rc"; cp "$ROOT/log/counter" "$OUT/$name.after-call" 2>/dev/null; cp "$V/.claude/scripts/uploader-heartbeat.txt" "$OUT/$name.heartbeat" 2>/dev/null; cp "$LOGD/com.portability.transcript-uploader.health" "$OUT/$name.health" 2>/dev/null; mkdir -p "$OUT/$name-staging-logs"; cp "$V/transcripts/reports/_process/_staging/"log-*.txt "$OUT/$name-staging-logs/" 2>/dev/null; }
ab() { local name="$1"; shift; ( cd "$W" && env "$@" bash "$V/.claude/scripts/transcript-absorber.sh" ) > "$OUT/$name.log" 2>&1; echo $? > "$OUT/$name.rc"; cp "$ROOT/log/counter" "$OUT/$name.after-call" 2>/dev/null; }

up U0 X=1                       # empty state file: must refuse, rc 3, and notify
up U1 ALLOW_EMPTY_STATE=1       # first real run
up U2 X=1
up U3 X=1                       # third under-floor sighting: m-short and m-empty retire
up U4 X=1                       # nothing new, and the retired blips must not be fetched
ab A0 SEED_ONLY=1
git -C "$V" add -A && git -C "$V" commit -q -m "after the seed"
printf 'd-004%sתמלול ד\n' "$TAB" >> "$ROOT/fixtures/docs.txt"
ab A1 X=1
git -C "$V" -c core.quotepath=false show --name-only --format= HEAD | sort | tr '\n' ' ' > "$OUT/A1.commit-files"
# The two failure notifications that remain: an absorbing run that reports an item failure,
# and an uploader whose enumeration comes back empty (a dead connection, rc 2).
: > "$ROOT/fixtures/absorb-failed-1"
ab A2 X=1
: > "$ROOT/fixtures/meetings.tsv"
up U5 X=1

# --- collect ---
cp "$ROOT/log/calls.log" "$ROOT/log/uploads.tsv" "$OUT/" 2>/dev/null
mkdir -p "$OUT/prompts"; cp "$ROOT"/log/prompt-*.txt "$OUT/prompts/" 2>/dev/null
for f in uploader-state.txt uploader-empty.txt uploader-heartbeat.txt absorber-state.txt absorber-heartbeat.txt; do
  cp "$V/.claude/scripts/$f" "$OUT/$f" 2>/dev/null
done
for f in com.portability.transcript-uploader.health com.portability.transcript-uploader.warn com.portability.transcript-absorber.health; do
  cp "$LOGD/$f" "$OUT/$f" 2>/dev/null
done
git -C "$V" -c core.quotepath=false log -p --format='commit %H%n%T%n%s' > "$OUT/git-log.txt"
git -C "$V" -c core.quotepath=false status --short > "$OUT/git-status.txt"
# The same history without the scripts' own source, which is exactly what differs between two
# versions of the kit. What is left is what the pipeline wrote, and that must not differ.
git -C "$V" -c core.quotepath=false log -p --format='%s' -- . ':(exclude).claude/scripts/*.sh' ':(exclude).claude/scripts/*.py' > "$OUT/git-log-content.txt"

# --- assertions ---
FAILS=0
ok()  { echo "PASS  $1"; }
bad() { echo "FAIL  $1"; FAILS=$((FAILS+1)); }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }
rc() { tr -d '\r\n' < "$OUT/$1.rc"; }
calls_between() { awk -F'\t' -v a="$1" -v b="$2" -v p="$3" '$1>a && $1<=b && $2==p' "$ROOT/log/calls.log" | wc -l | tr -d ' '; }

check "U0 refuses an empty state file (rc 3)" '[ "$(rc U0)" = 3 ]'
check "U0 wrote the FAIL health flag in LOG_DIR" 'grep -q "^FAIL .*empty-state-file" "$OUT/U0.health"'
[ "$WIN" = 0 ] && check "U0 notified through osascript, same text as always" 'grep -q "display notification \"קובץ המעקב של מעלה התמלולים ריק. הריצה נעצרה כדי שלא יעלה הכל מחדש.\" with title \"צינור התמלולים\" sound name \"Basso\"" "$OUT/osascript.log"'
for r in U1 U2 U3 U4 A0 A1 A2; do check "$r exits 0" '[ "$(rc '"$r"')" = 0 ]'; done
check "U1 recorded exactly the three real meetings" '[ "$(grep -v "^#" "$OUT/uploader-state.txt" | tr -d "\r" | sort | tr "\n" " ")" = "m-long m-normal m-notitle " ]'
check "U1 did not count an under-floor meeting as failed" 'grep -q "^last-successful-run: .*uploaded=3  under-floor=2" "$OUT/U1.heartbeat"'
check "no uploaded title or body carries a CR" '! grep -q "<CR>\|has-CR" "$ROOT/log/uploads.tsv"'
LONG_N="$(grep -c "פגישת אסטרטגיה ארוכה" "$ROOT/log/uploads.tsv")"
LONG_P="$(grep -o "(חלק 1 מתוך [0-9]*)" "$ROOT/log/uploads.tsv" | head -1 | grep -o "[0-9]*)" | tr -d ")")"
check "the long meeting uploaded as N parts, and N receipts matched (N=$LONG_N)" '[ -n "$LONG_P" ] && [ "$LONG_N" = "$LONG_P" ] && [ "$LONG_N" -ge 2 ]'
check "the document time is local (07:15Z is 10:15 in Asia/Jerusalem)" 'grep -q "10:15 | פגישת אסטרטגיה ארוכה" "$ROOT/log/uploads.tsv"'
check "a meeting with no title still got its own time (08:30Z is 11:30)" 'grep -q "11:30 | ללא נושא" "$ROOT/log/uploads.tsv"'
check "under-floor register retired m-short and m-empty after three sightings" '[ "$(awk -F"\t" "\$2==\"blip\"{print \$1}" "$OUT/uploader-empty.txt" | tr -d "\r" | sort | tr "\n" " ")" = "m-empty m-short " ]'
check "U4 fetched nothing (retired blips excluded from the worklist)" '[ "$(calls_between "$(cat "$OUT/U3.after-call")" "$(cat "$OUT/U4.after-call")" fetch)" = 0 ]'
check "U4 says 2 retired as empty" 'grep -q "2 retired as empty" "$OUT/U4.log"'
check "the uploader committed its own state once, by path" '[ "$(grep -c "^transcript uploader .*: 3 transcript(s) uploaded" "$OUT/git-log.txt")" = 1 ]'
check "uploader health OK in LOG_DIR after U4" 'grep -q "^OK " "$OUT/U4.health"'
check "uploader health FAIL after U5" 'grep -q "^FAIL .*rc=2" "$OUT/U5.health"'
check "A0 seeded the three existing documents" '[ "$(grep -v "^#" "$OUT/absorber-state.txt" | tr -d "\r" | head -3 | tr "\n" " ")" = "d-001 d-002 d-003 " ]'
check "A1 recorded d-004" 'grep -qx "d-004" <(tr -d "\r" < "$OUT/absorber-state.txt")'
LAST_FILES="$(cat "$OUT/A1.commit-files")"
check "A1 committed only owned paths ($LAST_FILES)" '[ "$LAST_FILES" = ".claude/scripts/absorber-state.txt memory/profile.md transcripts/reports/stub-report.md " ]'
check "A1 left the unowned write in the working tree" 'grep -q "?? notes/" "$OUT/git-status.txt"'
check "A1 heartbeat carries the undo line" 'grep -q "last-successful-run: .*undo=git revert --no-edit" "$OUT/absorber-heartbeat.txt"'
check "A2 surfaced the item failure in the heartbeat" 'grep -q "^ITEM FAILURES: .*failed=1" "$OUT/absorber-heartbeat.txt"'
check "U5 treats an empty enumeration as a dead connection (rc 2)" '[ "$(rc U5)" = 2 ]'
[ "$WIN" = 0 ] && check "the three failure notifications exercised here went through osascript" '[ "$(wc -l < "$OUT/osascript.log" | tr -d " ")" = 3 ] && grep -q "1 תמלול לא נספג במלואו. בדוק את הלוג." "$OUT/osascript.log" && grep -q "התמלולים של היום לא הועלו לתיקייה." "$OUT/osascript.log"'
check "absorber health OK in LOG_DIR" 'grep -q "^OK " "$LOGD/com.portability.transcript-absorber.health"'
MAXP="$(awk -F'\t' '$2=="upload"{if($5>m)m=$5} END{print m+0}' "$ROOT/log/calls.log")"
echo "INFO  longest upload prompt: $MAXP characters (Windows limit for a whole command line: 32767)"
echo "INFO  uploads: $(wc -l < "$ROOT/log/uploads.tsv" | tr -d ' '), calls: $(wc -l < "$ROOT/log/calls.log" | tr -d ' '), stub python: $SPY"
echo "SUITE $([ "$FAILS" = 0 ] && echo GREEN || echo "RED ($FAILS failed)")"
[ "$FAILS" = 0 ]
