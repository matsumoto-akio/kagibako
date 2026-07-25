import SwiftUI

/// アプリ内の文字サイズ。標準の .caption(10pt)は、この内容を初めて読む人には小さすぎる。
///
/// 最小は 14pt。これより小さいサイズはアプリ内で使わない。
/// 段落の本文は 15pt にして、補足との差だけを残す。
enum AppFont {
    /// 補足・手順・パスなど。これがアプリの最小サイズ。
    static let small = Font.system(size: 14)
    static let smallBold = Font.system(size: 14, weight: .semibold)
    static let mono = Font.system(size: 14, design: .monospaced)

    /// 読ませたい本文。
    static let body = Font.system(size: 15)
    static let bodyBold = Font.system(size: 15, weight: .semibold)
    static let bodyDigits = Font.system(size: 15).monospacedDigit()
}
