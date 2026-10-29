# conahcnuj

> GitHub Marketplace: <https://github.com/marketplace/actions/conahcnuj>

**GitHub App 名義**で Git 操作を行うための GitHub Actions です。issue を開くと
ドライバが自動でブランチ作成・Verified コミット・PR 作成・レビュー依頼まで進め、
owner の Approve で auto-merge します。

`conahcnuj` は @nahcnuj のインスタンス名です。他のユーザーは自分用の
GitHub App を作成し、そのスラッグ (`<slug>`) で利用します（bot アカウントは
`<slug>[bot]`）。

> **Marketplace からの利用に `git clone` は不要です。** 実体は reusable workflow
> で、利用側リポジトリから `uses:` で呼び出します。
> clone と `install.ps1` は、ローカルで opencode を bot 名義で動かす場合だけ
> 必要です。

## Marketplace で使う

`.github/workflows/issue-driver.yml` と
`.github/workflows/owner-approved-auto-merge.yml` は **reusable workflow** です。
このリポジトリの `action.yml` は Marketplace 掲載用の shim で、直接
`uses: nahcnuj/conahcnuj@…` では動きません。利用側リポジトリから reusable
workflow を呼び出して使います。

### 何ができるか

- `gh` CLI / GitHub API が **App 名義 (`<slug>[bot]`)** で動く
- opencode 内の git 操作が **App 名義** で行われる（Verified コミット）
- issue → ブランチ → PR → レビュー依頼 → owner の Approve までを自律的に運ぶ
  ドライバを含む
- owner の Approve をトリガーに auto-merge

### 前提（Marketplace 利用）

1. 自分用の GitHub App を作成し、対象リポジトリにインストールする
   （App ID / Installation ID / 秘密鍵 / スラッグが必要）。
2. 対象リポジトリの Secrets に `APP_ID` / `INSTALLATION_ID` / `PRIVATE_KEY` を
   登録する（`APP_SLUG` は Secret にしない）。
3. auto-merge を使う場合は、対象リポジトリの Settings → General → Pull Requests
   で **Allow auto-merge** を有効にする。

設定値の詳細は [docs/configuration.md](docs/configuration.md) を参照してください。

### issue の自動対応

issue が open / reopen されるとドライバを Actions 上で自動実行します。
`workflow_call` で他リポジトリから再利用できます。

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
`CONAHCNUJ_MAX_SECONDS=3540` を設定し、ジョブ強制終了の前にドライバが
自己終了してバグ報告を残せるようにします。
詳細は [docs/workflows.md](docs/workflows.md) を参照してください。

### owner 承認後の自動マージ

owner の approve をトリガーに auto-merge を有効化します。利用側リポジトリに
次を追加します。

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

詳細は [docs/workflows.md](docs/workflows.md) を参照してください。

## ローカルで使う (opencode セットアップ)

ローカルで opencode を bot 名義で動かす場合の手順です。

前提: Windows + Git for Windows (`C:/Program Files/Git/bin/bash.exe`)、
opencode が `~/.config/opencode/` をグローバル設定として使うこと。
（`install.ps1` は pwsh があれば Linux / macOS でも動作しますが、CI での検証は
Windows のみです。隔離実行には Docker も使えます。）

1. このリポジトリを clone し、`install.ps1` を実行します。

   ```sh
   git clone <repo>.git
   cd <repo>
   powershell -ExecutionPolicy Bypass -File install.ps1
   ```

2. `~/.config/opencode/gh-app/app.env`（またはリポジトリの `gh-app/app.env`）に
   `APP_ID` / `INSTALLATION_ID` / `PRIVATE_KEY_PATH` / `APP_SLUG` / `BASH_EXE` を
   設定します。キーの説明・キャッシュ・セキュリティは
   [docs/configuration.md](docs/configuration.md) を参照してください。
3. opencode を再起動し、`gh auth status` が bot アカウント (`<slug>[bot]`) を
   示すことを確認します。
4. 対象リポジトリで issue を開くか、`conahcnuj <issue番号>` を実行します。
   ドライバがブランチ作成・Verified コミット・PR 作成・レビュー依頼まで進めます。
5. owner が Approve すると、auto-merge workflow がマージします。

配置と実行の詳細は [docs/installation.md](docs/installation.md) を参照してください。

## 仕組み

1. `get-token.sh` が GitHub App の秘密鍵で JWT を署名し、インストールトークン
   （約 1 時間有効）を取得します。取得済みなら有効期限内はキャッシュ
   (`gh-app/token.cache`) を返します。
2. opencode プラグインが `shell.env` フックで `GH_TOKEN` と `GIT_CONFIG_*`
   (bot 名義 + `alias.vc`) を注入します。
3. `experimental.chat.system.transform` フックで「コミットは `git vc`」「GitHub は
   `GH_TOKEN` で認証済み」を全セッションのシステムプロンプトへ常時注入し、
   `tool.execute.before` で `git commit` / `api-commit.sh` の直接実行を `git vc` へ
   誘導します。
4. `install.ps1` は `opencode/AGENTS.md` を `~/.config/opencode/AGENTS.md` へ
   管理ブロックとしてマージします（既存内容は保持）。

プラグインの詳細は [docs/plugin.md](docs/plugin.md) を参照してください。

## Verified コミット (`git vc`)

コーディングエージェントは `git vc` でコミットします。`git vc` はプラグインが注入する
git alias で、GitHub GraphQL の `createCommitOnBranch` を使い **Verified 署名付き
コミット**をブランチに作成します。opencode 上の git は App 名義で動き署名鍵を持たない
ため、普通の `git commit` ではブランチルール
("Commits must have verified signatures") を満たせません。

```sh
git vc -m "message"        # staged の内容をコミット
git vc -m "message" -a     # tracked の作業ツリー変更をコミット
```

## トラブルシューティング

- **`gh auth status` が自分のアカウントを表示する**: プラグインがトークンを取得できていない。
  `BASH_EXE` が正しい Git Bash 経路か、`app.env` の値を確認してください。
  変更後は opencode を再起動します。
- **トークンが取れない**: `bash gh-app/get-token.sh` を直接実行して出力を確認します
  (`token.cache` 削除後に再実行)。
- **CI で実トークンの検証が無い**: CI の `mock-test` は秘密鍵・ネットワーク不要の
  offline 検証のみです。実トークンの動作確認はローカルで行ってください。

## 隔離環境で実行する (Docker)

```sh
cd <対象リポジトリ>
bash <このリポジトリ>/docker-run.sh <issue-or-PR番号>
```

対象リポジトリは `/work` にバインドマウントされ、秘密鍵と `app.env` はイメージに
焼き込まず実行時に読み取り専用でマウントします。詳細は
[docs/installation.md](docs/installation.md) を参照してください。

## 構成

```
.
├── gh-app/                    # App トークン発行・認証まわりのシェルスクリプト
├── bin/conahcnuj.sh           # issue 駆動自律開発ドライバ本体
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
filePath: /home/runner/work/conahcnuj/conahcnuj/README.md