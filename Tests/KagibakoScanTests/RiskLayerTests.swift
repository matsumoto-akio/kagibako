import XCTest
@testable import KagibakoScan

private let home = "/Users/tester"

private func finding(_ path: String, isLikelyTest: Bool = false) -> Finding {
    Finding(
        path: path,
        lineNumber: 1,
        kind: "Anthropic",
        confidence: .high,
        masked: "sk-ant-****(108文字)",
        isLikelyTest: isLikelyTest
    )
}

final class RiskLayerTests: XCTestCase {
    private let summary = ScanSummary(
        findings: [
            finding("\(home)/.zshrc"),
            finding("\(home)/.codex/shell_snapshots/a.sh"),
            finding("\(home)/Documents/.env"),
            finding("\(home)/Developer/app/.env"),
            finding("\(home)/tests/fixtures/.env", isLikelyTest: true),
            Finding(
                path: "\(home)/.zshrc",
                lineNumber: 9,
                kind: "汎用(変数名から推定)",
                confidence: .low,
                masked: "abcdefg****(30文字)"
            ),
        ],
        scannedFileCount: 100,
        unreadableFileCount: 0
    )

    /// トップの大きな数字はここ。フラットな27件では、どこから手を付けるか決められない。
    func test_splitsRealFindingsByRisk() {
        XCTAssertEqual(summary.realFindings(risk: .actNow, home: home).count, 2)
        XCTAssertEqual(summary.realFindings(risk: .shouldCheck, home: home).count, 1)
        XCTAssertEqual(summary.realFindings(risk: .likelyFine, home: home).count, 1)
    }

    /// 危険度の分類は「本物」枠の中だけの話。テスト用と誤検出は参考枠に残す。
    func test_riskLayersDoNotSwallowTheOtherTwoTiers() {
        let layered = Risk.allCases.flatMap { summary.realFindings(risk: $0, home: home) }
        XCTAssertEqual(layered.count, summary.realFindings.count)
        XCTAssertEqual(summary.testFindings.count, 1)
        XCTAssertEqual(summary.suspiciousFindings.count, 1)
    }
}
