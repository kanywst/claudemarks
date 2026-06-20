# claudemarks

[English](README.md) | [日本語](README.ja.md)

[![CI](https://github.com/kanywst/claudemarks/actions/workflows/ci.yml/badge.svg)](https://github.com/kanywst/claudemarks/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/kanywst/claudemarks)](https://github.com/kanywst/claudemarks/releases)
[![License: MIT](https://img.shields.io/github/license/kanywst/claudemarks)](LICENSE)

Claude Code セッションのブックマーク。終了時に resume ID・タイトル・作業ディレクトリを自動記録する。1セッション1行、プレーンな markdown、依存ゼロ。

`claude` を抜けると `claude --resume <id>` で再開できる ID が表示される。
毎回メモするのは面倒なので、`SessionEnd` フックで終了時に自動追記する。

## なぜ

他のツールは TUI・セマンティック検索・常駐プロセスで resume を包む。claudemarks は逆方向で、40行の bash フック1枚、フック登録以外のインストール不要、そして grep / commit / 一目で読める `SESSIONS.md` を残すだけ。

## 記録される内容

`SESSIONS.md` には1セッション1行で残る。

| 列 | 内容 |
| --- | --- |
| ended | 終了時刻 |
| topic | Claude Code 自動生成タイトル（無ければ最初の発言、それも無ければ `(untitled)`） |
| cwd | 起動した作業ディレクトリ |
| session id | resume 用 ID |
| reason | 終了理由（`clear` / `logout` / `prompt_input_exit` / `other`） |
| resume | コピペで実行できる `claude --resume <id>` |

## セットアップ

### A: plugin として入れる（おすすめ）

```text
/plugin marketplace add kanywst/claudemarks
/plugin install claudemarks@claudemarks
```

これで `SessionEnd` フックがグローバル登録される。以降は各セッションが、実行したプロジェクトのルート（`CLAUDE_PROJECT_DIR`）に `SESSIONS.md` を書く。

### B: 手動（bash フックだけ）

1. `hooks/log-session.sh` を自分のリポジトリにコピー（例: `.claude/hooks/log-session.sh`）して実行権限を付与:

   ```bash
   chmod +x .claude/hooks/log-session.sh
   ```

2. プロジェクトの `.claude/settings.json` に `SessionEnd` フックを追加:

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

3. public リポジトリなら `SESSIONS.md` を `.gitignore` に追加（作業内容とローカルパスを含むため）。

## 仕組み

- フックは stdin で JSON を受け取る（`session_id` / `transcript_path` / `cwd` / `reason`）
- トランスクリプトから自動タイトルを読み、`SESSIONS.md` に1行追記する
- fail-open: どんなエラーでも `0` で抜けるので、セッション終了を絶対にブロックしない
- このリポジトリでは `SESSIONS.md` を gitignore 済み（作業内容＋ローカルパス）

## ファイル

- `.claude-plugin/plugin.json` — plugin マニフェスト
- `.claude-plugin/marketplace.json` — `/plugin install` 用カタログ
- `hooks/hooks.json` — plugin の `SessionEnd` フック登録
- `hooks/log-session.sh` — 追記スクリプト（fail-open、終了をブロックしない）
- `SESSIONS.md` — 自動生成ログ（gitignore）
