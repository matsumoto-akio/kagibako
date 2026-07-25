import XCTest
@testable import KagibakoScan

final class DetectorTests: XCTestCase {
    private func makeDetector() throws -> Detector {
        try Detector()
    }

    func test_detectsAnthropicKeyAsHighConfidence() throws {
        // Arrange
        let detector = try makeDetector()
        let text = "ANTHROPIC_API_KEY=sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789"

        // Act
        let findings = detector.scan(text: text, path: "/tmp/.env")

        // Assert
        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.kind, "Anthropic")
        XCTAssertEqual(findings.first?.confidence, .high)
    }

    func test_neverExposesRawSecretValue() throws {
        // Arrange
        let detector = try makeDetector()
        let secret = "sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789"

        // Act
        let findings = detector.scan(text: "KEY=\(secret)", path: "/tmp/.env")

        // Assert
        let masked = try XCTUnwrap(findings.first?.masked)
        XCTAssertFalse(masked.contains("AbCdEfGh"))
        XCTAssertTrue(masked.hasPrefix("sk-ant-"))
    }

    func test_reportsCorrectLineNumber() throws {
        // Arrange
        let detector = try makeDetector()
        let text = ["# メモ", "", "OPENAI_API_KEY=sk-proj-AbCdEfGhIjKlMnOpQrStUvWx0123"].joined(separator: "\n")

        // Act
        let findings = detector.scan(text: text, path: "/tmp/.env")

        // Assert
        XCTAssertEqual(findings.first?.lineNumber, 3)
    }

    func test_ignoresPlaceholderSamples() throws {
        // Arrange
        let detector = try makeDetector()
        let text = [
            "OPENAI_API_KEY=your_api_key_here_xxxxxxxxxxxxxxxxxx",
            "ANTHROPIC_API_KEY=<sk-ant-api03-ここに取得したキーを貼る>",
        ].joined(separator: "\n")

        // Act
        let findings = detector.scan(text: text, path: "/tmp/README.md")

        // Assert
        XCTAssertTrue(findings.isEmpty)
    }

    func test_ignoresEnvironmentVariableReferences() throws {
        // Arrange
        let detector = try makeDetector()
        let text = [
            "const apiKey = process.env.OPENAI_API_KEY",
            "export ANTHROPIC_API_KEY=$(security find-generic-password -w -s anthropic)",
        ].joined(separator: "\n")

        // Act
        let findings = detector.scan(text: text, path: "/tmp/app.js")

        // Assert
        XCTAssertTrue(findings.isEmpty)
    }

    /// `task-abstraction-...` の中の `sk-...` を拾ってしまう事故があった。
    /// 単語の途中から始まる一致は、キーではなくただの英文。
    func test_ignoresKeyLikeSubstringsInsideWords() throws {
        // Arrange
        let detector = try makeDetector()
        let text = [
            "foundations/task-abstraction-and-layering",
            "'Asterisk-linking-protocol-exception'",
            "モデルは huggingface_hf_abcdefghijklmnopqrstuvwxyz012345 ではない",
        ].joined(separator: "\n")

        // Act
        let findings = detector.scan(text: text, path: "/tmp/doc.md")

        // Assert
        XCTAssertTrue(findings.isEmpty, "英文の一部を拾っています: \(findings.map(\.masked))")
    }

    func test_stillDetectsKeyAtStartOfLineAndAfterSeparators() throws {
        // Arrange
        let detector = try makeDetector()
        let text = [
            "sk-ant-api03-AbCdEfGhIjKlMnOpQrStUvWxYz0123456789",
            "  \"key\": \"AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R\"",
        ].joined(separator: "\n")

        // Act
        let findings = detector.scan(text: text, path: "/tmp/config.json")

        // Assert
        XCTAssertEqual(findings.count, 2)
    }

    /// `sk-or-v1-` は OpenRouter のキー。OpenAI と表示すると、利用者が
    /// 止めるべきサービスを間違える。種類名の誤りは検出漏れと同じくらい信用を削る。
    func test_labelsOpenRouterKeyAsOpenRouter() throws {
        // Arrange
        let detector = try makeDetector()
        let text = "OPENROUTER_API_KEY=sk-or-v1-0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

        // Act
        let findings = detector.scan(text: text, path: "/tmp/.env")

        // Assert
        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.kind, "OpenRouter")
    }

    func test_stillLabelsGenuineOpenAIKeyAsOpenAI() throws {
        // Arrange
        let detector = try makeDetector()
        let text = "OPENAI_API_KEY=sk-proj-AbCdEfGhIjKlMnOpQrStUvWx0123"

        // Act
        let findings = detector.scan(text: text, path: "/tmp/.env")

        // Assert
        XCTAssertEqual(findings.first?.kind, "OpenAI")
    }

    func test_prefersHighConfidenceOverGenericOnSameLine() throws {
        // Arrange
        let detector = try makeDetector()
        let text = "api_key: AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q7R"

        // Act
        let findings = detector.scan(text: text, path: "/tmp/config.yml")

        // Assert
        XCTAssertEqual(findings.count, 1)
        XCTAssertEqual(findings.first?.confidence, .high)
    }
}

final class ScanTargetsTests: XCTestCase {
    func test_scansDotEnvVariants() {
        XCTAssertTrue(ScanTargets.shouldScan(fileName: ".env"))
        XCTAssertTrue(ScanTargets.shouldScan(fileName: ".env.local"))
        XCTAssertTrue(ScanTargets.shouldScan(fileName: ".zshrc"))
        XCTAssertTrue(ScanTargets.shouldScan(fileName: "config.toml"))
    }

    func test_skipsBinaryAndMediaFiles() {
        XCTAssertFalse(ScanTargets.shouldScan(fileName: "photo.jpg"))
        XCTAssertFalse(ScanTargets.shouldScan(fileName: "video.mp4"))
    }

    func test_skipsDependencyDirectories() {
        XCTAssertTrue(ScanTargets.shouldSkip(directoryName: "node_modules"))
        XCTAssertTrue(ScanTargets.shouldSkip(directoryName: "Library"))
        XCTAssertTrue(ScanTargets.shouldSkip(directoryName: "site-packages"))
        XCTAssertTrue(ScanTargets.shouldSkip(directoryName: "vendor"))
        XCTAssertTrue(ScanTargets.shouldSkip(directoryName: ".venv"))
        XCTAssertTrue(ScanTargets.shouldSkip(directoryName: "Pods"))
        XCTAssertTrue(ScanTargets.shouldSkip(directoryName: "extensions"))
        XCTAssertTrue(ScanTargets.shouldSkip(directoryName: ".tmp"))
        XCTAssertFalse(ScanTargets.shouldSkip(directoryName: "Developer"))
    }
}
