#!/bin/bash
# カギバコを .app として組み立てる。
# 使い方: ./scripts/build_app.sh   → .build/カギバコ.app ができる
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="カギバコ"
EXECUTABLE="KagibakoApp"
BUNDLE_ID="com.newsfactory.kagibako"
APP_DIR=".build/${APP_NAME}.app"

echo "==> リリースビルド"
swift build -c release --product "${EXECUTABLE}"

echo "==> バンドル組み立て"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp ".build/release/${EXECUTABLE}" "${APP_DIR}/Contents/MacOS/${EXECUTABLE}"

if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
  ICON_ENTRY="<key>CFBundleIconFile</key><string>AppIcon</string>"
else
  ICON_ENTRY=""
fi

BUILD_VERSION="$(git rev-parse --short HEAD 2>/dev/null || echo 'dev')"

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
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>${BUILD_VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    ${ICON_ENTRY}
</dict>
</plist>
PLIST

echo "==> 署名(アドホック)"
codesign --force --deep --sign - "${APP_DIR}"

echo "完成: ${APP_DIR}"
echo "起動: open '${APP_DIR}'"
