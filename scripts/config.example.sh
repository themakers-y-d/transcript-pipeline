# shellcheck shell=bash
# config.example.sh, copy to config.sh and fill in for THIS machine.
# This file is sourced by the scripts, not executed, so it has no shebang.
#
# Claude fills this during install (see ../INSTALL.md, or ../INSTALL-MAKERS.md when the owner
# already has a MAKERS system). A non-technical owner never edits it by hand. Every value can
# also be overridden by an environment variable of the same name, which is what the launchd
# plists do.
#
# Nothing secret lives here. There are no tokens and no passwords: both scripts authenticate
# through the Claude Code CLI and its MCP connectors, which the owner authorizes once in a
# browser. Keep it that way, never paste a token into this file.

# --- The vault: the folder Claude Code opens, where the agents' memory lives ---
# Absolute path. This is the folder the absorber writes into and commits.
VAULT="${VAULT:-$HOME/CHANGE-ME-vault}"

# --- The Google Drive folder that holds the transcripts ---
# The folder id is the last path segment of the folder's URL in Drive:
#   https://drive.google.com/drive/folders/<THIS-PART>
DRIVE_FOLDER_ID="${DRIVE_FOLDER_ID:-CHANGE-ME-drive-folder-id}"

# --- MCP tool-name prefixes, DISCOVERED in preflight, never guessed ---
# The exact prefix depends on how each connector was added. The Google Drive connector added
# inside claude.ai is 'mcp__claude_ai_Google_Drive__'; a Drive added through a different MCP
# will have a different prefix. INSTALL tells Claude to print the real tool names first and
# paste the exact prefixes here.
WISPR_TOOL_PREFIX="${WISPR_TOOL_PREFIX:-mcp__wisprflow__}"
DRIVE_TOOL_PREFIX="${DRIVE_TOOL_PREFIX:-mcp__claude_ai_Google_Drive__}"

# --- launchd label prefix (identifies the two scheduled jobs) ---
LABEL_PREFIX="${LABEL_PREFIX:-com.example.transcript}"

# --- Timezone, as a real IANA zone name so daylight saving is handled ---
# Do NOT use a fixed UTC offset: it is wrong for half the year.
TIMEZONE="${TIMEZONE:-Asia/Jerusalem}"

# --- Long-meeting chunking ---
# The Drive create_file tool has a size ceiling far below Google Docs' own. A meeting whose
# text exceeds this many CHARACTERS is split into parts, one Google Doc per part. 40000 is
# proven safe for one create_file emission.
CHUNK_CHAR_LIMIT="${CHUNK_CHAR_LIMIT:-40000}"

# --- Batch caps: a backlog drains across runs, never in one burst ---
MAX_NEW_PER_RUN_UPLOAD="${MAX_NEW_PER_RUN_UPLOAD:-10}"
MAX_NEW_PER_RUN_ABSORB="${MAX_NEW_PER_RUN_ABSORB:-15}"

# --- Below this many characters a transcript is an empty-audio blip ---
# ONE number, read by both scripts. The uploader reads it from here rather than carrying its
# own literal, because a second literal would drift and the drift would show up as documents
# landing in the folder that the absorber then throws away on sight.
MIN_TRANSCRIPT_CHARS="${MIN_TRANSCRIPT_CHARS:-600}"

# --- How many CONSECUTIVE under-floor fetches before a meeting is retired as permanently empty ---
# Three, because the job runs nightly: three fetches span two to three days of real waiting,
# an order of magnitude more than a transcription lag of minutes to hours, and it survives the
# two hiccups that actually happen — one night the API answers short, and one night the Mac
# was asleep (a run that never happened does not count against the bound).
EMPTY_RETRY_LIMIT="${EMPTY_RETRY_LIMIT:-3}"

# --- Where the absorber's protocol file lives, RELATIVE TO THE VAULT ---
PROTOCOL_FILE="${PROTOCOL_FILE:-.claude/transcript-protocol.md}"

# --- Where the run's dated reports and its staging folders live, RELATIVE TO THE VAULT ---
REPORTS_DIR="${REPORTS_DIR:-transcripts/reports}"

# =====================================================================================
# OWNED_PATHS — the only paths this pipeline may COMMIT.
# =====================================================================================
# Three conditions decide whether a file the run wrote enters its commit, and this is the
# second of them: the path changed during the run, it matches a pattern here, and it was NOT
# already dirty before the run started.
#
# WHY IT IS NOT "everything that changed". A run writes for twenty minutes, and anything the
# owner or another session edited in that window also shows as changed. Committing those puts
# somebody else's unfinished work inside a commit whose documented undo is `git revert`, and
# the revert then destroys it.
#
# A write OUTSIDE this list is not committed and not lost: it stays in the working tree where
# `git status` shows it, which is the safe direction to fail in.
#
# One shell case-glob pattern per line, matched against paths relative to the vault root.
# Lines starting with # are ignored. ⛔ Never add a path the owner curates by hand and never
# add a whole-vault wildcard: the list is a permission, not an inventory.
OWNED_PATHS="${OWNED_PATHS:-
memory/*.md
$REPORTS_DIR/*
}"

# =====================================================================================
# EXTRA_PROMPT_FACTS / EXTRA_PROMPT_WRITE_RULES — the second door's injections.
# =====================================================================================
# Empty for a plain install. INSTALL-MAKERS.md fills them so the same absorber serves an owner
# who already has a MAKERS system, without the scripts forking into two versions to maintain.
# Two versions drifting apart is two products to keep alive; one script with two config files
# is one.
EXTRA_PROMPT_FACTS="${EXTRA_PROMPT_FACTS:-}"
EXTRA_PROMPT_WRITE_RULES="${EXTRA_PROMPT_WRITE_RULES:-}"
