# conahcnuj

> GitHub Marketplace: <https://github.com/marketplace/actions/conahcnuj>

**GitHub App 名義**で Git 操作を行うための GitHub Actions です。issue から PR を作成し、
レビュー対応まで行います。`gh` CLI・GitHub API・opencode 内の git 操作を App 名義
(`<slug>[bot]`) で動かすための設定とスクリプトも含みます。

`conahcnuj` は @nahcnuj のインスタンス名です。他のユーザーは自分用の GitHub App を
作成し、そのスラッグ (`<slug>`) で利用します（bot アカウントは `<slug>[bot]`）。

> **Marketplace での利用に `git clone` は不要です。** 実体は reusable workflow で、
> 利用側リポジトリから `uses:` で呼び出します（下記「Marketplace で使う」）。
> clone と `install.ps1` は、ローカルで opencode を bot 名義で動かす場合だけ必要です。

## Marketplace で使う

`.github/workflows/issue-driver.yml` と
`.github/workflows/owner-approved-auto-merge.yml` は **reusable workflow** です。
Marketplace のページにはこの README が表示されますが、利用側リポジトリから
呼び出して使います（clone は不要です）。

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

タイムアウトは Actions 側で制御します（`timeout-minutes: 60`）。
`CONAHCNUJ_MAX_SECONDS=3540` を設定し、ジョブ強制終了の前にドライバが自己終了して
バグ報告を残せるようにします。必要な repo secrets は `APP_ID` / `INSTALLATION_ID` /
`PRIVATE_KEY` です（`APP_SLUG` はシークレットにしません）。詳細は
[docs/workflows.md](docs/workflows.md) を参照してください。

### owner 承認後の自動マージ

owner の approve をトリガーに auto-merge を有効化します。利用側リポジトリに次を
追加します。

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
してください。詳細は [docs/workflows.md](docs/workflows.md) を参照してください。

## ローカルで使う (opencode セットアップ)

ローカルで opencode を bot 名義で動かす場合の手順です。

前提: Windows + Git for Windows (`C:/Program Files/Git/bin/bash.exe`)、
opencode が `~/.config/opencode/` をグローバル設定として使うこと。

1. このリポジトリを clone し、`install.ps1` を実行します（隔離実行には
   `docker-run.sh` も使えます）。

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
