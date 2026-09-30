---
name: check-the-system
description: Scan the whole system for the silent failures — a file pointing at something that no longer exists, an agent nobody can reach, a skill no agent file names, a profile section still empty. Use this whenever the owner says "תבדוק שהכל תקין", "תרוץ בדיקה על המערכת", "עשיתי סדר בקבצים", "העברתי קבצים", "run a checkup", "is my system healthy", and always after anything was renamed, moved or deleted. Different from /explain-the-system, which answers a person looking at a symptom, this one scans every file and reports counts. Always run it after adding an agent or a skill — a broken reference returns nothing and reports nothing, which is why it survives for months.
---

# Check the system

Owner: Rick.

Run this after any rename, move or deletion, and any time something feels off without an obvious cause.

The failures this catches do not announce themselves. A file pointing at a path that no longer exists returns nothing, the agent carries on without it, and the output is quietly worse. Nobody sees a message.

## The checks

Run all of them and report every one, including the ones that passed. A report listing only problems leaves the owner unsure whether the rest was examined.

**1. Dead paths.** Collect every file path mentioned across `CLAUDE.md`, `system.md`, `2-makers/`, `.claude/skills/` and `.claude/rules/`. Check each one exists. Report every miss with the file and line that names it.

**Three paths are born later and are not misses when absent**, so do not report them: a maker's `craft.md` and its `refs/`, which appear the first time there is something real to put in them, and `2-makers/_to-build.md`, which appears when the owner is first absorbed. Report them only when a file points at one **and** the thing that creates it has already happened.

**2. Unreachable agents.** Every maker file in `2-makers/` must appear in the team list inside `2-makers/morty/morty.md`. **This is the only list in the entire system that has to be kept in step with a folder, and it is deliberate:** without that line, an agent exists and is never routed to. Everything else here is discovered by looking, which is why nothing else can rot.

**3. Doors that lead nowhere.** Every file in `.claude/commands/` must point at something that exists — a skill folder in `.claude/skills/`, or a maker file in `2-makers/`. And every skill and every maker must have a command file, or it has no visible door.

Count it as `commands = skills + makers` and nothing else. Two makers also have a file in `.claude/agents/`, because they run in their own window; that is the same maker, not an extra door, and counting it twice makes the total disagree with the folder every time.

Check the pointer inside each command file, not just its name. A command whose target was renamed still appears in the menu and fails silently when someone picks it, which is worse than not appearing at all.

**4. Descriptions that will not fire.** Read each skill's `description`. Flag any that names no concrete trigger phrase, any that carries no Hebrew trigger, and any two whose triggers overlap enough that neither will reliably win.

**4b. Frontmatter that does not parse.** Open the block between the first two `---` lines of every file in `.claude/skills/`, `.claude/commands/` and `.claude/agents/`, and check it is valid YAML. **The common break is a colon followed by a space inside an unquoted description** — `"Finished words in your voice: a post"` — which silently truncates the description to the words before the colon, or drops it entirely. The file still looks perfect in an editor. Use a dash or a comma instead, or wrap the whole value in quotes. Report every file whose description does not survive parsing, because a description that does not survive is a skill the model can no longer find.

**5. The two files that must load.** Confirm `CLAUDE.md` still imports `1-me/summary.md` and `4-learned/state.md`, and that both files exist. This is the spine — when an import points at nothing, the system greets the owner as a stranger and gives no sign that anything is wrong.

**6. Empty profile.** Count the bracketed sections left across the five `1-me/` files. Report the number and name them. Brackets are not errors, they are unfinished business, and the count is the honest measure of how well the system knows this owner.

**7. Standing rules.** Count the bullets in `4-learned/state.md` against its ceiling of 25 rules, ignoring headings and the preamble, and check that nothing in it contradicts anything else in it. Two rules that disagree mean one gets picked arbitrarily, and neither the owner nor the team can predict which.

**7b. Skills nothing reaches for.** Every skill in `.claude/skills/` must be named inside the file of the agent that owns it, or inside `CLAUDE.md` for the ones that run before any agent does. A skill nothing names still fires when its description matches, but the team never reaches for it deliberately, which is most of what it was written for.

**7c. Rooms.** Every numbered folder at the top level must carry a `README.md` with all six fields: what it is for, what is kept there, what is not kept there and where that goes instead, who writes there, when it loads, and the delete test. Report a room missing the file or missing a field, and report any unnumbered folder at the top level other than `.claude`. The five shipped rooms are a closed set for most owners; a sixth is legitimate but it is the one addition that changes the shape of the system, so it is checked rather than assumed.

**7d. Library material nothing reaches for.** Every folder in `5-library/` **except those beginning with an underscore** must be pointed at from at least one maker's `craft.md`. Report any that is not, and name it. `_reading/` is the owner's own shelf and is never flagged — nothing is meant to point at it. Material nobody was sent to is a pile rather than knowledge, and this room is the one place in the system where a pile can form quietly. Report the room's size too, as a count of folders, so the owner sees it growing.

**7e. The reply rule.** Confirm `CLAUDE.md` still carries its section on how every reply is written. **It is the only thing shaping how the whole team talks to the owner**, and if it goes, every maker quietly falls back to answering like a general assistant — longer, flatter, and full of process narration. Nothing else in the system would report that.

**8. Maker folders.** Every entry in `2-makers/` other than files beginning with an underscore must be a folder containing a file named after it. The underscore files are the two `_new-agent` templates and, once the owner has been absorbed, `_to-build.md`. Report any loose `.md` sitting directly in `2-makers/` — a maker outside its own folder breaks the moment it grows one.

**8a. Two doors per maker.** Every maker folder needs a line in the team table inside `2-makers/morty/morty.md` **and** a file at `.claude/commands/<name>.md`. Report either one missing, and say which. The table is how Morty reaches the maker; the command file is how the owner reaches it by typing `/`. A maker with only the table works but is invisible in the menu, and a maker with only the command is never routed to. **Morty is the one exception and needs no line in its own table**, because it is the thing doing the routing.

**8a2. Ghosts of removed makers.** Every line in Morty's team table, every file in `.claude/commands/`, and every maker named inside another maker's file must correspond to a folder that exists in `2-makers/`. Report the reverse of check 8a: a door or a routing line pointing at a maker that is gone. This is what a half-finished removal leaves behind, and pressing that button fails in a way nothing explains.

**8b. Craft size.** Report the line count of every `craft.md`, and for anything past 150 lines say it is worth a read rather than that it is due to be split. **Length alone is not a fault.** A file is only due to split when one subject has taken over a run of lines, and that is a judgement made by reading it, not a number. Report the count and leave the decision to whoever opens it.

**8c. Orphan refs.** Every `refs/` folder must sit inside a maker folder and be pointed at from that maker's `craft.md`. Material nothing points at is material nothing opens.

**8d. Craft boundaries.** Every maker file must carry a line near the top naming what it does not do, in the owner's words — *"It does not design what it wrote, and it does not distribute it."* Report any maker without one, and name it. **This is the line `/final-pass` opens before every deliverable**, to decide whether the work was that maker's to produce, so a maker missing it has no boundary at all and the check that should catch a swallowed job has nothing to compare against. Flag a boundary that names no other maker and no real craft, because a line that refuses nothing specific passes everything.

**9. Numbered files.** No file in `2-makers/` may begin with a digit. A number is a position in a list, and this folder is built to grow for years — the tenth maker breaks any numbering scheme that looked tidy with nine.

**10. The drop zone.** Report how many files sit in `3-work/in/` beyond its README. Anything there was dropped and never filed, which means a session used it and left it, or nobody has looked. It is not an error, it is a number the owner should see.

**11. Project folder names.** Every folder in `3-work/now/` and `3-work/done/` must be lowercase English with hyphens, carrying no date and no number. Report any that are not. A path that breaks a link or a git operation does so silently, and the owner reads it as the system being flaky.

**12. Deliverables buried, or reasoning lost.** In each project folder, check two things: that the top level holds finished things rather than drafts and transcripts, and that anything on the way is in `_process/`. A project with six files at the top level and no `_process/` means a chain ran and left no trail.

**13. Twin projects.** List the folder names in `3-work/now/` and `3-work/done/` and flag any two that plainly refer to the same thing — `ronit` beside `proposal-for-ronit`. Splitting one project across two folders is the failure that makes this room stop being worth opening, and it is invisible until someone reads the names side by side.

**14. The snapshot files.** Report the last-modified time of `1-me/summary.md` and `4-learned/state.md` against the newest entry in `4-learned/log.md`. A profile edited by hand more recently than anything the system recorded means the owner changed something themselves and no session has taken it in. Not an error, but the one place a hand edit can sit unnoticed.

**15. Makers nothing has accumulated on.** For each maker in `2-makers/`, report whether anything has gathered around it: a `craft.md`, a `refs/`, or its name appearing in `4-learned/log.md`.

**Skip the finding while `4-learned/log.md` holds fewer than five dated entries**, and say in one line that it was skipped and why. Three makers ship with a craft file and six without, so running it in week one reports the shipped state as a fault — but a check that silently disappears is indistinguishable from one that never ran.

Past that, a maker carrying nothing is one of two things and only the owner knows which: work going well enough that nobody has ever had to correct it, or a maker that has never once been called. **Name them and ask which.** An unused maker is the most common dead weight in a system like this, and `.claude/rules/team.md` holds the three deletions that removing one takes.

⛔ **Never report a maker as unused.** Nothing in this system records which maker produced which file — deliverables are named for the stage, never for the maker — so this check sees accumulation and nothing else. Absence of accumulation is not absence of use, and telling an owner to drop a maker they rely on weekly costs far more than the clutter it would save.

## Report like this

One line per check, each with a count. Then the detail for anything that failed, with the exact file and line. Then **one** recommended next action — the single most valuable fix, not a list.

## The one hard rule

Fix nothing during the scan.

Report, then ask. A checkup that silently repairs things teaches the owner nothing about their own system and hides how it drifted. The exception is a fix the owner explicitly asks for after seeing the report, and then it is done one at a time with each change named.

## The signal you see

A count for every check, whether or not anything was wrong. A report that only appears when there is a problem is indistinguishable from a check that never ran.

## Where it breaks

It breaks when it checks only what it happens to open, rather than every path in every file. It breaks when it reports a problem without the file and line, which leaves the owner hunting. And it breaks when it quietly fixes things, which is how a system drifts and looks healthy at the same time.

## Delete test

Delete this skill and every rename becomes a slow leak. Files keep pointing at things that moved, agents keep reading nothing, and the whole system degrades without a single error message. The owner concludes it is getting worse for no reason, and stops trusting it.
