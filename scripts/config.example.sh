# shellcheck shell=bash
# config.example.sh, copy to config.sh and fill in for THIS machine.
# This file is sourced by the scripts, not executed, so it has no shebang.
#
# Claude fills this during install (see ../INSTALL.md). A non-technical owner
# never edits it by hand. Every value can also be overridden by an environment
# variable of the same name, which is what the launchd plists do.
#
# Nothing secret lives here. There are no tokens and no passwords: both scripts
# authenticate through the Claude Code CLI and its MCP connectors, which the
# owner authorizes once in a browser. Keep it that way, never paste a token
# into this file.

# --- The vault: the folder Claude Code opens, where the agents' memory lives ---
# Absolute path. This is the folder the absorber writes into and commits.
VAULT="${VAULT:-$HOME/CHANGE-ME-vault}"

# --- The shared Google Drive folder that holds the transcripts ---
# The folder id is the last path segment of the folder's URL in Drive:
#   https://drive.google.com/drive/folders/<THIS-PART>
DRIVE_FOLDER_ID="${DRIVE_FOLDER_ID:-CHANGE-ME-drive-folder-id}"

# --- MCP tool-name prefixes, DISCOVERED in preflight, never guessed ---
# The exact prefix depends on how each connector was added. The Google Drive
# connector added inside claude.ai is 'mcp__claude_ai_Google_Drive__'; a Drive
# added through a different MCP will have a different prefix. INSTALL.md tells
# Claude to print the real tool names first and paste the exact prefixes here.
WISPR_TOOL_PREFIX="${WISPR_TOOL_PREFIX:-mcp__wisprflow__}"
DRIVE_TOOL_PREFIX="${DRIVE_TOOL_PREFIX:-mcp__claude_ai_Google_Drive__}"

# --- launchd label prefix (identifies the two scheduled jobs) ---
LABEL_PREFIX="${LABEL_PREFIX:-com.example.transcript}"

# --- Timezone, as a real IANA zone name so daylight saving is handled ---
# Do NOT use a fixed UTC offset: it is wrong for half the year.
TIMEZONE="${TIMEZONE:-Asia/Jerusalem}"

# --- Long-meeting chunking ---
# The Drive create_file tool has a size ceiling far below Google Docs' own.
# A meeting whose text exceeds this many characters is split into parts, one
# Google Doc per part. 40000 is a safe default; tune it once the real ceiling
# is known on this machine. [verify]
CHUNK_CHAR_LIMIT="${CHUNK_CHAR_LIMIT:-40000}"

# --- Batch caps: a backlog drains across runs, never in one burst ---
MAX_NEW_PER_RUN_UPLOAD="${MAX_NEW_PER_RUN_UPLOAD:-10}"
MAX_NEW_PER_RUN_ABSORB="${MAX_NEW_PER_RUN_ABSORB:-15}"

# --- Below this many characters a transcript is an empty-audio blip ---
MIN_TRANSCRIPT_CHARS="${MIN_TRANSCRIPT_CHARS:-600}"

# --- Where the absorber's protocol file lives (copied into the vault at install) ---
PROTOCOL_FILE="${PROTOCOL_FILE:-$VAULT/.claude/transcript-protocol.md}"
