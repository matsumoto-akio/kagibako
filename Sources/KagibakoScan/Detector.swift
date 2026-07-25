import Foundation

/// テキスト1本を受け取り、平文シークレットらしき箇所を返す。
///
/// ファイルI/Oは持たない(純関数に近い形に保つ)。テストしやすさのため。
public struct Detector {
    private let patterns: [SecretPattern]

    public init(patterns: [SecretPattern]) {
        self.patterns = patterns
    }

    public init() throws {
        self.init(patterns: try SecretPattern.compiled())
    }

    public func scan(text: String, path: String) -> [Finding] {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .flatMap { index, line in
                findings(inLine: String(line), lineNumber: index + 1, path: path)
            }
    }

    private func findings(inLine line: String, lineNumber: Int, path: String) -> [Finding] {
        guard !isPlaceholder(line), !isEnvironmentReference(line) else { return [] }

        let matches = patterns.compactMap { pattern -> Finding? in
            guard let matched = pattern.firstMatch(in: line) else { return nil }
            return Finding(
                path: path,
                lineNumber: lineNumber,
                kind: pattern.kind,
                confidence: pattern.confidence,
                masked: Masking.mask(matched)
            )
        }

        // 同じ行がベンダー固有と汎用の両方に当たった場合、確度の高い方だけを残す。
        let highConfidence = matches.filter { $0.confidence == .high }
        return deduplicated(highConfidence.isEmpty ? matches : highConfidence)
    }

    /// 複数のパターンが同一箇所に当たった場合、先に定義された(より具体的な)方を残す。
    private func deduplicated(_ findings: [Finding]) -> [Finding] {
        findings.reduce(into: [Finding]()) { unique, finding in
            let isDuplicate = unique.contains { $0.lineNumber == finding.lineNumber && $0.masked == finding.masked }
            if !isDuplicate { unique.append(finding) }
        }
    }

    /// `YOUR_API_KEY` や `sk-xxxxxxxx` のようなドキュメント上の見本を除外する。
    private func isPlaceholder(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return placeholderMarkers.contains { lowered.contains($0) }
    }

    /// 既に環境変数・シークレット管理から読んでいる行は「平文」ではない。
    private func isEnvironmentReference(_ line: String) -> Bool {
        let lowered = line.lowercased()
        return environmentMarkers.contains { lowered.contains($0) }
    }

    private let placeholderMarkers = [
        "your_", "your-", "yourkey", "xxxx", "<", "example", "sample",
        "dummy", "placeholder", "changeme", "取得したキー", "ここに",
    ]

    private let environmentMarkers = [
        "process.env", "os.environ", "os.getenv", "env[", "${", "$(",
        "op://", "keychain", "secretsmanager", "getenv(",
    ]
}
