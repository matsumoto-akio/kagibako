#!/bin/sh
set -eu

# 配布パイプライン: ビルド → Developer ID 署名(Hardened Runtime) → DMG →
# 公証 → staple → GitHub Release 公開。
# 使い方: scripts/release.sh <version>   例: scripts/release.sh 0.1.0
#
# 公証まででいったん止めたい場合: SKIP_PUBLISH=1 scripts/release.sh 0.1.0

if [ $# -ne 1 ]; then
    echo "使い方: $0 <version>" >&2
    exit 1
fi

version="$1"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_bundle="$repo_root/.build/カギバコ.app"
dist_dir="$repo_root/.build/dist"
# ダウンロードされるファイル名は ASCII に固定する(ブラウザやSNSでの
# URLエンコード崩れを避けるため)。ボリューム名だけ日本語にする。
dmg_path="$dist_dir/Kagibako-${version}.dmg"
release_notes="$repo_root/docs/release-notes/v${version}.md"
icon_path="$repo_root/docs/assets/AppIcon.icns"
identity_name="Developer ID Application"
notary_profile="AC_NOTARY"
# 公開先はハードコードする。ローカルの origin が非公開リポジトリを指していた
# ために誤公開した実例(rimlight v0.2.1)があるため。
release_repo="matsumoto-akio/kagibako"

cd "$repo_root"

echo "==> [1/7] リリースビルド"
APP_VERSION="$version" ./scripts/build_app.sh

echo "==> [2/7] 署名 ($identity_name, Hardened Runtime)"
identity="$(security find-identity -v -p codesigning | grep "$identity_name" | head -1 | sed -E 's/.*"(.*)"/\1/')"
if [ -z "$identity" ]; then
    echo "ERROR: '$identity_name' の証明書がキーチェーンに見つかりません。" >&2
    echo "Apple Developer Program で Developer ID Application 証明書を発行し、" >&2
    echo "キーチェーンアクセスにインストールしてから再実行してください。" >&2
    exit 1
fi
# バンドルの中身は実行ファイルとicnsだけで、入れ子のフレームワークや
# ヘルパーは無い。--deep は将来入れ子が増えたときの保険として残す。
codesign --force --deep --options runtime --timestamp \
    --sign "$identity" "$app_bundle"
codesign --verify --deep --strict --verbose=2 "$app_bundle"

echo "==> [3/7] DMG作成(ボリュームアイコン付き)"
mkdir -p "$dist_dir"
rm -f "$dmg_path"
if command -v create-dmg >/dev/null 2>&1; then
    create-dmg --volname "カギバコ ${version}" --volicon "$icon_path" \
        --app-drop-link 400 200 "$dmg_path" "$app_bundle"
else
    # hdiutil にはボリュームアイコン指定が無いので、いったん書き込み可能な
    # イメージを作り、ルートに .VolumeIcon.icns を置いてカスタムアイコン
    # フラグを立ててから、圧縮読み取り専用DMGへ変換する。
    rw_dmg="$dist_dir/Kagibako-${version}-rw.dmg"
    rm -f "$rw_dmg"
    hdiutil create -volname "カギバコ ${version}" -srcfolder "$app_bundle" \
        -ov -format UDRW "$rw_dmg"
    rw_mount="$(mktemp -d)"
    hdiutil attach "$rw_dmg" -mountpoint "$rw_mount" -nobrowse -quiet
    cp "$icon_path" "$rw_mount/.VolumeIcon.icns"
    SetFile -a C "$rw_mount"
    hdiutil detach "$rw_mount" -quiet
    rmdir "$rw_mount"
    hdiutil convert "$rw_dmg" -format UDZO -o "$dmg_path" -ov
    rm -f "$rw_dmg"
fi

echo "==> [4/7] 公証"
if ! xcrun notarytool history --keychain-profile "$notary_profile" >/dev/null 2>&1; then
    echo "ERROR: notarytool のキーチェーンプロファイル '$notary_profile' が未設定です。" >&2
    echo "先に以下を実行してください(App用パスワードまたはApp Store Connect APIキーが必要):" >&2
    echo "  xcrun notarytool store-credentials \"$notary_profile\" \\" >&2
    echo "    --apple-id <Apple ID> --team-id <Team ID> --password <App用パスワード>" >&2
    exit 1
fi
xcrun notarytool submit "$dmg_path" --keychain-profile "$notary_profile" --wait

echo "==> [5/7] staple と検証"
xcrun stapler staple "$dmg_path"
xcrun stapler validate "$dmg_path"
# DMGに直接 spctl をかけると誤って rejected と出る(DMGコンテナ自体は
# 署名対象ではなく、署名されているのは中の .app のため)。マウントして
# 中のアプリを検証する。
mount_point="$(mktemp -d)"
hdiutil attach "$dmg_path" -mountpoint "$mount_point" -nobrowse -quiet
spctl -a -vv "$mount_point/カギバコ.app"
hdiutil detach "$mount_point" -quiet
rmdir "$mount_point"

echo "==> [6/7] DMGファイル自体のFinderアイコン設定"
# 見た目だけの処理(手順3で設定したボリュームアイコンとは別に、外側の
# .dmg ファイル自身のリソースフォークにアイコンを埋める)。公証・staple・
# spctl 検証がすべて通った後の最終ステップとして実行する。
icon_tmp="$(mktemp /tmp/kagibako-dmg-icon.XXXXXX).icns"
icon_rsrc="$(mktemp /tmp/kagibako-dmg-icon.XXXXXX).rsrc"
cp "$icon_path" "$icon_tmp"
# sips -i で icns データを自己参照の 'icns' リソースとしてリソースフォークへ
# 埋め込む。DeRez はリソースフォークからしか抽出できず、iconutil が吐く
# データフォークの icns からは直接取り出せないため、この経由が要る。
sips -i "$icon_tmp" >/dev/null
DeRez -only icns "$icon_tmp" > "$icon_rsrc"
Rez -append "$icon_rsrc" -o "$dmg_path"
SetFile -a C "$dmg_path"
rm -f "$icon_tmp" "$icon_rsrc"

if [ "${SKIP_PUBLISH:-0}" = "1" ]; then
    echo "SKIP_PUBLISH=1 のため公開はしません。"
    echo "公証済みDMG: $dmg_path"
    exit 0
fi

echo "==> [7/7] GitHub Release を $release_repo へ公開"
if [ ! -f "$release_notes" ]; then
    echo "ERROR: リリースノートが見つかりません: $release_notes" >&2
    exit 1
fi
if ! gh repo view "$release_repo" >/dev/null 2>&1; then
    echo "ERROR: リポジトリ $release_repo が存在しない(または権限が無い)ため公開できません。" >&2
    echo "公証済みDMGは $dmg_path に残っています。" >&2
    echo "リポジトリ作成後に再実行してください。" >&2
    exit 1
fi
printf 'v%s を %s (公開リポジトリ) へ公開します。よろしいですか？ [y/N]: ' \
    "$version" "$release_repo"
read -r confirm_publish
case "$confirm_publish" in
    y|Y|yes|YES) ;;
    *)
        echo "公開を中止しました。DMGは $dmg_path に残っています。" >&2
        exit 1
        ;;
esac
gh release create "v${version}" "$dmg_path" \
    --repo "$release_repo" \
    --title "カギバコ v${version}" \
    --notes-file "$release_notes"

echo "完了: v${version} を $release_repo へ公開しました。DMG: $dmg_path"
