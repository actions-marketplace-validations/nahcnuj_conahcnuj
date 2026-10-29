# conahcnuj

GitHub Marketplace: <https://github.com/marketplace/actions/conahcnuj>

**GitHub App 名義**で Git 操作を行う GitHub Actions です。issue から PR を
作成し、レビュー対応まで行います。

## Getting started

1. GitHub App を作成し、対象リポジトリにインストールする。
2. 対象リポジトリの Secrets に `APP_ID` / `INSTALLATION_ID` / `PRIVATE_KEY`
   を登録する (`APP_SLUG` は Secret にしない)。
3. auto-merge を使う場合は Settings → General → Pull Requests で
   **Allow auto-merge** を有効にする。

### 使い方

1. issue を作成する。
2. PR をレビューする。

## Workflows

reusable workflow (`issue-driver.yml` / `owner-approved-auto-merge.yml`)。
詳細は [docs/workflows.md](docs/workflows.md)。

## ローカルで使う (opencode)

詳細は [docs/installation.md](docs/installation.md)。

## Verified コミット (`git vc`)

詳細は [docs/cli.md](docs/cli.md)。

## 隔離環境 (Docker)

詳細は [docs/installation.md](docs/installation.md)。

## トラブルシューティング

- **`gh auth status` が自分のアカウントを表示する**: `BASH_EXE` と `app.env`
  を確認し、opencode を再起動する。
- **トークンが取れない**: `bash gh-app/get-token.sh` を直接実行する。

## ドキュメント

- サイト: <https://nahcnuj.github.io/conahcnuj/>
- 機械可読な索引: <https://nahcnuj.github.io/conahcnuj/llms.txt>
- AI エージェント向け: [AGENTS.md](AGENTS.md)
