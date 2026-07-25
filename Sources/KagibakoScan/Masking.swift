import Foundation

/// 検出した値を、絶対に復元できない形へ落とすためのユーティリティ。
///
/// スキャナは「どこに何件あるか」だけを扱う道具であり、
/// 値そのものを画面・ログ・ファイルへ出してはならない。
public enum Masking {
    /// 先頭に残す文字数。ベンダーを識別できる最小限に留める。
    private static let visiblePrefixLength = 7

    public static func mask(_ raw: String) -> String {
        let prefix = String(raw.prefix(visiblePrefixLength))
        return "\(prefix)****(\(raw.count)文字)"
    }
}
