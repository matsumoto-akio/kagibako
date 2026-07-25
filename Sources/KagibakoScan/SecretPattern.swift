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

    /// 単語の途中から始まる一致を禁じる先読み。
    ///
    /// これが無いと `task-abstraction-and-layering` の中の `sk-abstraction-...` を
    /// OpenAIキーとして拾う(実測で9ファイルが誤検出になっていた)。
    /// キーは必ず行頭・空白・記号の直後から始まる。
    private static let wordStart = "(?<![A-Za-z0-9_])"

    private static let definitions: [(kind: String, confidence: Confidence, expression: String)] = [
        ("Anthropic", .high, wordStart + "sk-ant-[A-Za-z0-9_-]{20,}"),
        // sk- で始まる他社キーは OpenAI より先に判定する。
        // 発行元を取り違えると、利用者が止めるべきサービスを間違える。
        ("OpenRouter", .high, wordStart + "sk-or-v1-[A-Za-z0-9]{20,}"),
        ("OpenAI", .high, wordStart + "sk-(?!ant-|or-v1-)(?:proj-)?[A-Za-z0-9_-]{20,}"),
        ("Google", .high, wordStart + "AIza[0-9A-Za-z_-]{35}"),
        ("GitHub", .high, wordStart + "gh[pousr]_[A-Za-z0-9]{36,}"),
        ("GitHub(PAT)", .high, wordStart + "github_pat_[A-Za-z0-9_]{50,}"),
        ("Slack", .high, wordStart + "xox[baprs]-[A-Za-z0-9-]{10,}"),
        ("AWS", .high, wordStart + "AKIA[0-9A-Z]{16}"),
        ("Stripe(本番)", .high, wordStart + "[sr]k_live_[A-Za-z0-9]{20,}"),
        ("HuggingFace", .high, wordStart + "hf_[A-Za-z0-9]{30,}"),
        ("Google(OAuthシークレット)", .high, wordStart + "GOCSPX-[A-Za-z0-9_-]{20,}"),
        ("汎用(変数名から推定)", .low, "(?i)(?:api[_-]?key|secret|token|password|passwd)[\"']?\\s*[=:]\\s*[\"']?[A-Za-z0-9/+_-]{20,}"),
    ]
}
