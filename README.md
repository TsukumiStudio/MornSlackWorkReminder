# MornSlackWorkReminder

Slackデスクトップアプリで個人チャンネル（`_` や `times` で始まるチャンネル）を開くと、「仕事しろ」というWindows XP風の警告を出すメニューバー常駐アプリです。macOS 14以降、Apple Silicon・Intel両対応。

## インストール

```sh
brew install --cask tsukumistudio/tap/mornslackworkreminder
```

初回起動時に「システム設定 > プライバシーとセキュリティ > アクセシビリティ」で MornSlackWorkReminder を許可し、アプリを起動し直します。Slackのウィンドウタイトルからチャンネル名を読むために必要です。

アンインストールは `brew uninstall --cask --zap mornslackworkreminder` です（設定とログも消えます）。

## 使い方

メニューバーの⚠️を左クリックすると設定、右クリックすると「ログイン時に起動」「終了」のメニューが開きます。

### 個人チャンネルの判定

Slackのウィンドウタイトル（例: `_foo（チャンネル） - Workspace - Slack`）からチャンネル名を取り出し、`_` または `times` で始まれば個人チャンネルとみなします（大文字小文字は区別しません）。`dev-times` のように途中に含むだけのものは対象外です。

### 警告が出る条件

リマインダーが有効で、除外していない個人チャンネルを開いているとき、次のどちらかで警告します。

- 設定した曜日・時間帯に入っている（初期値は月〜金 9:40〜18:30）
- 同じチャンネルを3分以上開いている（時間帯・曜日に関係なく。設定で無効化可）

### 警告の動き

- 警告はSlackのウィンドウの直上に重ねて表示します。Slackが他アプリの裏にあっても見えている部分に出ますが、他アプリのウィンドウより手前には出ません。最小化・非表示・別Spaceのときは出さず、Mission Controlにも表示しません。
- 「OK」「×」はそのウィンドウだけを、Escは全ウィンドウを閉じます。
- 警告が消えたら、Slackを前面で10秒使うまで次の警告は出ません（別アプリを使っている間は数えません）。個人チャンネル同士を移動しても警告は消えません。
- 1日の警告回数に応じて、1〜5回目は1個、6〜10回目は2個、11回目以降は3個のウィンドウを表示します。日付が変わるとリセットします。
- 「1分停止」は1日3回まで使えます。

### 設定画面

- 曜日・時間帯、3分以上の滞在での警告、除外チャンネル（名前を1行に1件）を編集して「設定を保存」します。保存すると1分停止も解除します。
- 「ログイン時に起動」はトグルで即時に切り替わります。
- 左下に版、右下に「最新を確認」「最新へ更新」があります。更新は `brew update` → `brew upgrade` を行い、終わると自動で起動し直します。

### 保存先

- 設定と回数: `UserDefaults`（`com.tsukumistudio.MornSlackWorkReminder`）
- 動作ログ: `~/Library/Logs/MornSlackWorkReminder.log`（検知したチャンネル名・警告の表示・更新の結果）

## 開発

| ファイル | 役割 |
|---|---|
| `main.swift` | アプリ本体（Slackウィンドウの取得、警告パネル、メニュー、保存、更新） |
| `settings.js` | 設定の検証と警告条件の判定 |
| `rules.js` | ウィンドウタイトルからチャンネル名を取り出す処理 |
| `popup.html` / `popup.css` / `popup.js` | 設定画面 |
| `popup-mac.js` | 設定画面のネイティブ連携部品（ログイン時起動・版・更新・大きさ合わせ） |
| `warning.html` | 警告画面 |
| `make-icon.swift` | `AppIcon.icns` の生成 |

```sh
./build.sh          # build/MornSlackWorkReminder.app
./build.sh dmg      # 上記＋DMG
node --test settings.test.cjs rules.test.cjs
```

- ローカルでは、キーチェーンに「SlackWorkReminder Local Signing」証明書があればそれで署名します（再ビルドしてもアクセシビリティ許可が外れない）。無ければad-hoc署名です。
- `v*` タグをpushすると、GitHub ActionsがMornNotaryで署名・公証し、GitHub Releasesの公開とHomebrew Caskの更新を自動で行います。リポジトリに `MORN_RELEASE_TOKEN` と `HOMEBREW_TAP_TOKEN` のsecretが必要です。
