# conahcnuj


**GitHub App 名義**で Git 操作を行うための GitHub Actions です。issue から PR を
作成し、レビュー対応まで行います。

> **Marketplace での利用に `git clone` は不要です。** reusable workflow は
> `uses: nahcnuj/conahcnuj/.github/workflows/...@main` で呼び出します。
> 以下の clone / install 手順は、ローカルで opencode を bot 名義で動かす場合のみ
> 必要です。

## Getting started

### Create your GitHub App for conahcnuj

1. あなたのアカウントに GitHub App を作成する（対象リポジトリにインストールする。
   App ID / Installation ID / 秘密鍵 / スラッグが必要）。
2. 対象リポジトリの Secrets に `APP_ID` / `INSTALLATION_ID` / `PRIVATE_KEY` を
   登録する（`APP_SLUG` は Secret にしない）。
3. auto-merge を使う場合は、Settings → General → Pull Requests で
   **Allow auto-merge** を有効にする。

### 使い方

1. issue を作成する。
2. PR をレビューする。

## GitHub Actions として使う

`.github/workflows/issue-driver.yml` と `.github/workflows/owner-approved-auto-merge.yml`
は **reusable workflow** です（`action.yml` は Marketplace 用の shim で、実体は
こちら）。clone は不要で、利用側リポジトリから呼び出して使います。
詳細は [docs/workflows.md](docs/workflows.md)。

- **issue の自動対応** (`issue-driver.yml`): issue が open / reopen されるとドライバを
  Actions 上で自動実行します。必要な repo secrets: `APP_ID` / `INSTALLATION_ID` /
  `PRIVATE_KEY`（`APP_SLUG` はシークレットにしない）。
- **owner 承認後の自動マージ** (`owner-approved-auto-merge.yml`): owner の approve を
  トリガーに auto-merge を有効化します。**Allow auto-merge** の有効化が必要です。

## ローカルで使う (opencode セットアップ)

ローカルで opencode を bot 名義で動かす場合の手順です。配置の詳細は
[docs/installation.md](docs/installation.md) を参照してください。

前提: Windows + Git for Windows (`C:/Program Files/Git/bin/bash.exe`)、
opencode が `~/.config/opencode/` をグローバル設定として使うこと
（pwsh があれば Linux / macOS でも動作しますが、CI 検証は Windows のみ）。

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
4. `conahcnuj <issue番号>` を実行するか、issue を開く。ドライバがブランチ作成・
   Verified コミット・PR 作成・レビュー依頼まで進め、owner の Approve で
   auto-merge workflow がマージする。

opencode プラグインの仕組みは [docs/plugin.md](docs/plugin.md) を参照。

## Verified コミット (`git vc`)

コーディングエージェントは `git vc` でコミットします。プラグインが注入する
git alias で、GitHub GraphQL の `createCommitOnBranch` を使い **Verified 署名付き
コミット**をブランチに作成します。

```sh
git vc -m "message"        # staged の内容をコミット
git vc -m "message" -a     # tracked の作業ツリー変更をコミット
```

詳細は [docs/cli.md](docs/cli.md)。

## トラブルシューティング

- **`gh auth status` が自分のアカウントを表示する**: プラグインがトークンを取得できていない。
  `BASH_EXE` が正しい Git Bash 経路か、`app.env` の値を確認し、opencode を再起動する。
- **トークンが取れない**: `bash gh-app/get-token.sh` を直接実行して出力を確認する
  (`token.cache` 削除後に再実行)。
- **CI で実トークンの検証が無い**: `mock-test` は秘密鍵・ネットワーク不要の
  offline 検証のみ。実トークンの動作確認はローカルで行う。

## 隔離環境で実行する (Docker)

```sh
cd <対象リポジトリ>
bash <このリポジトリ>/docker-run.sh <issue-or-PR番号>
```

対象リポジトリは `/work` にバインドマウントされ、秘密鍵と `app.env` はイメージに
焼き込まず実行時に読み取り専用でマウントします。詳細は
[docs/installation.md](docs/installation.md)。

## ドキュメント

- サイト: <https://nahcnuj.github.io/conahcnuj/>
- 機械可読な索引: <https://nahcnuj.github.io/conahcnuj/llms.txt>

AI エージェント向けの詳細ルールは [AGENTS.md](AGENTS.md) を参照してください。

## リポジトリ構成

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
", filePath: "/home/runner/work/conahcnuj/conahcnuj/README.md"}