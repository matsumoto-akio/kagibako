#!/bin/bash
# カギバコを .app として組み立てる。
# 使い方: ./scripts/build_app.sh   → .build/カギバコ.app ができる
#
# バージョンは release.sh から APP_VERSION で渡される。
# 単体で叩いたときは下の既定値が使われる(rimlightで版数の二重管理がずれた
# 実例があるため、ここでは既定値のみを持ち release.sh を正とする)。
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="カギバコ"
EXECUTABLE="KagibakoApp"
BUNDLE_ID="com.newsfactory.kagibako"
APP_DIR=".build/${APP_NAME}.app"
APP_VERSION="${APP_VERSION:-0.1.0}"
ICON_SOURCE="docs/assets/AppIcon.icns"

echo "==> リリースビルド"
swift build -c release --product "${EXECUTABLE}"

echo "==> バンドル組み立て (v${APP_VERSION})"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp ".build/release/${EXECUTABLE}" "${APP_DIR}/Contents/MacOS/${EXECUTABLE}"

if [ -f "${ICON_SOURCE}" ]; then
  cp "${ICON_SOURCE}" "${APP_DIR}/Contents/Resources/AppIcon.icns"
  ICON_ENTRY="<key>CFBundleIconFile</key><string>AppIcon</string>"
else
  echo "警告: ${ICON_SOURCE} が無いためアイコン無しで組み立てます(./scripts/make_icns.sh で生成)" >&2
  ICON_ENTRY=""
fi

BUILD_VERSION="$(git rev-parse --short HEAD 2>/dev/null || echo 'dev')"

# デスクトップ・書類・ダウンロードは TCC の確認ダイアログが出る。
# 「なぜ読むのか」を説明しないと、セキュリティ用途のアプリほど怪しく見えるため必ず書く。
FOLDER_REASON="このMacに平文で保存されたAPIキーを数えるために、フォルダの中を読み取ります。読み取るだけで、書き換えや外部送信は行いません。"

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleExecutable</key><string>${EXECUTABLE}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key><string>Copyright (c) 2026 akio matsumoto. MIT License.</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSDesktopFolderUsageDescription</key><string>${FOLDER_REASON}</string>
    <key>NSDocumentsFolderUsageDescription</key><string>${FOLDER_REASON}</string>
    <key>NSDownloadsFolderUsageDescription</key><string>${FOLDER_REASON}</string>
    ${ICON_ENTRY}
</dict>
</plist>
PLIST

echo "==> 署名(アドホック・開発用)"
# 配布用の Developer ID 署名は scripts/release.sh が上書きする。
codesign --force --deep --sign - "${APP_DIR}"

echo "完成: ${APP_DIR}"
echo "起動: open '${APP_DIR}'"
