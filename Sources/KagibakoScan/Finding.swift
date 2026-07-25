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

    public init(path: String, lineNumber: Int, kind: String, confidence: Confidence, masked: String) {
        self.path = path
        self.lineNumber = lineNumber
        self.kind = kind
        self.confidence = confidence
        self.masked = masked
    }
}
