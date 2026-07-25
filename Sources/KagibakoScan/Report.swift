import Foundation

/// 検証で本当に欲しい数字(何件・どの種類・どこに)だけを組み立てる。
///
/// 3段階に分けて出す。主役は「本物の可能性が高い」だけで、
/// テスト用と誤検出は参考として下に置く。混ぜて大きな数を出すと、
/// 数字そのものが信用されなくなるため。
public enum Report {
    public static func render(_ summary: ScanSummary, rootPath: String) -> String {
        let real = summary.realFindings
        let test = summary.testFindings
        let suspicious = summary.suspiciousFindings

        let actNow = summary.realFindings(risk: .actNow)

        let header = """
        ═══════════════════════════════════════════
          カギバコ 平文APIキー棚卸し
        ═══════════════════════════════════════════
        対象        : \(rootPath)
        走査ファイル: \(summary.scannedFileCount) 件(読めず\(summary.unreadableFileCount)件)

        ■ いますぐ対処      : \(actNow.count) 件 / \(fileCount(actNow)) ファイル
          (本物の可能性が高い検出は全部で \(real.count) 件 / \(fileCount(real)) ファイル)
        ── 以下は参考 ──────────────────────────────
        ■ テスト用・サンプル : \(test.count) 件 / \(fileCount(test)) ファイル
        ■ 誤検出の可能性が高い: \(suspicious.count) 件 / \(fileCount(suspicious)) ファイル
        """

        let sections = [
            header,
            actNow.isEmpty ? "" : Remediation.whyItMatters,
            byKindSection(real),
            riskSections(summary),
            referenceSection("【参考: テスト用・サンプルの可能性が高い】", test),
            referenceSection("【参考: 誤検出の可能性が高い(変数名からの推定のみ)】", suspicious),
            footer(real.count),
        ]
        return sections.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    private static func fileCount(_ findings: [Finding]) -> Int {
        Set(findings.map(\.path)).count
    }

    private static func byKindSection(_ findings: [Finding]) -> String {
        guard !findings.isEmpty else { return "" }
        let counts = Dictionary(grouping: findings, by: { $0.kind })
            .map { (kind: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
        let rows = counts.map { "  \($0.kind.padded(to: 26)) \($0.count) 件" }
        return (["【種類ごと】"] + rows).joined(separator: "\n")
    }

    /// 場所を危険度の高い順に並べる。フラットな一覧では、どれから手を付けるか決められない。
    private static func riskSections(_ summary: ScanSummary) -> String {
        let sections = Risk.allCases.compactMap { risk -> String? in
            let findings = summary.realFindings(risk: risk)
            guard !findings.isEmpty else { return nil }
            return fileSection("【\(risk.label)】", findings)
        }
        return sections.joined(separator: "\n\n")
    }

    private static func fileSection(_ title: String, _ findings: [Finding]) -> String {
        guard !findings.isEmpty else { return "" }
        let byFile = Dictionary(grouping: findings, by: { $0.path })
            .map { (path: $0.key, items: $0.value) }
            .sorted { $0.items.count > $1.items.count }
        let rows = byFile.flatMap { entry -> [String] in
            let lines = entry.items.map { "      L\($0.lineNumber)  \($0.kind)  \($0.masked)" }
            let guidance = Remediation.guidance(for: LocationKind.of(path: entry.path), path: entry.path)
            return ["  \(entry.path)"] + lines + ["      → \(guidance.title)"]
        }
        return ([title] + rows).joined(separator: "\n")
    }

    /// 参考枠はファイル単位の件数だけにする。主役の数字を埋もれさせないため。
    private static func referenceSection(_ title: String, _ findings: [Finding]) -> String {
        guard !findings.isEmpty else { return "" }
        let byFile = Dictionary(grouping: findings, by: { $0.path })
            .map { (path: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
        let shown = byFile.prefix(referenceFileLimit)
        let rows = shown.map { "  \($0.path)  (\($0.count))" }
        let omitted = byFile.count - shown.count
        let note = omitted > 0 ? ["  ほか \(omitted) ファイル"] : []
        return ([title] + rows + note).joined(separator: "\n")
    }

    private static let referenceFileLimit = 20

    private static let reissueOrderLines = Remediation.reissueOrder
        .enumerated()
        .map { "\($0.offset + 1). \($0.element)" }
        .joined(separator: "\n")

    private static func footer(_ realCount: Int) -> String {
        guard realCount > 0 else {
            return """
            いますぐ対処した方がいいキーは見つかりませんでした。
            このままで大丈夫です。何もしなくて構いません。

            \(Remediation.neverShowNote)
            """
        }
        return """
        ───────────────────────────────────────────
        値そのものは表示していません(この出力を人に見せても安全です)。

        キーを作り直すときは、この順番で行ってください。
        \(reissueOrderLines)
        ※ \(Remediation.reissueOrderCaution)

        \(Remediation.neverShowNote)

        \(Remediation.closingNote)
        ───────────────────────────────────────────
        """
    }
}

private extension String {
    func padded(to width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}
