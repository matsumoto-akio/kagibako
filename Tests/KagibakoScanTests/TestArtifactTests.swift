import XCTest
@testable import KagibakoScan

final class TestArtifactPathTests: XCTestCase {
    func test_marksFileUnderTestsDirectory() {
        // Arrange
        let path = "/Users/me/.hermes/hermes-agent/tests/agent/test_redact.py"

        // Act & Assert
        XCTAssertTrue(TestArtifact.isTestPath(path))
    }

    func test_marksSpecFixtureAndMockLocations() {
        XCTAssertTrue(TestArtifact.isTestPath("/Users/me/app/spec/models/user_spec.rb"))
        XCTAssertTrue(TestArtifact.isTestPath("/Users/me/app/fixtures/keys.json"))
        XCTAssertTrue(TestArtifact.isTestPath("/Users/me/app/__mocks__/client.ts"))
        XCTAssertTrue(TestArtifact.isTestPath("/Users/me/app/testdata/sample.env"))
        XCTAssertTrue(TestArtifact.isTestPath("/Users/me/app/internal/client_test.go"))
        XCTAssertTrue(TestArtifact.isTestPath("/Users/me/app/src/MockAPIClient.swift"))
    }

    func test_doesNotMarkOrdinaryPaths() {
        XCTAssertFalse(TestArtifact.isTestPath("/Users/me/Developer/myapp/.env"))
        XCTAssertFalse(TestArtifact.isTestPath("/Users/me/.zshrc"))
        XCTAssertFalse(TestArtifact.isTestPath("/Users/me/.codex/shell_snapshots/snap.sh"))
    }

    /// 部分一致で判定すると `latest` や `protest` を巻き込む。パス要素単位で見ていることの確認。
    func test_doesNotMarkPathsThatMerelyContainTheWordTest() {
        XCTAssertFalse(TestArtifact.isTestPath("/Users/me/latest/config.yml"))
        XCTAssertFalse(TestArtifact.isTestPath("/Users/me/protest/notes.md"))
        XCTAssertFalse(TestArtifact.isTestPath("/Users/me/contest-entry/.env"))
    }
}

final class TestArtifactValueTests: XCTestCase {
    func test_marksTestPrefixedValues() {
        XCTAssertTrue(TestArtifact.isTestValue("sk-test-AbCdEfGhIjKlMnOpQrSt"))
        XCTAssertTrue(TestArtifact.isTestValue("sk_test_51AbCdEfGhIjKlMnOpQrSt"))
        XCTAssertTrue(TestArtifact.isTestValue("pk_test_51AbCdEfGhIjKlMnOpQrSt"))
    }

    func test_doesNotMarkRealLookingValues() {
        XCTAssertFalse(TestArtifact.isTestValue("sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789"))
        XCTAssertFalse(TestArtifact.isTestValue("AKIAIOSFODNN7REALKEY0"))
    }
}

final class FindingSeparationTests: XCTestCase {
    func test_detectorFlagsKeysFoundInTestFiles() throws {
        // Arrange
        let detector = try Detector()
        let text = "ANTHROPIC_API_KEY=sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789"

        // Act
        let inTest = detector.scan(text: text, path: "/Users/me/app/tests/test_redact.py")
        let inReal = detector.scan(text: text, path: "/Users/me/app/.env")

        // Assert
        XCTAssertEqual(inTest.first?.isLikelyTest, true)
        XCTAssertEqual(inReal.first?.isLikelyTest, false)
    }

    func test_summarySplitsRealTestAndSuspicious() {
        // Arrange
        let real = Finding(path: "/a/.env", lineNumber: 1, kind: "Anthropic", confidence: .high, masked: "sk-ant-****(108文字)")
        let fromTest = Finding(path: "/a/tests/t.py", lineNumber: 2, kind: "Anthropic", confidence: .high, masked: "sk-ant-****(108文字)", isLikelyTest: true)
        let suspicious = Finding(path: "/a/app.js", lineNumber: 3, kind: "汎用(変数名から推定)", confidence: .low, masked: "api_key****(40文字)")
        let summary = ScanSummary(
            findings: [real, fromTest, suspicious],
            scannedFileCount: 3,
            unreadableFileCount: 0
        )

        // Act & Assert
        XCTAssertEqual(summary.realFindings, [real])
        XCTAssertEqual(summary.testFindings, [fromTest])
        XCTAssertEqual(summary.suspiciousFindings, [suspicious])
    }

    /// 主役の数字にテスト用が混ざっていないこと。製品として最も守りたい性質。
    func test_realFindingsExcludeTestArtifacts() throws {
        // Arrange
        let detector = try Detector()
        let secretLine = "ANTHROPIC_API_KEY=sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789"
        let findings = detector.scan(text: secretLine, path: "/a/tests/fixtures/keys.env")
        let summary = ScanSummary(findings: findings, scannedFileCount: 1, unreadableFileCount: 0)

        // Act & Assert
        XCTAssertTrue(summary.realFindings.isEmpty)
        XCTAssertEqual(summary.testFindings.count, 1)
    }
}
