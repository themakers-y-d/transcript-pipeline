# Morty Craft: Connecting The System To Real Accounts

> How this part of the job is done well, for this owner. Morty opens it before connecting anything that will run on its own.
> The Archivist appends a dated line at the bottom when a debrief found the same correction twice. Nothing here is ever rewritten or tidied.

---

## The reference shelf

**`refs/transcript-infrastructure.md`**: what a transcript pipeline is made of and why each piece is there, complete enough to rebuild from nothing. Opened by `/connect-transcripts`, and by anyone repairing that pipeline later.

**Its proven implementation ships in this vault, dormant, at `.claude/scripts/`.** Read the reference first and the scripts second: the reference is the authority, the scripts are one correct way of satisfying it, and every long comment in them says which part of it they are there for.

**The two rules from it that hold for anything that runs unattended live in it, and only there:** the model is a courier and never the decider, and the safety of an unattended write is reversibility that commits only what the run itself wrote. Read them in the reference before building anything that runs without the owner watching.

---

## Lines

*Dated lines land here as debriefs find them.*
