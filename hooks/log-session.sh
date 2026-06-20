#!/usr/bin/env bash
# claudemarks — SessionEnd hook.
# Appends this session's resume id + auto-title to SESSIONS.md in the project
# root so `claude --resume <id>` can be looked up later by topic.
# Wired via hooks/hooks.json (plugin) or a SessionEnd entry in settings.json.
#
# Contract: never blocks a session exit. Fails open (exit 0) on any error.
set -uo pipefail

# jq is the only external dependency. If it is missing, fail open silently
# rather than spraying "command not found" to stderr on every session exit.
command -v jq >/dev/null 2>&1 || exit 0

# Nothing is piped in on a manual interactive run; bail instead of hanging on cat.
[ -t 0 ] && exit 0

payload="$(cat)" || exit 0

# Parse all payload fields in a single jq pass (one process, not four). @tsv
# keeps fields on one tab-separated line; none of these values contain tabs.
IFS=$'\t' read -r sid reason cwd tpath < <(
  printf '%s' "$payload" |
    jq -r '[.session_id // "", .reason // "other", .cwd // "", .transcript_path // ""] | @tsv' 2>/dev/null
)
[ -z "$sid" ] && exit 0

ts="$(date '+%Y-%m-%d %H:%M:%S')"

# Topic: prefer Claude Code's auto-generated session title; fall back to the
# first plain-text user prompt; else "(untitled)".
topic=""
if [ -n "$tpath" ] && [ -f "$tpath" ]; then
  # `.type?` tolerates non-object transcript lines instead of aborting jq.
  topic="$(jq -r 'select(.type? == "ai-title") | .aiTitle' "$tpath" 2>/dev/null | tail -n 1)"
  if [ -z "$topic" ]; then
    # Optional chaining keeps jq from aborting on unexpected shapes; the string
    # slice is codepoint-based, so it won't split a multibyte char.
    topic="$(jq -r 'select(.type? == "user") | .message?.content? | select(type == "string") | .[0:80]' "$tpath" 2>/dev/null | grep -vE '^<' | head -n 1)"
  fi
fi
[ -z "$topic" ] && topic="(untitled)"
# Sanitize for a markdown table cell: drop newlines, escape pipes.
topic="$(printf '%s' "$topic" | tr '\n' ' ' | sed 's/|/\\|/g')"

# Pin the log to the project root so it lands in one place regardless of which
# subdirectory claude was launched from. CLAUDE_PROJECT_DIR is set for hooks.
log="${CLAUDE_PROJECT_DIR:-${cwd:-$(pwd)}}/SESSIONS.md"

if [ ! -f "$log" ]; then
  {
    printf '# Claude Code sessions\n\n'
    printf 'Auto-logged by [claudemarks](https://github.com/kanywst/claudemarks) on SessionEnd. Resume with `claude --resume <id>`.\n\n'
    printf '| ended | topic | cwd | session id | reason | resume |\n'
    printf '| --- | --- | --- | --- | --- | --- |\n'
  } >> "$log" 2>/dev/null
fi

cwd_cell="$(printf '%s' "${cwd:-$(pwd)}" | sed 's/|/\\|/g')"
printf '| %s | %s | `%s` | `%s` | %s | `claude --resume %s` |\n' "$ts" "$topic" "$cwd_cell" "$sid" "$reason" "$sid" >> "$log" 2>/dev/null
exit 0
