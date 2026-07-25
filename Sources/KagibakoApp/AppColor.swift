import SwiftUI

/// アプリの色。note記事のサムネイル・結果画面の件数がオレンジなので、
/// アクセントもオレンジに揃える(既定の青のままだと起動画面だけ浮く)。
enum AppColor {
    /// アイコン・ボタン・強調。`.tint` としてルートに流し、各所は `.tint` を参照する。
    static let accent = Color.orange
}
