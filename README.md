# claudemarks

[English](README.md) | [日本語](README.ja.md)

Bookmarks for your Claude Code sessions. Auto-logs resume IDs, topics, and working dirs on session exit — one row per session, in plain markdown, zero dependencies.

When you exit `claude`, it prints an ID you can use to resume with `claude --resume <id>`.
Writing it down every time is tedious, so a `SessionEnd` hook appends it automatically.

## Why

Other tools wrap session resume with TUIs, semantic search, or daemons. claudemarks does the opposite: one 40-line bash hook, no install step beyond a hook, and a human-readable `SESSIONS.md` you can grep, commit, or read at a glance.

## What gets recorded

`SESSIONS.md` keeps one row per session.

| Column | Meaning |
| --- | --- |
| ended | Exit timestamp |
| topic | Claude Code auto-generated title (falls back to the first prompt, then `(untitled)`) |
| cwd | Working directory the session launched from |
| session id | ID for resuming |
| reason | Exit reason (`clear` / `logout` / `prompt_input_exit` / `other`) |
| resume | Copy-paste ready `claude --resume <id>` |

## Setup

### Option A — Install as a plugin (recommended)

```text
/plugin marketplace add kanywst/claudemarks
/plugin install claudemarks@claudemarks
```

This registers a `SessionEnd` hook globally. From then on, every session writes a `SESSIONS.md` to the root of whatever project it ran in (`CLAUDE_PROJECT_DIR`).

### Option B — Manual (just the bash hook)

1. Copy `hooks/log-session.sh` into your repo (e.g. `.claude/hooks/log-session.sh`) and make it executable:

   ```bash
   chmod +x .claude/hooks/log-session.sh
   ```

2. Add a `SessionEnd` hook to your project's `.claude/settings.json`:

   ```json
   {
     "hooks": {
       "SessionEnd": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/log-session.sh"
             }
           ]
         }
       ]
     }
   }
   ```

3. Add `SESSIONS.md` to `.gitignore` if the repo is public — it contains topics and local paths.

## How it works

- The hook receives JSON on stdin (`session_id`, `transcript_path`, `cwd`, `reason`)
- It reads the auto title from the transcript and appends a row to `SESSIONS.md`
- It is fail-open: any error exits `0` so it never blocks a session from closing
- `SESSIONS.md` is gitignored in this repo (work topics + local paths)

## Files

- `.claude-plugin/plugin.json` — plugin manifest
- `.claude-plugin/marketplace.json` — marketplace catalog for `/plugin install`
- `hooks/hooks.json` — registers the `SessionEnd` hook for the plugin
- `hooks/log-session.sh` — the append script (fail-open, never blocks exit)
- `SESSIONS.md` — auto-generated log (gitignored)
