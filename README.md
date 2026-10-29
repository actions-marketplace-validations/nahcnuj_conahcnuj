# conahcnuj

> GitHub Marketplace: <https://github.com/marketplace/actions/conahcnuj>

**GitHub App 名義**で Git 操作を行う GitHub Actions です。issue から PR を
作成し、レビュー対応まで行います。

## Getting started

1. GitHub App を作成し、対象リポジトリにインストールする
   (APP_ID / INSTALLATION_ID / 秘密鍵 / APP_SLUG)。
2. 対象リポジトリの Secrets に `APP_ID` / `INSTALLATION_ID` / `PRIVATE_KEY`
   を登録する (`APP_SLUG` は Secret にしない)。
3. auto-merge を使う場合は Settings → General → Pull Requests で
   **Allow auto-merge** を有効にする。

### 使い方

1. issue を作成する。
2. PR をレビューする。

## GitHub Actions として使う

reusable workflow (`issue-driver.yml` / `owner-approved-auto-merge.yml`)。
詳細は [docs/workflows.md](docs/workflows.md)。

## ローカルで使う (opencode セットアップ)

詳細は [docs/installation.md](docs/installation.md)。

1. clone して `install.ps1` を実行する。
2. `~/.config/opencode/gh-app/app.env` を設定する。
3. opencode を再起動し、`gh auth status` を確認する。
4. `conahcnuj <issue番号>` を実行するか、issue を開く。

## Verified コミット (`git vc`)

コーディングエージェントは `git vc` で Verified 署名付きコミットを作成します。
詳細は [docs/cli.md](docs/cli.md)。

```sh
git vc -m "message"        # staged の内容をコミット
git vc -m "message" -a     # tracked の作業ツリー変更をコミット
```

## 隔離環境 (Docker)

```sh
cd <対象リポジトリ>
bash <このリポジトリ>/docker-run.sh <issue-or-PR番号>
```

詳細は [docs/installation.md](docs/installation.md)。

## トラブルシューティング

- **`gh auth status` が自分のアカウントを表示する**: `BASH_EXE` と `app.env` を
  確認し、opencode を再起動する。
- **トークンが取れない**: `bash gh-app/get-token.sh` を直接実行する
  (`token.cache` 削除後に再実行)。

## ドキュメント

- サイト: <https://nahcnuj.github.io/conahcnuj/>
- 機械可読な索引: <https://nahcnuj.github.io/conahcnuj/llms.txt>

AI エージェント向けの詳細ルールは [AGENTS.md](AGENTS.md) を参照してください。
