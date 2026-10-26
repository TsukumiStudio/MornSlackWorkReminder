#!/bin/sh
# build/MornSlackWorkReminder.app を作る。Xcode不要（Command Line Toolsのswiftcのみ）。
#   ./build.sh          アプリのみ
#   ./build.sh dmg      配布用DMGも作る
# 署名: DEVELOPER_ID="Developer ID Application: …" があればそれ、無ければローカル証明書、それも無ければad-hoc。
# 公証: DMG作成時に NOTARY_PROFILE（xcrun notarytool store-credentials で保存した名前）があれば公証・staple する。
set -eu
cd "$(dirname "$0")"
VERSION=${VERSION:-1.0.0}
APP=build/MornSlackWorkReminder.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for ARCH in arm64 x86_64; do
  swiftc -O -swift-version 5 -target "$ARCH-apple-macos14" -o "build/MornSlackWorkReminder-$ARCH" main.swift
done
lipo -create build/MornSlackWorkReminder-arm64 build/MornSlackWorkReminder-x86_64 -output "$APP/Contents/MacOS/MornSlackWorkReminder"
rm build/MornSlackWorkReminder-arm64 build/MornSlackWorkReminder-x86_64

cp settings.js popup.html popup.css popup.js rules.js popup-mac.js warning.html AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>com.tsukumistudio.MornSlackWorkReminder</string>
  <key>CFBundleName</key><string>MornSlackWorkReminder</string>
  <key>CFBundleDisplayName</key><string>MornSlackWorkReminder</string>
  <key>CFBundleExecutable</key><string>MornSlackWorkReminder</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

# 固定の署名だとアクセシビリティ許可が再ビルド後も残る。
if [ -n "${DEVELOPER_ID:-}" ]; then
  IDENTITY=$DEVELOPER_ID
  TIMESTAMP=--timestamp
else
  IDENTITY="SlackWorkReminder Local Signing"
  security find-identity -v -p codesigning | grep -q "$IDENTITY" || IDENTITY=-
  TIMESTAMP=
fi
codesign --force --options runtime $TIMESTAMP --entitlements entitlements.plist --sign "$IDENTITY" "$APP"
echo "built: $(pwd)/$APP"

[ "${1:-}" = dmg ] || exit 0
DMG=build/MornSlackWorkReminder-$VERSION.dmg
mkdir build/dmg
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -quiet -volname "仕事しろリマインダー" -srcfolder build/dmg -format UDZO "$DMG"
rm -rf build/dmg
codesign --force $TIMESTAMP --sign "$IDENTITY" "$DMG"
if [ -n "${NOTARY_PROFILE:-}" ]; then
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
fi
echo "dmg: $(pwd)/$DMG"
