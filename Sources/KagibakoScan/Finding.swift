import Foundation

/// 検出の確からしさ。ベンダー固有の接頭辞を持つものは high。
public enum Confidence: String, Sendable {
    case high
    case low
}

/// 平文キーの検出結果。値そのものは決して保持しない(masked のみ)。
public struct Finding: Equatable, Sendable {
    public let path: String
    public let lineNumber: Int
    public let kind: String
    public let confidence: Confidence
    public let masked: String
    /// テスト・フィクスチャ・見本の可能性が高い場所/値か。主役の件数から外す判断に使う。
    public let isLikelyTest: Bool

    public init(
        path: String,
        lineNumber: Int,
        kind: String,
        confidence: Confidence,
        masked: String,
        isLikelyTest: Bool = false
    ) {
        self.path = path
        self.lineNumber = lineNumber
        self.kind = kind
        self.confidence = confidence
        self.masked = masked
        self.isLikelyTest = isLikelyTest
    }
}
