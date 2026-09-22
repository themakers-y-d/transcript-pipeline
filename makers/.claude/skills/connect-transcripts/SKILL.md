---
name: connect-transcripts
description: מחבר את צינור התמלולים. Connect this MAKERS system to the owner's recorded meetings, so every meeting they have lands in the team's memory on its own, twice a day, without them copying anything. Use this whenever the owner says "תחבר לי את התמלולים", "אני רוצה שהצוות ישמע את הפגישות שלי", "תוסיף לצוות את המתעד", "תפעיל את צינור התמלולים", "connect my meetings", "I want the team to hear my calls", or hands over a Wispr Flow account and asks for it to feed the system. Always use this instead of writing the scripts or the scheduled jobs by hand, because this installs two jobs that run unattended and write into the owner's own files, and every safety gate that makes that survivable lives in here. Different from /connect-a-tool, which registers a tool the owner already owns; this one installs running machinery. Different from /absorb-transcript, which is the protocol a transcript goes through once it has arrived.
---

# Connect the transcripts

Owner: the Vibecoder. This installs machinery that runs unattended and writes into `1-me/` and `4-learned/`, which is the highest-consequence thing anyone installs in this system.

Work at low freedom. Follow the steps in order and stop where a step says stop.

## 0. Open the reference before you touch anything

> [!danger] Read `2-makers/vibecoder/refs/transcript-infrastructure.md` in full, first.
> It is what must EXIST and why, complete enough to rebuild the pipeline from nothing. The scripts you are about to install are a proven implementation of it — **but they are the implementation, not the authority.** The moment something on this machine does not fit them, that file is what you reason from.

Nothing below repeats it. These are the steps; the mechanics and every reason are there.

## 1. Say what this is, in one line, and get an answer

> *"זה מחבר את הפגישות שלך למערכת. כל מה שנאמר בהן נכנס לזיכרון של הצוות פעמיים ביום, לבד. אני מתקין, ומראה לך ריצה אמיתית אחת לפני שזה נשאר דלוק."*

Then name what it costs and **stop for their answer**: a **Claude subscription** (the two scheduled jobs run the CLI and draw on it), a **Wispr Flow subscription**, a Google account, and a Mac that is awake at the scheduled hour.

⛔ **And say plainly where their words go.** Wispr transcribes and Google Drive stores, both under their own accounts, with no service of ours in between. **That is not "everything stays on your machine", and claiming it would be false** — the bonus page says so in those words, and a skill that contradicts the page is the version they will believe.

## 2. Check this is a MAKERS vault, and stop if it is not

`CLAUDE.md`, `2-makers/morty/morty.md` and `4-learned/state.md` must all exist here. If any is missing, say plainly that this is not their MAKERS folder and stop before touching anything.

## 3. Preflight: discover, never assume

Everything in this step is a finding you report, not a value you carry in from somewhere else.

**The MCP tool-name prefixes.** Print the real tool names available right now and read the prefixes off them. A wrong prefix blocks the tool silently.

**The Claude binary.** Confirm the scripts resolve it on this machine.

**Git on the vault.** The absorber refuses to run without a restore point.

**The Drive folder.** If they have no folder for this, have them create one and take its id from the URL. If they do, take the existing one — and check what else is in it, because the liveness test assumes nothing else writes there.

## 4. Stop for a yes on exactly three things

Everything else you do yourself.

1. **`git init` in the vault**, if it is not already a repo. It is a change to their machine.
2. **Turning on the Google Drive connector** at claude.ai, and signing in to Wispr Flow. Both are theirs to click; you cannot.
3. **The first `launchctl` line**, if the terminal asks for it. Hand it as one self-contained line that prints something whatever happens.

## 5. Check what is already here, because most of it is

**Nothing is downloaded in the normal case.** This system ships with the whole pipeline in the vault already, dormant:

```
.claude/scripts/transcript-uploader.sh      the producer
.claude/scripts/transcript-absorber.sh      the consumer
.claude/scripts/build-parts.py              measures and splits, outside the model
.claude/scripts/empty-register.py           the bounded retry for empty recordings
.claude/scripts/config.example.sh           the values, with the reason for each
2-makers/scribe/                            the maker that reads what arrives
2-makers/vibecoder/refs/transcript-infrastructure.md   why each of the above exists
```

**Confirm all seven are there.** If they are, there is nothing to install and you are configuring, not building — go to step 6.

**If they are missing**, this vault predates the pipeline. Clone the kit outside the vault, run `python3 makers/apply-to-vault.py "<their MAKERS folder>"`, and it places all of the above and applies the edits a new maker needs in files the vault already has. It is idempotent, it never overwrites a file the owner has edited, and **it stops rather than guessing if an anchor is missing** — which means their vault is a version the payload was not written against, so you read that file and place the line by hand. **The clone is then deletable.**

**Either way the machinery ends up in the vault, and that is the point.** Ledgers and heartbeats land beside their script, so inside the vault they are in git — versioned, revertable, and survivable. Outside it they are on their own, and a ledger that is lost re-uploads every meeting the owner ever recorded.

## 6. Fill the config, and understand two values before you do

`.claude/scripts/config.example.sh` → `.claude/scripts/config.sh`. Every value carries its reason in the example file itself, and `INSTALL-MAKERS.md` in the kit repeats them with the MAKERS-specific ones filled in. Two of them carry the design:

**`OWNED_PATHS`** is the list of paths the run may commit. A permission, not an inventory. ⛔ **`4-learned/state.md` is not on it and never goes on it** — see the reference for what the ceiling is and why a twice-daily job breaks it.

**`MIN_TRANSCRIPT_CHARS`** is read by both scripts from one place. A second copy of it drifts, and the drift shows up as documents landing in the folder that the absorber then throws away on sight.

## 7. Seed the ledgers before the first run

```
SEED_ONLY=1 bash .claude/scripts/transcript-absorber.sh
```

Writes down everything already in the folder as handled, absorbs nothing, writes nothing to the vault. **Without it the first scheduled run absorbs their whole history in one night.**

The uploader has its own guard and refuses to start on an empty ledger. Override it exactly once, after they have seen and agreed, or their entire meeting history uploads into a folder someone else may read.

## 8. Prove it with a real run, and check four things

Delete **one** id from the absorber's ledger by hand and run it once. The ledger's own header says that is how you force a re-absorb.

> [!danger] Nothing is reported as connected on the strength of a job that loaded and a script that exited zero.
> A green exit code is not proof. A run that never reached the source exits green too.

1. a dated report appeared in `3-work/now/transcript-absorption/`
2. it carries open numbers and confidence tags — **neither means the gates did not run**
3. `4-learned/state.md` is **unchanged**, and the proposals are in `_process/proposed-rules.md`
4. `git log -1 --stat` shows a commit holding only that run's own paths

## 9. Schedule, register, and check

Load the two jobs from the kit's `launchd/` templates, pointing at the vault's script paths. The uploader first, the absorber at least half an hour later.

Add the row to `tools.md` following `/connect-a-tool`: what it is, what it can do, that it **writes**, the date, and how to switch it off.

**Then run `/check-the-system` yourself and see it pass.** The proof is your job, not a question the owner had to ask.

## 10. Tell them what now happens, and how to stop it

Four short lines, in their language, with no file names they do not need:

- their meetings reach the team twice a day, on their own
- the team **proposes** standing rules and never writes them into the list that loads every session
- anything a run did is undone with one line, and you give them that line
- switching it off is two `launchctl bootout` commands and deleting two files, and **nothing about it is irreversible**

## The one hard rule

> [!danger] Never report this as connected on the strength of a loaded job and a zero exit code.
> The one thing that proves it is a real meeting that reached a real file, read with your own eyes. A pipeline that looks installed and is not is worse than none: the owner stops taking notes, believing the system is listening.

## Input and output

**In:** `2-makers/vibecoder/refs/transcript-infrastructure.md`, the kit's `INSTALL-MAKERS.md`, the owner's Wispr and Drive access, this vault.

**Out:** the scripts and their config in `.claude/scripts/`, two loaded scheduled jobs, one proven end-to-end run with its report on disk, a row in `tools.md`, and the Scribe reachable from both its doors.

## The signal you see

A dated report in `3-work/now/transcript-absorption/` from a meeting the owner actually had, and a commit whose diff holds only the paths that run was entitled to touch.

## Where it breaks

It breaks when the seed step is skipped and the owner's entire meeting history uploads overnight into a folder someone else may read.

It breaks when the scripts are left running from the cloned repo, and their ledgers sit outside git — so a lost ledger re-uploads every meeting the owner ever recorded, and the owner cannot see or stop machinery that is not in the folder they open.

It breaks when `4-learned/state.md` is left writable and the standing list is full of meeting weather within a fortnight.

And it breaks when it is reported done off a loaded job, which the owner only discovers weeks later, asking the team about a meeting it has never heard of.

## Delete test

Delete this skill and connecting the pipeline becomes a hand-build every time: a different folder path, a forgotten seed step, ledgers left outside git, and no reason written down for why the standing list is off limits. The gates that make an unattended write survivable are exactly the ones a hand-build leaves out.
