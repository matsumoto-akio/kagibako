import Foundation

/// 検証で本当に欲しい数字(何件・どの種類・どこに)だけを組み立てる。
public enum Report {
    public static func render(_ summary: ScanSummary, rootPath: String) -> String {
        let high = summary.findings.filter { $0.confidence == .high }
        let low = summary.findings.filter { $0.confidence == .low }

        let header = """
        ═══════════════════════════════════════════
          カギバコ 平文APIキー棚卸し
        ═══════════════════════════════════════════
        対象        : \(rootPath)
        走査ファイル: \(summary.scannedFileCount) 件(読めず\(summary.unreadableFileCount)件)

        ■ 確実に平文のキー : \(high.count) 件
        ■ 疑わしい記述     : \(low.count) 件
        """

        return ([header, byKindSection(high), fileSection(high), lowSection(low), footer(high.count)])
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private static func byKindSection(_ findings: [Finding]) -> String {
        guard !findings.isEmpty else { return "" }
        let counts = Dictionary(grouping: findings, by: { $0.kind })
            .map { (kind: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
        let rows = counts.map { "  \($0.kind.padded(to: 26)) \($0.count) 件" }
        return (["【種類ごと】"] + rows).joined(separator: "\n")
    }

    private static func fileSection(_ findings: [Finding]) -> String {
        guard !findings.isEmpty else { return "" }
        let byFile = Dictionary(grouping: findings, by: { $0.path })
            .map { (path: $0.key, items: $0.value) }
            .sorted { $0.items.count > $1.items.count }
        let rows = byFile.flatMap { entry -> [String] in
            let lines = entry.items.map { "      L\($0.lineNumber)  \($0.kind)  \($0.masked)" }
            return ["  \(entry.path)"] + lines
        }
        return (["【場所】"] + rows).joined(separator: "\n")
    }

    private static func lowSection(_ findings: [Finding]) -> String {
        guard !findings.isEmpty else { return "" }
        let byFile = Dictionary(grouping: findings, by: { $0.path })
            .map { (path: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(20)
        let rows = byFile.map { "  \($0.path)  (\($0.count))" }
        return (["【疑わしい記述(誤検出を含む・上位20ファイル)】"] + rows).joined(separator: "\n")
    }

    private static func footer(_ highCount: Int) -> String {
        guard highCount > 0 else {
            return "平文のキーは見つかりませんでした。"
        }
        return """
        ───────────────────────────────────────────
        値そのものは表示していません(この出力を人に見せても安全です)。
        該当ファイルを直す前に、まず発行元でキーを再発行するのが安全です。
        ───────────────────────────────────────────
        """
    }
}

private extension String {
    func padded(to width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}
