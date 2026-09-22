#!/usr/bin/env python3
"""build-parts.py — turn fetched transcript bodies into ready-to-upload documents.

WHY THIS IS NOT IN THE PROMPT
    Every decision in here used to be asked of the model, and every one of them drifted.
    It counted the meetings it had seen and reported a number that moved by two depending on
    whether it counted subfolders. It measured a body's length by eye and recomputed the part
    count halfway through an upload, which is how a real meeting reached the shared folder
    labelled "חלק 3 מתוך 4" directly after "חלק 2 מתוך 3". A language model does not have a
    character counter, and asking it to behave as if it does produces confident wrong numbers
    that nobody downstream can tell from right ones.

    So the model fetches and the model writes; it never measures. Here, the part count P is
    computed ONCE, from the real character length, before a single document is created — and
    then it cannot change mid-upload, because nothing recomputes it.

WHAT IT DOES
    Reads the staging directory the fetch phase filled, and for each meeting in the worklist:
      - assembles the body by concatenating its numbered page files in order
      - refuses the meeting outright if BOTH its completion marker (done-<id>) and its
        empty-transcript marker (empty-<id>) are missing, which means the fetch did not finish
      - reports the meeting as UNDER-FLOOR, and builds nothing for it, when the assembled body
        is shorter than <min-chars> (see below)
      - splits the body into the fewest parts of at most SPLIT_CHARS characters, cutting ONLY
        at a line break between speaker turns, so no line and no word is ever cut
      - builds each part's header and its exact document title with plain string formatting
      - writes part-<id>-<i>-of-<P>.txt and one line per part into upload-manifest.tsv

    The concatenation of a meeting's parts, in order, equals its body exactly. The split is a
    size workaround, never an edit.

THE FLOOR IS THE CONSUMER'S NUMBER, NOT ONE OF OURS
    <min-chars> is passed in and is REQUIRED. It is deliberately not defaulted here: the only
    honest value is the consumer's own MIN_TRANSCRIPT_CHARS, the length below which
    transcript-absorber.sh calls a transcript an empty-audio blip and writes nothing. A second
    literal in this file could drift from it, and the drift would show up as documents landing
    in the partner's shared folder that the consumer then throws away on sight. The caller reads
    the number out of the consumer at run time and hands it here.

    Under-floor covers a 0-character body and a 256-character one with ONE rule, because they
    are the same fact from the consumer's side. It is a SOFT skip: the caller retries the
    meeting on later runs and only retires it after a bounded number of consecutive sightings.
    Nothing here decides that; this file only measures and reports.

USAGE
    build-parts.py <staging-dir> <split-chars> <min-chars> <iana-timezone>
    Prints one line per meeting to stdout: "OK <id> <P>" or "SKIP <id> <reason>".
    Also writes <staging-dir>/under-floor-ids.txt: one meeting id per line for every meeting
    skipped as under-floor, ALWAYS, even when empty. A machine contract, not a scrape of the
    text above — and its ABSENCE means this script never ran, which the caller treats as the
    old loud behaviour rather than as "nothing was under the floor".
    Exit 0 always unless the staging directory itself is unusable — a meeting that cannot be
    built is a reported skip, not a crash that takes the whole run down with it.
"""
import glob
import os
import sys
from datetime import datetime, timedelta, timezone

def load_zone(name):
    """The owner's real IANA zone, passed in rather than hardcoded. A FIXED UTC OFFSET IS
    WRONG FOR HALF THE YEAR, so the fallback is only ever reached when zoneinfo itself is
    unavailable, and it says so out loud rather than silently stamping the wrong hour on a
    document that lands in a shared folder."""
    try:
        from zoneinfo import ZoneInfo
        return ZoneInfo(name), ""
    except Exception as e:
        print(f"WARN: timezone '{name}' unavailable ({e}); header times fall back to UTC and "
              f"may be several hours off.", file=sys.stderr)
        return timezone(timedelta(hours=0)), " TIMEZONE-FALLBACK-header-time-may-be-wrong"

LOCAL_ZONE = timezone(timedelta(hours=0))   # replaced in main() by the configured zone
ZONE_NOTE = ""

NO_TITLE = "ללא נושא"
NO_SPEAKERS = "לא זוהו דוברים"


def local_dt(raw):
    """Parse whatever the meeting list carried as a start timestamp into the owner's local time.
    Returns None when there is nothing usable, and the caller falls back to the file's own
    date rather than inventing one."""
    if not raw or raw == "none":
        return None
    s = raw.strip().replace("Z", "+00:00")
    for candidate in (s, s.split(".")[0] + "+00:00" if "." in s else s):
        try:
            dt = datetime.fromisoformat(candidate)
        except ValueError:
            continue
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(LOCAL_ZONE)
    return None


def split_body(body, limit):
    """The fewest consecutive slices of at most `limit` CHARACTERS each, cut only at a line
    break. Characters, not bytes: Hebrew is two bytes per character in UTF-8, so counting bytes
    would halve the slice size and double the number of documents in the shared folder — and
    every extra part is one more document to duplicate when a retry re-uploads the meeting.

    A single line longer than the limit is emitted whole rather than cut. Overshooting the
    limit is recoverable; cutting a speaker mid-sentence is not."""
    lines = body.split("\n")
    parts, cur, cur_len = [], [], 0
    for ln in lines:
        add = len(ln) + (1 if cur else 0)
        if cur and cur_len + add > limit:
            parts.append("\n".join(cur))
            cur, cur_len = [ln], len(ln)
        else:
            cur.append(ln)
            cur_len += add
    if cur:
        parts.append("\n".join(cur))
    return parts or [""]


def main():
    if len(sys.argv) != 5:
        print("usage: build-parts.py <staging-dir> <split-chars> <min-chars> <iana-timezone>",
              file=sys.stderr)
        return 2
    staging, limit, min_chars = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    global LOCAL_ZONE, ZONE_NOTE
    LOCAL_ZONE, ZONE_NOTE = load_zone(sys.argv[4])
    if not os.path.isdir(staging):
        print(f"staging dir not found: {staging}", file=sys.stderr)
        return 2

    meta = {}
    try:
        with open(os.path.join(staging, "meetings.tsv"), encoding="utf-8") as f:
            for ln in f:
                cols = ln.rstrip("\n").split("\t")
                # Pad rather than require four fields. A meeting with an empty title is written
                # with no trailing tab, so its row has three fields — and demanding four threw
                # that meeting's START TIMESTAMP away with it, which silently sent a real
                # document to the shared folder headed 00:00 instead of 10:15. A parser that
                # drops a whole row over a missing last field fails in the one direction that
                # cannot be seen from the outside.
                if not cols or not cols[0]:
                    continue
                cols += [""] * (4 - len(cols))
                meta[cols[0]] = (cols[1], cols[3])
    except OSError as e:
        print(f"cannot read meetings.tsv: {e}", file=sys.stderr)
        return 2

    try:
        with open(os.path.join(staging, "worklist.txt"), encoding="utf-8") as f:
            worklist = [ln.strip() for ln in f if ln.strip()]
    except OSError as e:
        print(f"cannot read worklist.txt: {e}", file=sys.stderr)
        return 2

    manifest = open(os.path.join(staging, "upload-manifest.tsv"), "w", encoding="utf-8")
    under_floor = []
    for mid in worklist:
        # Two different statements from the fetch phase, deliberately kept apart:
        #   done-<id>   "I reached the transcript's END marker; what is on disk is WHOLE."
        #   empty-<id>  "I asked, and there is no transcript at all."
        # Without either, the pages on disk may be a prefix, and uploading a prefix is worse
        # than uploading nothing: it looks complete in the partner's folder forever. That is a
        # real failure and stays one.
        #
        # The empty marker is NOT folded into done-. Overloading one file with both meanings
        # would weaken the only guard against uploading half a meeting, to solve a problem that
        # a second file solves without touching it.
        done_marker = os.path.isfile(os.path.join(staging, f"done-{mid}.txt"))
        empty_marker = os.path.isfile(os.path.join(staging, f"empty-{mid}.txt"))
        if not done_marker and not empty_marker:
            print(f"SKIP {mid} no-completion-marker")
            continue

        pages = sorted(glob.glob(os.path.join(staging, f"body-{mid}-p*.txt")))
        body = ""
        for p in pages:
            with open(p, encoding="utf-8", errors="replace") as f:
                body += f.read()
        body = body.strip("\n")
        # The floor, in CHARACTERS, on the transcript body alone. A body under it is not a
        # failure and must never be counted as one: the meeting may be four seconds of nothing,
        # or the service may simply not have finished transcribing when we asked. Both look identical
        # from here, so this reports the fact and the caller decides how many nights to keep
        # asking before it calls the meeting empty for good.
        # Contradiction: the courier said "there is nothing here" and then wrote pages. Neither
        # statement about wholeness can be trusted, so this is an incomplete fetch and it is
        # loud. It should never happen; if it does, something about the fetch is wrong and
        # quietly picking one of the two answers would hide it.
        if empty_marker and not done_marker and body:
            print(f"SKIP {mid} empty-marker-but-body-present ({len(body)} chars) — contradictory fetch")
            continue

        if len(body) < min_chars:
            under_floor.append(mid)
            why = "courier reported no transcript" if empty_marker else f"floor {min_chars}"
            print(f"SKIP {mid} under-floor chars={len(body)} ({why})")
            continue

        speakers = NO_SPEAKERS
        sp_path = os.path.join(staging, f"speakers-{mid}.txt")
        if os.path.isfile(sp_path):
            with open(sp_path, encoding="utf-8", errors="replace") as f:
                cand = " ".join(f.read().split()).strip()
            if cand:
                speakers = cand

        raw_start, raw_title = meta.get(mid, ("none", ""))
        dt = local_dt(raw_start)
        # Say so when the timestamp is missing. The fallback puts a plausible-looking date and
        # 00:00 on a document in a folder a business partner reads, and a plausible wrong time
        # is invisible unless the run says out loud that it guessed.
        stamp_note = ""
        if dt is None:
            stamp_note = " NO-START-TIMESTAMP-header-time-is-a-guess"
        stamp_note += ZONE_NOTE
        d_str = dt.strftime("%d.%m.%Y") if dt else datetime.now(LOCAL_ZONE).strftime("%d.%m.%Y")
        t_str = dt.strftime("%H:%M") if dt else "00:00"

        title = " ".join(raw_title.split()).strip() or NO_TITLE
        title_short = title[:80]

        slices = split_body(body, limit)
        P = len(slices)
        for i, chunk in enumerate(slices, start=1):
            header = [
                "תמלול פגישה",
                f"תאריך: {d_str}",
                f"שעה: {t_str}",
                f"נושא: {title}",
                "מקור: Wispr Flow",
                f"דוברים: {speakers}",
            ]
            if P > 1:
                header.append(f"חלק {i} מתוך {P}")
            doc = "\n".join(header) + "\n\n" + "=" * 10 + "\n\n" + chunk + "\n"

            doc_title = f"תמלול פגישה {d_str} {t_str} | {title_short}"
            if P > 1:
                doc_title += f" (חלק {i} מתוך {P})"

            part_path = os.path.join(staging, f"part-{mid}-{i:02d}-of-{P:02d}.txt")
            with open(part_path, "w", encoding="utf-8") as f:
                f.write(doc)
            manifest.write(f"{mid}\t{part_path}\t{doc_title}\n")

        with open(os.path.join(staging, f"parts-{mid}.count"), "w", encoding="utf-8") as f:
            f.write(str(P))
        print(f"OK {mid} {P} chars={len(body)}{stamp_note}")

    manifest.close()
    # Written unconditionally, so an empty file means "measured, nothing under the floor" and a
    # MISSING file means "this script did not get that far". The caller must be able to tell
    # those apart, because reading the second as the first would quietly suppress a real failure.
    with open(os.path.join(staging, "under-floor-ids.txt"), "w", encoding="utf-8") as f:
        for mid in under_floor:
            f.write(mid + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
