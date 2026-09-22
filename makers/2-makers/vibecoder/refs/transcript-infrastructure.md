# transcript-infrastructure.md — what a transcript pipeline is made of, and why each piece is there

Reference for the Vibecoder. `/connect-transcripts` opens it before it builds anything, and anyone repairing the pipeline months later opens it first.

⚠️ **This is not an installation recipe, and it is deliberately not written as one.** A recipe works exactly as long as nothing deviates, and the first time something does — a tool renamed, a folder that already has files in it, a machine where the binary sits somewhere else — an agent following a recipe has nothing left to reason from.

**What is here is what must EXIST, and why each piece is there.** Read it and you can rebuild this from nothing. The scripts that ship with it are a proven implementation of exactly this, hardened by a year of real nights, and they are what you should install rather than retype. But they are the implementation, not the authority. This file is the authority.

---

## The shape: two halves, and a folder between them

**The producer** takes the meetings that were recorded and puts each one into a folder in the owner's Google Drive, one document per meeting.

**The consumer** scans that same folder, and for every document it has not seen before, runs the transcript protocol and writes what it learned into the owner's real files.

**The folder between them is not a detail, and it is the first thing to understand.** A direct pipe from the recorder into the vault would be simpler and it would be worse, for four reasons:

1. **The two halves fail independently.** A dead recorder connection does not stop absorption of what already arrived, and a broken absorption does not lose what was recorded.
2. **The owner can drop a file in by hand.** A recording from somewhere else, a transcript a client sent. It gets absorbed like any other.
3. **It is a durable store the owner can read.** They can open any meeting in Drive and see exactly what the system saw. There is no hidden intermediate state.
4. **It is what makes the dedup ledger meaningful.** A document in a folder has a stable id. A stream does not.

---

## The nine things that must exist

Miss any one and you have something that looks like a pipeline and is not. Each is written here as what it is, why it is there, and **what it looks like when it is missing** — because most of these fail silently, and the failure looks like everything being fine.

### 1. A folder that only holds transcripts

One folder in the owner's Drive, its id recorded in config. Direct children only; the consumer never recurses.

**Why its own folder:** the consumer's liveness check is "this folder is never empty once the producer has run, so zero documents means a dead connection." That check is only true of a folder nothing else writes to.

**Missing:** a scan that returns zero looks identical to a quiet week, and a dead connection goes unnoticed for as long as the owner does not happen to ask.

### 2. A producer that fills it, one document per meeting

Pulls the meetings not already recorded, and creates one Google Doc each. A meeting too long for one document is split into parts on a speaker or line boundary, **never mid-line**, with every part carrying the same header block and a part marker.

**Why one doc per meeting and not one per day:** Drive's API cannot append to an existing document, and a day-file would have to be rewritten. Rewriting is the one operation that can lose what is already there.

**Missing:** nothing arrives, and the consumer reports a correct, honest zero forever.

### 3. A dedup ledger for each side, written by the script and never by the model

One id per line, in a plain text file. The producer's holds meeting ids it has uploaded. The consumer's holds Drive file ids it has absorbed.

⛔ **The model reports which items it finished on a final parsed line. The wrapper is what writes them down.** This is not a style preference. A permission prompt, a crash or a confused run can then never mark an item done when it was not, and never leave a finished one unrecorded either.

**And the producer refuses to run on an empty ledger**, unless explicitly overridden once. An empty ledger makes every meeting look new, and the cost is a folder full of duplicates that the consumer then absorbs a second time, writing the same lessons twice into the owner's files.

**Missing:** either every meeting uploads again every night, or a meeting is marked done that never arrived. The second is the expensive one, because nothing will ever look for it again.

### 4. A consumer that runs a protocol, not a summariser

The protocol is `/absorb-transcript`, and it is the same one whether the run is unattended or the owner asked for it by hand. Its gates — length, contamination, room identification, decision versus discussion, the numeric check, the routing, the two craft gates — are doing the job the owner's eyes used to do.

**Why a protocol and not a prompt:** an unattended pass writes factual claims about real people into the owner's own record. Every gate is there because one of them failed once, and each failure is named in that file.

**Missing:** the system fills with confident summaries that nobody checked, and the first person to notice is the owner, months later, reading a claim about themselves that nobody ever said.

### 5. A restore point that does not sweep in open work

The safety model for an unattended write is not approval, it is reversibility.

⛔ **And the obvious implementation of that is wrong.** Committing the whole working tree before the run, under the name "restore point", sweeps in whatever the owner had open at that hour — and the documented undo then destroys their unfinished work along with the run's. **A restore point that can destroy work is not a restore point.**

**What is correct:** no commit is made up front at all. The restore point is the commit that is already HEAD. What the run wrote is worked out afterwards, by comparing a content-hash snapshot taken before the model started against the same snapshot taken after, and **only those exact paths are committed.**

**Three conditions decide staging, and all three must hold:**

1. the path's content changed during the run
2. it matches a pattern in the list of paths this pipeline is allowed to commit
3. it was **not** already dirty before the run started

**The third is the one that looks redundant and is not.** `git add <path>` stages the whole file and never the run's own lines, so a path that was already carrying somebody else's uncommitted work and was written to during the run passes both of the first two conditions and drags that work into a commit whose documented undo is `git revert`.

A path failing any condition is left in the working tree, named in the log, and counted in the heartbeat. It is not committed and it is not lost.

**Missing:** the first time the owner has two sessions open — which here is most days — an undo destroys an afternoon.

### 6. A list of paths the pipeline is allowed to commit

A permission, never an inventory. Anything the run writes outside it stays visible in `git status` rather than entering a commit.

⛔ **Never a whole-vault wildcard, and never a file the owner curates by hand.**

**Missing:** condition 2 above collapses into "everything that changed", and anything another session touched in the same twenty minutes rides into the pipeline's commit.

### 7. A separate verification that proves the source was actually read

A second, tiny run whose only job is to list the folder into a file. Then bash counts the file.

⛔ **The count must not come from the run being checked.** Reading `seen` out of the absorbing run's own final line is the model grading its own homework: the single number that decides whether the connection is alive comes from the thing whose failure it is supposed to catch. A run that never called Drive at all, and simply wrote a plausible number, passes.

**The number is a fact about the disk.** Count **distinct** ids, not lines: paginated listings overlap at page seams, and a duplicate must never be allowed to pad the count past a check that exists to catch a short read.

**Two assertions it makes possible, both free:** zero documents in a folder that is never empty means the connection is dead; and a listing **shorter than the ledger** means the listing is truncated, because nothing is ever deleted from that folder.

**Missing:** the most expensive failure in the whole system, because it reports success.

### 8. A heartbeat, and a watcher with a named reader

A run that stops starting cannot complain. No process, no error, no notification. **The only thing that catches it is age.**

So a success writes one dated line to a file inside the vault, and something reads that line at session open and says so when it has gone stale. A failure writes a distinct line and fires a desktop notification.

⛔ **A self-reported success is not a status.** The wrapper reads the real exit code. And **a red nobody reads is the normal outcome**: every alarm needs a named reader or it should be deleted.

**Missing:** a quiet stretch of meetings looks exactly like a dead pipeline, and the owner finds out when they ask the team about a meeting it never heard of.

### 9. An undo line, printed by the run itself

Every run that commits prints the exact command that reverts it, and the heartbeat carries it too. When paths were held back, the run says which and why, and that the revert will not reach them.

**Missing:** reversibility that exists in principle and that nobody can actually perform at the moment they need it.

---

## The one architectural rule: the model is a courier, not a decider

This is the rule the rest of the design follows from, and it was learned the expensive way.

**The producer used to be one prompt** that asked the model to search, count, filter, sort, cap, measure, split and upload. **Every decision in that list drifted, and the drift was invisible, because the model also reported the numbers the wrapper checked.**

What that actually cost, in one system, in thirteen nights:

- a reported count that moved by two depending on whether it counted folders, which the wrapper treated as an integrity check. It never was one.
- `failed=1` reported on nine nights out of thirteen, in a field the wrapper never read, so every run exited green while meetings were left behind
- filtering against a hardcoded window of the newest 25, so a meeting that failed often enough fell out of the window and became permanently invisible
- a part count recomputed mid-upload, which is how a shared folder came to hold a document labelled "part 3 of 4" directly after "part 2 of 3"

> [!danger] In unattended machinery, a deterministic decision is computed in code. The model is a courier and never the arbiter of what can be calculated.
> A count, a threshold, a limit, a filename, a set difference, a sort order. Deriving any of them inside a prompt is a bug with a plausible face, **because a model that miscounts does not fail, it reports.**

**What the model is still good at, and still does:** reading a transcript, naming who was in the room from what was said, judging whether something closed or was merely discussed, reaching the end of a paginated body, writing a line of craft. Those are judgement. Counting is not judgement.

**And it may classify only what the prompt has DEFINED.** Every outcome enumerated, the degenerate case named outright with its own signal. An empty recording that the prompt never described will be filed one way on Monday and the opposite way on Tuesday, by coin flip, and a bounded retry cannot help an item that lands in the wrong bucket at random.

**Every mechanism that softens an alarm must fail toward the old, loud behaviour.** If the piece that decides "this is a harmless empty recording" is missing or errors, an empty recording counts as a failure exactly as it did before that piece existed. A new mechanism must never be able to swallow a real failure by breaking.

---

## The producer, in four phases

The split exists so that no phase both decides and reports.

**Phase 1, the model enumerates.** One call, every meeting, one line each into a file. No filtering, no counting, no sorting. The prompt says so in those words, because a courier asked to be useful will start being helpful.

**Then bash decides.** `seen` is a line count. The worklist is a real set difference against the whole account, with `comm`, never a window of the newest N — **this single line is what makes a meeting that failed twelve nights running still eligible on the thirteenth, and what makes a double upload structurally impossible.** Order is a sort on the timestamp. The cap is `head`.

**The enumeration cap is computed from what is already known to exist**, with headroom and a floor, and it is passed in rather than written into the prompt. A number that exists only inside prompt text is a decision handed to the model: nothing can read it, test against it, or notice the day it stopped being big enough. Because it is a bash fact, bash can test whether the returned list is exactly as long as the cap — which is the classic truncation tell.

**Phase 2, the model fetches one meeting per invocation**, writing each page verbatim to its own numbered file as it receives it, and writing a completion marker **only** after reaching the end marker. One invocation per meeting means a failure is one meeting's failure.

**Then bash assembles, measures and splits.** The part count is computed once, from the real character length, before a single document is created — and then nothing can recompute it mid-upload. Characters, not bytes: Hebrew is two bytes per character, so counting bytes halves the slice and doubles the number of documents.

**Phase 3, one invocation per document**, handed the finished title and the finished text, with the create tool as its only tool. It cannot rename, renumber, merge or split, because none of those are still being computed by the time it is asked.

**Then bash records state.** A meeting counts only when **every** one of its parts was created. A partial failure retries the whole meeting from part 1 next run — a rare duplicate on retry, in exchange for the guarantee that a long meeting is never silently half-uploaded.

### The third outcome, which is the one people forget

A fetch has three outcomes, not two. It can succeed, it can fail, and it can **come back under the floor**: four seconds of nothing, or a transcript the service had not finished writing when asked. Those last two are the same thing at the moment of the fetch, and only time tells them apart.

Counting that as a failure produces **a red that can never clear**: the meeting is never recorded, so it is fetched again, comes back empty again, and goes red again, every night, forever. A permanent red trains the owner to ignore the light inside a week, and then the watcher is worse than nothing.

So under-the-floor is its own outcome, with its own register and a bounded retry: soft-skipped and retried for a small number of **consecutive fetches** — counted on times we actually asked, not on days that passed — then retired as permanently empty and never fetched again. Retiring is a decision made with nobody watching, so it leaves three traces: a row in the register, a loud line in the run log, and an advisory that expires on its own.

---

## The consumer, in three

**Read the folder, paginating to the end.** ⛔ **A first page is not the folder.** The newest documents come back first, so on a quiet day page one holds everything new and a single-page read looks perfectly correct. On a day that produced more new documents than fit on one page, **the ones that did not fit are absorbed nowhere** — and on the next run page one is full of items already in the ledger, so they never come back. They are not delayed, they are lost, and nothing reports it.

**Group multi-part meetings before any gate.** Documents whose titles share a base and end with a part marker are one meeting. Concatenate them into one body **before** the length, contamination or room gate, or one split meeting is judged as several separate rooms — and a middle part on its own is an hour out of three with no beginning and no end.

**Then run the protocol, write, and commit what the run itself wrote.**

**Truncation is real on long documents.** The read tool can return only the start of a long body. Compare what came back against the size in the metadata and paginate until the whole body is in hand. **Never classify on a partial body.**

---

## Where every fact goes

The routing table is filled in already, with real paths, in `2-makers/scribe/scribe.md` step 7. It is filled in because this owner's team already exists — there is nothing to guess at install time.

⛔ **The one destination that is not in it, and never will be: `4-learned/state.md`.**

That file is the standing list. It loads into every session, it steers the whole team, and it has a ceiling **because a list nobody can hold in mind stops steering anything.** A job running twice a day and appending bullets fills that ceiling inside a fortnight.

**So the pipeline writes the dated line to `4-learned/log.md` and proposes the standing rule.** The proposal goes in its report and into an accumulating file in the project's `_process/`, and the Archivist rules on it at the next debrief.

**Two guards, and both must be in place:**

1. `state.md` is **not** in the list of paths the pipeline may commit. Even a stray write stays visible in the working tree rather than entering a commit.
2. The run's own instructions say it outright, as a numbered step.

**And the law in the files was updated to match**, in `.claude/rules/records.md` and `4-learned/README.md`. A rule left on disk that contradicts the actual behaviour is a competing instruction that the next maker will trust.

---

## What cannot be known in advance

These are discovered on the machine, in preflight, and reported as what was actually found. **Never assumed.**

- **The exact MCP tool-name prefixes.** They depend on how each connector was added. Print the real tool names and read the prefixes off them. A wrong prefix blocks the tool silently.
- **Whether the connectors surface under a headless run** in this account, and whether a user-scoped MCP is visible to a scheduled job started from the vault.
- **Where the Claude binary is.** The editor extension path changes on every update, so resolve it at run time and fall back to the usual install locations.
- **The real size ceiling of one document creation call**, and proof that splitting solves a genuinely long meeting on this machine.
- **Whether the desktop notification appears under the scheduler** after the owner grants permission.
- **The producer's real finish times**, which is what the consumer's schedule is set from.

---

## What counts as built

> [!danger] Nothing here is reported as working until it has run once, end to end, on a real meeting, and the files it wrote have been read.
> A loaded scheduled job is not proof. A dry run is not proof. **A green exit code is not proof**, because a run that never reached the source exits green too.

Four things are checked, and all four:

1. a real document appeared in the folder
2. a dated report appeared in the project folder
3. the report carries open numbers and confidence tags — **if it carries neither, the gates did not run**
4. the commit holds only the run's own paths, and the printed undo command reverts exactly it

**And a structural change is not done until `/check-the-system` has been run and seen to pass.** The proof is the maker's job, not a question the owner had to ask.

---

## How to take it apart

Two `launchctl bootout` commands and deleting the two schedule files stops everything. The scripts and the ledgers can stay or go. Anything a run wrote is one `git revert` away, and the command is in the log and the heartbeat.

**The Scribe can stay in the team afterwards** and be handed a transcript by hand. Nothing about the pipeline is required for the protocol to run.

Nothing in this infrastructure is irreversible, and saying that out loud is part of installing it.
