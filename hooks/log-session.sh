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

payload="$(cat)" || exit 0

sid="$(printf '%s' "$payload" | jq -r '.session_id // empty' 2>/dev/null)" || exit 0
[ -z "$sid" ] && exit 0

reason="$(printf '%s' "$payload" | jq -r '.reason // "other"' 2>/dev/null)"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
tpath="$(printf '%s' "$payload" | jq -r '.transcript_path // empty' 2>/dev/null)"
ts="$(date '+%Y-%m-%d %H:%M:%S')"

# Topic: prefer Claude Code's auto-generated session title; fall back to the
# first plain-text user prompt; else "(untitled)".
topic=""
if [ -n "$tpath" ] && [ -f "$tpath" ]; then
  topic="$(jq -r 'select(.type=="ai-title") | .aiTitle' "$tpath" 2>/dev/null | tail -1)"
  if [ -z "$topic" ]; then
    # jq string slice is codepoint-based, so it won't split a multibyte char.
    topic="$(jq -r 'select(.type=="user" and (.message.content|type=="string")) | .message.content[0:80]' "$tpath" 2>/dev/null | grep -vE '^<' | head -1)"
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
  } >> "$log"
fi

cwd_cell="$(printf '%s' "${cwd:-$(pwd)}" | sed 's/|/\\|/g')"
printf '| %s | %s | `%s` | `%s` | %s | `claude --resume %s` |\n' "$ts" "$topic" "$cwd_cell" "$sid" "$reason" "$sid" >> "$log"
exit 0
