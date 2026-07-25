import Foundation

public enum SecretPatternError: Error, CustomStringConvertible {
    case invalidRegex(kind: String, underlying: Error)

    public var description: String {
        switch self {
        case let .invalidRegex(kind, underlying):
            return "検出パターンの構築に失敗しました (\(kind)): \(underlying)"
        }
    }
}

/// 1種類のシークレットを表す検出パターン。
public struct SecretPattern: Sendable {
    public let kind: String
    public let confidence: Confidence
    private let regex: NSRegularExpression

    private init(kind: String, confidence: Confidence, expression: String) throws {
        do {
            self.regex = try NSRegularExpression(pattern: expression)
        } catch {
            throw SecretPatternError.invalidRegex(kind: kind, underlying: error)
        }
        self.kind = kind
        self.confidence = confidence
    }

    /// 行の中から最初の一致を返す。無ければ nil。
    public func firstMatch(in line: String) -> String? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let matchedRange = Range(match.range, in: line) else { return nil }
        return String(line[matchedRange])
    }

    /// 全パターン。ベンダー固有(high)を先に、汎用(low)を後に並べる。
    public static func compiled() throws -> [SecretPattern] {
        try definitions.map { try SecretPattern(kind: $0.kind, confidence: $0.confidence, expression: $0.expression) }
    }

    private static let definitions: [(kind: String, confidence: Confidence, expression: String)] = [
        ("Anthropic", .high, "sk-ant-[A-Za-z0-9_-]{20,}"),
        ("OpenAI", .high, "sk-(?!ant-)(?:proj-)?[A-Za-z0-9_-]{20,}"),
        ("Google", .high, "AIza[0-9A-Za-z_-]{35}"),
        ("GitHub", .high, "gh[pousr]_[A-Za-z0-9]{36,}"),
        ("GitHub(PAT)", .high, "github_pat_[A-Za-z0-9_]{50,}"),
        ("Slack", .high, "xox[baprs]-[A-Za-z0-9-]{10,}"),
        ("AWS", .high, "AKIA[0-9A-Z]{16}"),
        ("Stripe(本番)", .high, "[sr]k_live_[A-Za-z0-9]{20,}"),
        ("HuggingFace", .high, "hf_[A-Za-z0-9]{30,}"),
        ("Google(OAuthシークレット)", .high, "GOCSPX-[A-Za-z0-9_-]{20,}"),
        ("汎用(変数名から推定)", .low, "(?i)(?:api[_-]?key|secret|token|password|passwd)[\"']?\\s*[=:]\\s*[\"']?[A-Za-z0-9/+_-]{20,}"),
    ]
}
