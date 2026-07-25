import SwiftUI

/// アプリ内の文字サイズ。標準の .caption(10pt)は、この内容を初めて読む人には小さすぎる。
///
/// 最小は 12pt。これより小さいサイズはアプリ内で使わない。
/// 段落の本文は 13pt にして、補足との差だけを残す。
enum AppFont {
    /// 補足・手順・パスなど。これがアプリの最小サイズ。
    static let small = Font.system(size: 12)
    static let smallBold = Font.system(size: 12, weight: .semibold)
    static let mono = Font.system(size: 12, design: .monospaced)

    /// 読ませたい本文。
    static let body = Font.system(size: 13)
    static let bodyBold = Font.system(size: 13, weight: .semibold)
    static let bodyDigits = Font.system(size: 13).monospacedDigit()
}
