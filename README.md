# conahcnuj

> GitHub Marketplace: <https://github.com/marketplace/actions/conahcnuj>

**GitHub App 名義**で Git 操作を行うための GitHub Actions です。
issue から PR を作成し、レビュー対応まで行います。

`conahcnuj` は @nahcnuj のインスタンスです。他のユーザーは自分の GitHub App
（`<slug>`）を作成して利用します。bot アカウントは `<slug>[bot]` です。

> **Marketplace での利用に `git clone` は不要です。** reusable workflow は
> `uses: nahcnuj/conahcnuj/.github/workflows/...@main` で呼び出します
> （下記「GitHub Actions として使う」参照）。以下の clone / install 手順は、
> ローカルで opencode を bot 名義で動かす場合のみ必要です。

## 何ができるか

- `gh` CLI / GitHub API が **App 名義（`<slug>[bot]`）** で動く
- opencode 内の git 操作が **App 名義** で行われる
- issue を PR・レビュー依頼・owner の Approve まで自律的に運ぶドライバを含む

## GitHub Actions として使う

このリポジトリの `.github/workflows/issue-driver.yml` と
`.github/workflows/owner-approved-auto-merge.yml` は **reusable workflow** です。
Marketplace のページはこの README を表示しますが、直接 `uses:` するものではなく、
利用側リポジトリから呼び出して使います（clone は不要です）。

### issue の自動対応

issue が open されるとドライバを Actions 上で自動実行します。`workflow_call` で
他リポジトリから再利用できます。

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

タイムアウトは Actions 側で制御（`timeout-minutes: 60`）し、
`CONAHCNUJ_MAX_SECONDS=3540` を設定します。必要な repo secrets:
`APP_ID` / `INSTALLATION_ID` / `PRIVATE_KEY`（`APP_SLUG` はシークレットにしない）。
詳細は [docs/workflows.md](docs/workflows.md) を参照。

### owner 承認後の自動マージ

owner の approve をトリガーに auto-merge を有効化します。利用側リポジトリに次を追加します。

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

対象リポジトリの Settings → General → Pull Requests で **Allow auto-merge** を有効に
してください。詳細は [docs/workflows.md](docs/workflows.md) を参照。

## ローカルで使う (opencode セットアップ)

### Quick start (クイックスタート)

1. このリポジトリを clone し、`powershell -ExecutionPolicy Bypass -File install.ps1` を実行します
   （隔離実行には `docker-run.sh` も使えます）。
2. `~/.config/opencode/gh-app/app.env` に `APP_ID` / `INSTALLATION_ID` /
   `PRIVATE_KEY_PATH` / `APP_SLUG` / `BASH_EXE` を設定します。
3. opencode を再起動し、`gh auth status` が bot アカウント（`<slug>[bot]`）を
   示すことを確認します。
4. 対象リポジトリで issue を開くか、`conahcnuj <issue番号>` を実行します。
   ドライバがブランチ作成・Verified コミット・PR 作成・レビュー依頼まで進めます。
5. owner が Approve すると、auto-merge workflow がマージします。

### インストールと設定

前提: Windows + Git for Windows（`C:/Program Files/Git/bin/bash.exe`）、
opencode が `~/.config/opencode/` をグローバル設定として使うこと。

```sh
git clone <repo>.git
cd <repo>
powershell -ExecutionPolicy Bypass -File install.ps1
```

`~/.config/opencode/gh-app/app.env`（またはリポジトリの `gh-app/app.env`）に
`APP_ID` / `INSTALLATION_ID` / `PRIVATE_KEY_PATH` / `APP_SLUG` / `BASH_EXE` を設定します。
キーの説明・キャッシュ・セキュリティは [docs/configuration.md](docs/configuration.md) と
[docs/installation.md](docs/installation.md) を参照してください。

## 仕組み

1. `get-token.sh` が GitHub App の秘密鍵で JWT を署名し、インストールトークン（約 1 時間有効）を取得。
   取得済みなら有効期限内はキャッシュ（`gh-app/token.cache`）を返す。
2. opencode プラグインが `shell.env` フックで `GH_TOKEN` と `GIT_CONFIG_*`
   （bot 名義 + `alias.vc`）を注入。
3. `experimental.chat.system.transform` フックで「コミットは `git vc`」「GitHub は `GH_TOKEN` で
   認証済み」を全セッションのシステムプロンプトへ常時注入し、`tool.execute.before` で
   `git commit` / `api-commit.sh` の直接実行を `git vc` へ誘導する。
4. `install.ps1` は `opencode/AGENTS.md` を `~/.config/opencode/AGENTS.md` へ
   管理ブロックとしてマージする（既存内容は保持）。

## Verified コミット（`git vc`）

コーディングエージェントは `git vc` でコミットする。`git vc` はプラグインが注入する git alias で、
GitHub GraphQL の `createCommitOnBranch` を使い **Verified 署名付きコミット**をブランチに作成する。
opencode 上の git は App 名義で動き署名鍵を持たないため、普通の `git commit` では
ブランチルール（"Commits must have verified signatures"）を満たせない。

```sh
git vc -m "message"        # staged の内容をコミット
git vc -m "message" -a     # tracked の作業ツリー変更をコミット
```

## トラブルシューティング

- **`gh auth status` が自分のアカウントを表示する**: プラグインがトークンを取得できていない。
  `BASH_EXE` が正しい Git Bash 経路か、`app.env` の値を確認。変更後は opencode を再起動。
- **トークンが取れない**: `bash gh-app/get-token.sh` を直接実行して出力を確認
  （`token.cache` 削除後に再実行）。
- **CI で実トークンの検証が無い**: CI の `mock-test` は秘密鍵・ネットワーク不要の
  offline 検証のみ。実トークンの動作確認はローカルで行う。

## 隔離環境で実行する（Docker）

```sh
cd <対象リポジトリ>
bash <このリポジトリ>/docker-run.sh <issue-or-PR番号>
```

対象リポジトリは `/work` にバインドマウントされ、秘密鍵と `app.env` はイメージに
焼き込まず実行時に読み取り専用でマウントします。詳細は
[docs/installation.md](docs/installation.md) を参照。

## 構成

```
.
├── gh-app/                    # シェルスクリプト群（App トークン発行・認証まわり）
├── bin/conahcnuj.sh           # issue駆動自律開発ドライバ本体
├── lib/                       # ドライバ用ライブラリ
├── plugins/gh-app-token.ts    # opencode プラグイン
├── opencode/AGENTS.md         # opencode グローバルルール
├── plugin-tests/              # プラグインのテスト
├── driver-tests/              # ドライバの offline モックテスト
├── Dockerfile / docker-run.sh # 隔離実行
├── install.ps1                # 配置スクリプト
├── docs/                      # リファレンス（GitHub Pages で配信）
├── .github/workflows/         # GitHub Actions
├── .gitignore
└── AGENTS.md                  # AI エージェント向けルール
```

## ドキュメント

設定・CLI・ドライバ・プラグイン・環境変数・ワークフローのリファレンスを `docs/` に置き、
GitHub Pages で配信しています。

- サイト: <https://nahcnuj.github.io/conahcnuj/>
- 機械可読な索引: <https://nahcnuj.github.io/conahcnuj/llms.txt>

AI エージェント向けの詳細ルールは [AGENTS.md](AGENTS.md) を参照してください。
