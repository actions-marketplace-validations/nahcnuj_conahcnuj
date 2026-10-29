# conahcnuj

GitHub Marketplace: <https://github.com/marketplace/actions/conahcnuj>

**GitHub App 名義**で Git 操作を行う GitHub Actions です。issue から PR を
作成し、レビュー対応まで行います。

> `action.yml` は shim です（`exit 255`）。このリポジトリを clone する必要は
> なく、下記の reusable workflow を呼び出すだけで使えます。

## Getting started

利用側リポジトリから reusable workflow を呼び出して使います。

### 前提条件

1. あなたのアカウントに GitHub App を作成し、対象リポジトリにインストールする
   （App ID / Installation ID / 秘密鍵 / スラッグが必要）。
2. 対象リポジトリの Secrets に `APP_ID` / `INSTALLATION_ID` / `PRIVATE_KEY` を
   登録する（`APP_SLUG` は Secret にしない）。
3. auto-merge を使う場合は、Settings → General → Pull Requests で
   **Allow auto-merge** を有効にする。

設定値の詳細は [docs/configuration.md](docs/configuration.md)。

### 使い方

1. 利用側リポジトリで issue を開く。
2. ドライバが PR を作成するので、内容を確認し Approve する。

## Workflows

### issue の自動対応 (`issue-driver.yml`)

issue が open / reopen されるとドライバを Actions 上で自動実行します。

```yaml
name: Issue auto-drive

on:
  issues:
    types: [opened, reopened]

permissions:
  contents: read

jobs:
  drive:
    uses: nahcnuj/conahcnuj/.github/workflows/issue-driver.yml@main
    with:
      number: ${{ github.event.issue.number }}
    secrets: inherit
```

タイムアウトは Actions 側で制御します（`timeout-minutes: 60`）。
詳細は [docs/workflows.md](docs/workflows.md)。

### owner 承認後の自動マージ (`owner-approved-auto-merge.yml`)

```yaml
name: Owner-approved auto-merge

on:
  pull_request_review:
    types: [submitted]

permissions:
  contents: write
  pull-requests: write

jobs:
  enable:
    uses: nahcnuj/conahcnuj/.github/workflows/owner-approved-auto-merge@main
    with:
      repository: ${{ github.repository }}
      pr-number: ${{ github.event.pull_request.number }}
      head-sha: ${{ github.event.pull_request.head.sha }}
```

詳細は [docs/workflows.md](docs/workflows.md)。

## ローカルで使う (opencode)

ローカルで opencode を bot 名義で動かす場合の手順です。配置の詳細は
[docs/installation.md](docs/installation.md) を参照してください。

前提: Git for Windows（`C:/Program Files/Git/bin/bash.exe`）。
Linux / macOS でも pwsh があれば動作します（CI 検証は Windows のみ）。

1. clone して `install.ps1` を実行する。

   ```sh
   git clone <repo>.git
   cd <repo>
   powershell -ExecutionPolicy Bypass -File install.ps1
   ```

2. `~/.config/opencode/gh-app/app.env` に `APP_ID` / `INSTALLATION_ID` /
   `PRIVATE_KEY_PATH` / `APP_SLUG` / `BASH_EXE` を設定する。
3. opencode を再起動し、`gh auth status` が bot アカウント (`<slug>[bot]`) を
   示すことを確認する。
4. `conahcnuj <issue番号>` を実行するか、issue を開く。

opencode プラグインの仕組みは [docs/plugin.md](docs/plugin.md) を参照。

## Verified コミット (`git vc`)

コーディングエージェントは `git vc` でコミットします。GitHub GraphQL の
`createCommitOnBranch` を使い **Verified 署名付きコミット**をブランチに作成します。

```sh
git vc -m "message"        # staged の内容をコミット
git vc -m "message" -a     # tracked の作業ツリー変更をコミット
```

詳細は [docs/cli.md](docs/cli.md)。

## トラブルシューティング

- **`gh auth status` が自分のアカウントを表示する**: `BASH_EXE` と `app.env`
  を確認し、opencode を再起動する。
- **トークンが取れない**: `bash gh-app/get-token.sh` を直接実行する。

## 隔離環境 (Docker)

```sh
cd <対象リポジトリ>
bash <このリポジトリ>/docker-run.sh <issue-or-PR番号>
```

詳細は [docs/installation.md](docs/installation.md)。

## ドキュメント

- サイト: <https://nahcnuj.github.io/conahcnuj/>
- 機械可読な索引: <https://nahcnuj.github.io/conahcnuj/llms.txt>
- AI エージェント向け: [AGENTS.md](AGENTS.md)
