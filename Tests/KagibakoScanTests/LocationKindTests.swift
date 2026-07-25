import XCTest
@testable import KagibakoScan

private let home = "/Users/tester"

private func kind(_ path: String) -> LocationKind {
    LocationKind.of(path: path, home: home)
}

final class LocationKindTests: XCTestCase {
    func test_shellConfigIsActNow() {
        XCTAssertEqual(kind("\(home)/.zshrc"), .shellConfig)
        XCTAssertEqual(kind("\(home)/.bashrc"), .shellConfig)
        XCTAssertEqual(kind("\(home)/.zprofile"), .shellConfig)
        XCTAssertEqual(LocationKind.shellConfig.risk, .actNow)
    }

    func test_shellSnapshotIsActNow() {
        let path = "\(home)/.codex/shell_snapshots/019f9824-3057.sh"
        XCTAssertEqual(kind(path), .shellSnapshot)
        XCTAssertEqual(LocationKind.shellSnapshot.risk, .actNow)
    }

    func test_globalToolConfigIsActNow() {
        XCTAssertEqual(kind("\(home)/.claude/settings.local.json"), .globalToolConfig)
        XCTAssertEqual(kind("\(home)/.hermes/config.yaml"), .globalToolConfig)
        XCTAssertEqual(kind("\(home)/.hermes/.env"), .globalToolConfig)
        XCTAssertEqual(LocationKind.globalToolConfig.risk, .actNow)
    }

    /// 認証ファイルは、隠しディレクトリの中にあってもツール設定より先に判定する。
    /// 消すのではなく発行元での再発行が要るため、案内する手順が違う。
    func test_authFileIsShouldCheckEvenInsideHiddenDirectory() {
        XCTAssertEqual(kind("\(home)/.hermes/auth.json"), .authFile)
        XCTAssertEqual(kind("\(home)/Documents/credentials/token.json"), .authFile)
        XCTAssertEqual(kind("\(home)/puchitore/client_secret.json"), .authFile)
        XCTAssertEqual(LocationKind.authFile.risk, .shouldCheck)
    }

    func test_looseEnvDirectlyUnderHomeOrDocumentsIsShouldCheck() {
        XCTAssertEqual(kind("\(home)/.jijipuchi.env"), .looseEnv)
        XCTAssertEqual(kind("\(home)/Documents/.env"), .looseEnv)
        XCTAssertEqual(LocationKind.looseEnv.risk, .shouldCheck)
    }

    /// プロジェクトフォルダの .env は通常の運用。ここを赤くすると、
    /// 本当に危ない場所が埋もれる。
    func test_projectEnvIsLikelyFine() {
        XCTAssertEqual(kind("\(home)/Documents/projects/saki/.env"), .projectEnv)
        XCTAssertEqual(kind("\(home)/Developer/x-research-ai/.env"), .projectEnv)
        XCTAssertEqual(kind("\(home)/Documents/workout-app/.env.local"), .projectEnv)
        XCTAssertEqual(LocationKind.projectEnv.risk, .likelyFine)
    }

    /// 分類できないものを「そのままでよい」に流すと見落としになる。
    func test_unknownLocationFallsBackToShouldCheck() {
        XCTAssertEqual(kind("\(home)/.hermes/hermes-agent/agent/redact.py"), .other)
        XCTAssertEqual(LocationKind.other.risk, .shouldCheck)
    }
}

final class SnapshotCleanupTests: XCTestCase {
    /// 自動削除を許すのは shell_snapshots だけ。ここが緩むと、
    /// ユーザーの環境を壊すツールになる。
    func test_onlyShellSnapshotsMayBeTrashed() {
        XCTAssertTrue(LocationKind.isTrashable(path: "\(home)/.codex/shell_snapshots/a.sh", home: home))
        XCTAssertFalse(LocationKind.isTrashable(path: "\(home)/.zshrc", home: home))
        XCTAssertFalse(LocationKind.isTrashable(path: "\(home)/Documents/.env", home: home))
        XCTAssertFalse(LocationKind.isTrashable(path: "\(home)/.claude/settings.local.json", home: home))
    }
}

final class RemediationTests: XCTestCase {
    func test_everyLocationKindHasSteps() {
        for kind in LocationKind.allCases {
            let guidance = Remediation.guidance(for: kind)
            XCTAssertFalse(guidance.title.isEmpty, "\(kind) に見出しがありません")
            XCTAssertFalse(guidance.steps.isEmpty, "\(kind) に手順がありません")
        }
    }

    /// 消して終わりだと誤解されると、Codex起動で復活して「直っていない」ことになる。
    func test_snapshotGuidanceSaysItComesBack() {
        let guidance = Remediation.guidance(for: .shellSnapshot)
        let text = guidance.steps.joined()
        XCTAssertTrue(text.contains("再生成"))
        XCTAssertTrue(text.contains("シェル設定"))
    }

    func test_shellConfigGuidanceShowsKeychainCommands() {
        let guidance = Remediation.guidance(for: .shellConfig)
        let commands = guidance.commands.joined(separator: "\n")
        XCTAssertTrue(commands.contains("security add-generic-password"))
        XCTAssertTrue(commands.contains("security find-generic-password"))
    }

    /// キーチェーンに移しても実行中のプロセスからは読める。
    /// ここを黙ると効能の誇張になる。
    func test_shellConfigGuidanceDoesNotOverstateKeychain() {
        let text = Remediation.guidance(for: .shellConfig).steps.joined()
        XCTAssertTrue(text.contains("実行"))
    }

    func test_projectEnvGuidanceChecksGitignore() {
        let commands = Remediation.guidance(for: .projectEnv).commands.joined(separator: "\n")
        XCTAssertTrue(commands.contains("check-ignore"))
    }
}
