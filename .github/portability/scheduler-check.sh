#!/bin/bash
# scheduler-check.sh <vault> <label-prefix> - scripts/windows/schedule.ps1 end to end (V1 item 7).
# install, status, run the absorber through Task Scheduler, wait for its heartbeat to change,
# then uninstall and prove nothing is left. Interactive first, which is what an owner gets. A
# hosted CI runner may have no interactive session to start it in; then the same chain is
# proven with -LogonType S4U, and the report says so.
set -u
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
V="$1"; LABEL="$2"
PS1="$(cygpath -w "$KIT/scripts/windows/schedule.ps1")"
SD="$(cygpath -m "$V/.claude/scripts")"
HB="$V/.claude/scripts/absorber-heartbeat.txt"
LOGD="$(cygpath -u "$LOCALAPPDATA")/transcript-pipeline/logs"
sched() { powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$PS1" "$@"; }

attempt() {
  local logon="$1" before after i
  echo "=== install, LogonType $logon"
  sched -Action install -LabelPrefix "$LABEL" -ScriptsDir "$SD" -LogonType "$logon" || return 1
  echo "=== status"
  sched -Action status -LabelPrefix "$LABEL" || return 1
  before="$(cat "$HB" 2>/dev/null)"
  echo "=== run -Job absorber"
  sched -Action run -LabelPrefix "$LABEL" -Job absorber || return 1
  for i in $(seq 1 36); do
    after="$(cat "$HB" 2>/dev/null)"
    [ "$after" != "$before" ] && break
    sleep 5
  done
  echo "=== status after the run"
  sched -Action status -LabelPrefix "$LABEL"
  if [ "$after" = "$before" ]; then
    echo "heartbeat did not change in 3 minutes under $logon"
    tail -5 "$LOGD/transcript-absorber.stderr.log" 2>/dev/null
    return 1
  fi
  echo "heartbeat now: $after"
  echo "=== the task's own stdout log (redirected by the scheduled command)"
  tail -4 "$LOGD/transcript-absorber.stdout.log"
  printf '%s' "$after" | grep -q '^last-successful-run' || return 1
  grep -q "absorber finished rc=0" "$LOGD/transcript-absorber.stdout.log" || return 1
  return 0
}

RESULT=""
if attempt Interactive; then RESULT="Interactive"
else
  echo "Interactive logon could not run the job on this runner; retrying the same chain with S4U"
  if attempt S4U; then RESULT="S4U (CI fallback; an owner's machine uses Interactive)"; fi
fi

echo "=== uninstall"
sched -Action uninstall -LabelPrefix "$LABEL"; urc=$?
echo "=== status after uninstall (must fail: nothing registered)"
sched -Action status -LabelPrefix "$LABEL"; src=$?
echo "=== notify-test (the toast call must not throw; whether it is SEEN needs a desktop)"
TP_TITLE="צינור התמלולים" TP_MSG="בדיקה" sched -Action notify-test; nrc=$?

echo "SCHEDULER: ran via ${RESULT:-NOTHING}; uninstall rc=$urc; status-after rc=$src; notify-test rc=$nrc"
[ -n "$RESULT" ] && [ "$urc" = 0 ] && [ "$src" != 0 ]
