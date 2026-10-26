# MornSlackWorkReminder

Slackデスクトップアプリで `_` や `times` から始まる個人チャンネルを開くと、指定した曜日・時間帯に「仕事しろ」というWindows XP風の警告を表示するメニューバー常駐アプリです。macOS 14以降、Apple Silicon・Intel両対応。

## インストール

```sh
brew install --cask tsukumistudio/tap/mornslackworkreminder
```

初回起動時に「システム設定 > プライバシーとセキュリティ > アクセシビリティ」で MornSlackWorkReminder を許可します。Slackのウィンドウタイトルからチャンネル名を読むためです。

## 使い方

- メニューバーの⚠️を左クリックで設定、右クリックで「ログイン時に起動」「終了」のメニューを開きます。
- 設定では曜日・時間帯（初期値は月〜金 9:40〜18:30）、3分以上の滞在での警告、除外チャンネル、ログイン時起動を変更できます。左下に版、右下に「最新を確認」「最新へ更新」（`brew upgrade` して自動で再起動）があります。
- Slackのウィンドウタイトル（例: `_foo（チャンネル） - Workspace - Slack`）からチャンネル名を取り出し、`_` または `times` で始まれば個人チャンネルとみなします。
- 警告は常にSlackのウィンドウの直上に重ねて表示します（他アプリのウィンドウより手前には出ません）。最小化・非表示・別Spaceのときは出しません。
- 「OK」「×」はそのウィンドウだけを、Escは全ウィンドウを閉じます。全部閉じてから10秒後に再表示します。
- 1日の警告回数に応じて、1〜5回目は1個、6〜10回目は2個、11回目以降は3個のウィンドウを表示します。
- 「1分停止」は1日3回まで使えます。
- 設定と回数は `UserDefaults`（`com.tsukumistudio.MornSlackWorkReminder`）へ保存します。動作ログは `~/Library/Logs/MornSlackWorkReminder.log`。

## ビルド・リリース

```sh
./build.sh          # build/MornSlackWorkReminder.app
./build.sh dmg      # 上記＋DMG
node --test settings.test.cjs rules.test.cjs
```

- ローカルでは、キーチェーンに「SlackWorkReminder Local Signing」証明書があればそれで署名します（再ビルドしてもアクセシビリティ許可が外れない）。無ければad-hoc署名です。
- `v*` タグをpushすると、GitHub ActionsがMornNotaryで署名・公証し、GitHub Releasesの公開とHomebrew Caskの更新を自動実行します。リポジトリに `MORN_RELEASE_TOKEN` と `HOMEBREW_TAP_TOKEN` のsecretが必要です。
- アイコンは `make-icon.swift` で生成した `AppIcon.icns` です。
