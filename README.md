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

`.github/workflows/issue-driver.yml` と `owner-approved-auto-merge.yml` は
reusable workflow です。詳細は [docs/workflows.md](docs/workflows.md)。

- **issue の自動対応** (`issue-driver.yml`): issue が open / reopen されると
  ドライバを実行します。
- **owner 承認後の自動マージ** (`owner-approved-auto-merge.yml`): owner の approve
  をトリガーに auto-merge を有効化します。

## ローカルで使う (opencode セットアップ)

ローカルで opencode を bot 名義で動かす場合の手順です。詳細は
[docs/installation.md](docs/installation.md)。

1. clone して `install.ps1` を実行する。
2. `~/.config/opencode/gh-app/app.env` に `APP_ID` / `INSTALLATION_ID` /
   `PRIVATE_KEY_PATH` / `APP_SLUG` / `BASH_EXE` を設定する。
3. opencode を再起動し、`gh auth status` が bot アカウント (`<slug>[bot]`)
   を示すことを確認する。
4. `conahcnuj <issue番号>` を実行するか、issue を開く。

opencode プラグインの仕組みは [docs/plugin.md](docs/plugin.md) を参照。

## Verified コミット (`git vc`)

コーディングエージェントは `git vc` で Verified 署名付きコミットを作成します。

```sh
git vc -m "message"        # staged の内容をコミット
git vc -m "message" -a     # tracked の作業ツリー変更をコミット
```

詳細は [docs/cli.md](docs/cli.md)。

## 隔離環境で実行する (Docker)

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
- **CI で実トークンの検証が無い**: `mock-test` は offline 検証のみ。実トークンの
  確認はローカルで行う。

## ドキュメント

- サイト: <https://nahcnuj.github.io/conahcnuj/>
- 機械可読な索引: <https://nahcnuj.github.io/conahcnuj/llms.txt>

AI エージェント向けの詳細ルールは [AGENTS.md](AGENTS.md) を参照してください。

## リポジトリ構成

```
.
├── gh-app/                    # シェルスクリプト群（App トークン発行・認証まわり）
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
filePath: /home/runner/work/conahcnuj/conahcnuj/README.md