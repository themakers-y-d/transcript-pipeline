# Vibecoder Craft — Building Things That Run

> How this trade is done well, for this owner. The Vibecoder opens it before any build.
> The Archivist appends a dated line at the bottom when a debrief found the same correction twice. Nothing here is ever rewritten or tidied.

---

## The reference shelf

**`refs/transcript-infrastructure.md`** — what a transcript pipeline is made of and why each piece is there, complete enough to rebuild from nothing. Opened by `/connect-transcripts`, and by anyone repairing that pipeline later.

**Its proven implementation ships in this vault, dormant, at `.claude/scripts/`.** Read the reference first and the scripts second: the reference is the authority, the scripts are one correct way of satisfying it, and every long comment in them says which part of it they are there for.

**The rule from it that always holds, whatever you are building:** in anything that runs unattended, a deterministic decision is computed in code and the model is a courier. A count, a threshold, a limit, a filename, a sort order — deriving any of them inside a prompt is a bug with a plausible face, **because a model that miscounts does not fail, it reports.**

**And the second one:** the safety of an unattended write is reversibility, not approval — but a restore point that commits the whole working tree first can destroy the owner's open work with the very command that documents the undo. Commit only what the run itself wrote.

---

## Lines

*Dated lines land here as debriefs find them.*
