# MornSlackWorkReminder

Slackで個人チャンネル（`_` か `times` で始まるチャンネル）を開くと「仕事しろ」と警告するメニューバー常駐アプリです。macOS 14以降。

## インストール

```sh
brew install --cask tsukumistudio/tap/mornslackworkreminder
```

初回起動時に「システム設定 > プライバシーとセキュリティ > アクセシビリティ」で MornSlackWorkReminder を許可し、アプリを起動し直してください。

## 使い方

- メニューバーの⚠️を左クリックで設定、右クリックで終了メニューが開きます。
- 設定では警告する曜日・時間帯（初期値は平日 9:40〜18:30）、3分以上の滞在での警告、除外チャンネル、ログイン時の起動を変えられます。
- 更新は設定画面右下の「最新を確認」「最新へ更新」からできます。

## アンインストール

```sh
brew uninstall --cask --zap mornslackworkreminder
```
