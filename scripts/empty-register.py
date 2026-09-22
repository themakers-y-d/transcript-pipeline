#!/usr/bin/env python3
"""empty-register.py — the bounded retry for meetings that come back under the floor.

THE PROBLEM THIS EXISTS FOR
    A meeting whose transcript comes back shorter than the consumer's blip floor is genuinely
    ambiguous, and the two readings want opposite handling:
      - a BLIP: four seconds of nothing, "No meaningful audio recorded". Permanently empty.
        Retrying it every night forever is pointless.
      - a LAG: the transcription service had not finished when the producer asked. Retrying tomorrow
        is exactly right and it will succeed with nobody involved.
    They are indistinguishable at the moment of the fetch. The only thing that separates them
    is TIME, so the honest answer is to keep asking a bounded number of times and then decide.

    Before this file existed, an under-floor body was counted as a failed upload. That turned
    the run red, and because the meeting was never recorded anywhere it was re-fetched the next
    night, went under the floor again, and went red again — every night, forever. A permanent
    red teaches the owner to ignore the light within a week, which destroys the one thing the
    watchdog was built for. A failure that cannot clear is worse than no alarm at all.

THE REGISTER
    <register> holds one row per meeting seen under the floor, tab separated:

        meeting_id <TAB> status <TAB> count <TAB> first_seen <TAB> last_seen

      status   pending — still being retried, count is how many consecutive under-floor fetches
               blip    — retired. Permanently empty as far as this pipeline is concerned, and
                         excluded from every future worklist so it is never fetched again.
      count    consecutive under-floor fetches. A run that never happened does not count: the
               bound is on times we actually ASKED, not on days that passed.
      dates    YYYY-MM-DD, local.

    A meeting that later comes back WITH a transcript has its row deleted, so the count is
    consecutive by construction and a one-off lag leaves no residue.

    The file sits beside the state file in the kit folder, so where it lives follows the kit.
    On the plain install the kit is OUTSIDE the vault and this file is not in the vault's git
    history at all, which is fine: a vault restore cannot reset what the vault never tracked.
    On the MAKERS install the scripts live inside the vault and it is committed with the state
    file. It is safe to hand-edit either way: delete a row to put that meeting back in the
    worklist.

WHY THE COUNT IS NOT ALSO THE ALARM
    Retiring a meeting is a decision made without a human, so it must leave something a human
    can find. Three traces, on purpose: the row here, a loud RETIRED line in the run log, and a
    <warn-file> the watchdog reads and shows as 🟡 for three mornings. Not a notification — a
    four-second recording being retired does not deserve to interrupt anyone.

WHAT RAISES THE WARNING, AND WHAT DELIBERATELY DOES NOT
    A meeting under the floor for the FIRST time is normal and silent. It is written down and
    retried, and most of them resolve or retire without anyone needing to know. A warning on
    every short recording would be the same alarm fatigue in a quieter colour.
    The warning is raised only when:
      - a meeting has been under the floor 2+ consecutive fetches, so it is genuinely stuck and
        is on its last chance, or
      - a meeting was retired within the last RECENT_DAYS days.
    Both conditions expire on their own, so this warning cannot become permanent either.

USAGE
    empty-register.py blips  <register>
        Prints one blip meeting id per line. Nothing when the register is missing. Exit 0.
        This is the single place that knows the file's format; the caller never parses it.

    empty-register.py update <register> <under-floor-ids> <resolved-ids> <limit> <warn-file>
        Applies one run to the register and rewrites or removes <warn-file>.
        <under-floor-ids> and <resolved-ids> are files of one meeting id per line; either may be
        missing or empty, which means "none this run". Running with both empty is valid and is
        how the warning ages out on a quiet night.
        Prints RETIRED / PENDING / RESOLVED lines, then one final line:
            REGISTER_RESULT changed=<n> pending=<n> blips=<n> retired_now=<n>

    Exit 0 unless the register itself cannot be written. This never fails a sync run: the caller
    treats an error here as "no register data" and carries on uploading, which is the old
    behaviour and the safe direction.
"""
import os
import sys
import time
from datetime import date, timedelta

RECENT_DAYS = 3   # how long a retirement keeps showing in the morning banner before it ages out

HEADER = [
    "# transcript-uploader under-floor register. One meeting per line, tab separated:",
    "#   meeting_id  status  count  first_seen  last_seen",
    "# status=pending  still retried nightly; count is consecutive under-floor fetches.",
    "# status=blip     retired as permanently empty. Never fetched again.",
    "# Safe to hand-edit: delete a row to put that meeting back in the worklist.",
]


def read_register(path):
    """Rows as a dict id -> [status, count, first_seen, last_seen], preserving file order.
    A malformed row is dropped rather than crashing the run: this file is hand-editable by
    design, and a stray line must not be able to stop the night's sync."""
    rows, order = {}, []
    try:
        with open(path, encoding="utf-8") as f:
            for ln in f:
                ln = ln.rstrip("\n")
                if not ln.strip() or ln.lstrip().startswith("#"):
                    continue
                cols = ln.split("\t")
                if len(cols) < 5 or not cols[0].strip():
                    continue
                mid, status, count, first, last = (c.strip() for c in cols[:5])
                if status not in ("pending", "blip"):
                    continue
                try:
                    n = int(count)
                except ValueError:
                    continue
                if mid not in rows:
                    order.append(mid)
                rows[mid] = [status, n, first, last]
    except OSError:
        pass
    return rows, order


def write_register(path, rows, order):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        for h in HEADER:
            f.write(h + "\n")
        for mid in order:
            status, n, first, last = rows[mid]
            f.write(f"{mid}\t{status}\t{n}\t{first}\t{last}\n")
    os.replace(tmp, path)


def read_ids(path):
    try:
        with open(path, encoding="utf-8") as f:
            return [ln.strip() for ln in f if ln.strip()]
    except OSError:
        return []


def parse_day(s):
    try:
        y, m, d = (int(x) for x in s.split("-"))
        return date(y, m, d)
    except Exception:
        return None


def cmd_blips(register):
    rows, order = read_register(register)
    for mid in order:
        if rows[mid][0] == "blip":
            print(mid)
    return 0


def cmd_update(register, under_floor_file, resolved_file, limit, warn_file):
    today = date.today()
    today_s = today.isoformat()
    rows, order = read_register(register)

    under = read_ids(under_floor_file)
    resolved = read_ids(resolved_file)
    changed = retired_now = 0

    # A meeting that uploaded is no longer under the floor. Drop its row so `count` can only
    # ever mean CONSECUTIVE sightings, and a meeting that was late once does not carry a mark.
    for mid in resolved:
        if mid in rows:
            del rows[mid]
            order = [m for m in order if m != mid]
            changed += 1
            print(f"RESOLVED {mid} (was under the floor, now has a real transcript)")

    for mid in under:
        if mid in rows and rows[mid][0] == "blip":
            # Already retired, so it should never have been fetched. Say so rather than
            # silently re-counting: it means the worklist exclusion did not hold.
            print(f"WARN {mid} is already retired as a blip but was fetched again — "
                  f"the worklist exclusion did not apply")
            continue
        if mid in rows:
            rows[mid][1] += 1
            rows[mid][3] = today_s
        else:
            rows[mid] = ["pending", 1, today_s, today_s]
            order.append(mid)
        changed += 1
        n = rows[mid][1]
        if n >= limit:
            rows[mid][0] = "blip"
            retired_now += 1
            print(f"RETIRED {mid} as a permanently empty recording after {n} consecutive "
                  f"under-floor fetches (first seen {rows[mid][2]}). It will not be fetched "
                  f"again. To undo, delete its line from {register}")
        else:
            print(f"PENDING {mid} under the floor {n}/{limit} — retried on the next run")

    if changed:
        write_register(register, rows, order)

    pending = sum(1 for m in rows if rows[m][0] == "pending")
    blips = sum(1 for m in rows if rows[m][0] == "blip")

    # --- the watchdog's advisory ---
    stuck = sum(1 for m in rows if rows[m][0] == "pending" and rows[m][1] >= 2)
    cutoff = today - timedelta(days=RECENT_DAYS)
    recent = 0
    for m in rows:
        if rows[m][0] != "blip":
            continue
        d = parse_day(rows[m][3])
        if d is None or d >= cutoff:
            recent += 1

    parts = []
    if stuck:
        parts.append(f"{stuck} פגישות חוזרות ריקות מוישפר וממשיכות להיבדק")
    if recent:
        parts.append(f"{recent} פגישות נרשמו כהקלטות ריקות ולא ינוסו שוב")
    if parts:
        msg = ", ו".join(parts) + f". הרשימה המלאה: {register}"
        tmp = warn_file + ".tmp"
        try:
            os.makedirs(os.path.dirname(warn_file), exist_ok=True)
            with open(tmp, "w", encoding="utf-8") as f:
                # An epoch of its own, so the reader can ignore a warning nobody refreshed.
                f.write(f"warn={int(time.time())}\n{msg}\n")
            os.replace(tmp, warn_file)
        except OSError as e:
            print(f"WARN could not write {warn_file}: {e}", file=sys.stderr)
    else:
        # Nothing stuck and nothing retired recently: remove the advisory rather than leave a
        # stale one. A yellow that outlives its reason is the same disease as a stuck red.
        try:
            os.remove(warn_file)
        except OSError:
            pass

    print(f"REGISTER_RESULT changed={changed} pending={pending} blips={blips} "
          f"retired_now={retired_now}")
    return 0


def main(argv):
    if len(argv) >= 3 and argv[1] == "blips":
        return cmd_blips(argv[2])
    if len(argv) == 7 and argv[1] == "update":
        try:
            limit = int(argv[5])
        except ValueError:
            print("update: <limit> must be a number", file=sys.stderr)
            return 2
        if limit < 1:
            print("update: <limit> must be at least 1", file=sys.stderr)
            return 2
        return cmd_update(argv[2], argv[3], argv[4], limit, argv[6])
    print(__doc__.split("USAGE", 1)[1].strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
