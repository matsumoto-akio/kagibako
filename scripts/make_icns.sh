#!/bin/bash
# docs/assets/AppIcon.icns を生成する。
# 使い方: ./scripts/make_icns.sh
set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE_PNG="$(mktemp -t kagibako-icon).png"
ICONSET="$(mktemp -d)/AppIcon.iconset"
OUTPUT="docs/assets/AppIcon.icns"

swift scripts/make_icon.swift "${SOURCE_PNG}"

mkdir -p "${ICONSET}" "$(dirname "${OUTPUT}")"
for size in 16 32 128 256 512; do
  sips -z "${size}" "${size}" "${SOURCE_PNG}" --out "${ICONSET}/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "${double}" "${double}" "${SOURCE_PNG}" --out "${ICONSET}/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "${ICONSET}" -o "${OUTPUT}"
rm -rf "${SOURCE_PNG}" "$(dirname "${ICONSET}")"

echo "完成: ${OUTPUT}"
