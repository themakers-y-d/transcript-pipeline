#!/usr/bin/env python3
"""stub_claude.py - a stand-in for `claude -p`, for the portability suite only.

It never talks to a model. It reads the prompt the pipeline built, recognises which phase is
calling, and does what a well-behaved courier would: writes the files the prompt names and
prints the final line the wrapper parses. Every call is recorded, so two runs of the pipeline
(before and after a change) can be compared call by call.

It is a NATIVE program on purpose. On Windows the pipeline launches it through CreateProcess,
exactly as it launches claude.exe, so the 32,767-character command-line limit and the
/c/Users vs C:/Users path question are both real here. And it writes files in the platform's
text mode, so on Windows its files and its stdout carry CRLF, which is the worst case the
pipeline has to survive.

Invoked by a generated wrapper as: stub_claude.py <root> <claude args...>
  <root>/fixtures/meetings.tsv   what the Wispr enumeration returns
  <root>/fixtures/bodies/<id>.txt  one transcript per meeting; the word EMPTY means no transcript
  <root>/fixtures/docs.txt       what the Drive folder listing returns
  <root>/fixtures/absorb-done.txt  the ids the absorbing run reports as finished
  <root>/log/                    calls.log, prompt-N.txt, uploads.tsv
"""
import hashlib
import os
import re
import sys


def main():
    root = sys.argv[1]
    args = sys.argv[2:]
    prompt = args[args.index("-p") + 1] if "-p" in args else ""
    allowed = args[args.index("--allowedTools") + 1] if "--allowedTools" in args else ""
    turns = args[args.index("--max-turns") + 1] if "--max-turns" in args else ""
    fx = os.path.join(root, "fixtures")
    log = os.path.join(root, "log")
    os.makedirs(log, exist_ok=True)

    cnt_path = os.path.join(log, "counter")
    n = int(open(cnt_path).read()) + 1 if os.path.exists(cnt_path) else 1
    with open(cnt_path, "w") as f:
        f.write(str(n))

    if "search_meetings" in prompt:
        phase = "enum-meetings"
    elif "The meeting id is: " in prompt:
        phase = "fetch"
    elif "create_file tool EXACTLY ONCE" in prompt:
        phase = "upload"
    elif "_staging-enum/docs.txt" in prompt:
        phase = "enum-docs"
    elif "Read and follow the transcript protocol" in prompt:
        phase = "absorb"
    else:
        phase = "unknown"

    with open(os.path.join(log, "calls.log"), "a", encoding="utf-8", newline="\n") as f:
        f.write("%d\t%s\t%s\t%s\t%d\t%s\n" % (n, phase, allowed, turns, len(prompt),
                                            hashlib.sha1(prompt.encode("utf-8")).hexdigest()))
    with open(os.path.join(log, "prompt-%03d.txt" % n), "w", encoding="utf-8", newline="\n") as f:
        f.write(prompt)

    def fixture(name):
        with open(os.path.join(fx, name), encoding="utf-8") as f:
            return f.read()

    if phase == "enum-meetings":
        out = re.search(r"write the file (\S+meetings\.tsv)", prompt).group(1)
        with open(out, "w", encoding="utf-8") as f:          # platform text mode, on purpose
            f.write(fixture("meetings.tsv"))
        print("ENUM_DONE")

    elif phase == "fetch":
        mid = re.search(r"The meeting id is: (\S+)", prompt).group(1)
        staging = re.search(r"(\S+)/body-" + re.escape(mid) + r"-p001\.txt", prompt).group(1)
        body = fixture(os.path.join("bodies", mid + ".txt"))
        if body.strip() == "EMPTY":
            with open(os.path.join(staging, "empty-%s.txt" % mid), "w", encoding="utf-8") as f:
                f.write("EMPTY")
        else:
            lines, pages, cur = body.split("\n"), [], []
            for ln in lines:                                  # pages of about 30000 chars
                if cur and sum(len(x) + 1 for x in cur) + len(ln) > 30000:
                    pages.append("\n".join(cur))
                    cur = []
                cur.append(ln)
            pages.append("\n".join(cur))
            for i, pg in enumerate(pages, start=1):
                with open(os.path.join(staging, "body-%s-p%03d.txt" % (mid, i)), "w", encoding="utf-8") as f:
                    f.write(pg if i == len(pages) else pg + "\n")
            with open(os.path.join(staging, "speakers-%s.txt" % mid), "w", encoding="utf-8") as f:
                f.write("דובר 1, דובר 2")
            with open(os.path.join(staging, "done-%s.txt" % mid), "w", encoding="utf-8") as f:
                f.write("COMPLETE")
        print("FETCH_DONE " + mid)

    elif phase == "upload":
        title = re.search(r"^  title: (.*)$", prompt, re.M).group(1)
        body = prompt.split("-----BEGIN DOCUMENT TEXT-----\n", 1)[1].rsplit("\n-----END DOCUMENT TEXT-----", 1)[0]
        with open(os.path.join(log, "uploads.tsv"), "a", encoding="utf-8", newline="\n") as f:
            f.write("%s\t%d\t%s\t%s\n" % (title.replace("\r", "<CR>"), len(body),
                                          hashlib.sha1(body.encode("utf-8")).hexdigest(),
                                          "has-CR" if "\r" in body else "no-CR"))
        print("CREATED doc-%03d" % n)

    elif phase == "enum-docs":
        out = re.search(r"write the file (\S+docs\.txt)", prompt).group(1)
        with open(out, "w", encoding="utf-8") as f:
            f.write(fixture("docs.txt"))
        print("ENUM_DONE pages=1")

    elif phase == "absorb":
        done = fixture("absorb-done.txt").split()
        with open(os.path.join("memory", "profile.md"), "a", encoding="utf-8") as f:
            f.write("- נספג מהסטאב: %s\n" % " ".join(done))
        os.makedirs(os.path.join("transcripts", "reports"), exist_ok=True)
        with open(os.path.join("transcripts", "reports", "stub-report.md"), "w", encoding="utf-8") as f:
            f.write("# דוח\n\n%s [ודאי]\n" % " ".join(done))
        os.makedirs("notes", exist_ok=True)
        with open(os.path.join("notes", "not-owned.md"), "w", encoding="utf-8") as f:
            f.write("written by the run, outside OWNED_PATHS\n")
        print("working...")
        failed = 1 if os.path.exists(os.path.join(fx, "absorb-failed-1")) else 0
        print("TRANSCRIPT_RESULT seen=%d absorbed=%d skipped_existing=0 skipped_short=0 contaminated=0 failed=%d"
              % (len(fixture("docs.txt").splitlines()), len(done), failed))
        print("TRANSCRIPT_DONE_IDS " + " ".join(done))

    else:
        print("stub: unrecognised prompt", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
