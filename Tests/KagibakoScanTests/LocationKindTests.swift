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

    /// 「なぜ危ないか」を言わずに手順だけ出すと、後回しにされる。
    func test_actNowKindsExplainWhyItIsDangerous() {
        for kind in [LocationKind.shellSnapshot, .shellConfig, .globalToolConfig] {
            let reason = Remediation.guidance(for: kind).reason
            XCTAssertNotNil(reason, "\(kind) に「なぜ危ないか」がありません")
            XCTAssertFalse(reason?.isEmpty ?? true)
        }
    }

    /// 先に失効させると動いているものが止まる。順番を書かないと事故になる。
    func test_shellConfigGuidanceReissuesKeyLast() {
        let steps = Remediation.guidance(for: .shellConfig).steps
        let last = steps.last ?? ""
        XCTAssertTrue(last.contains("失効") || last.contains("再発行"))
        XCTAssertTrue(steps.joined().contains("順番"))
    }

    /// find-generic-password を .zshrc に書くと、結局スナップショットに載る。
    func test_shellConfigGuidanceWarnsAgainstExportingEveryTime() {
        let caution = Remediation.guidance(for: .shellConfig).caution ?? ""
        XCTAssertTrue(caution.contains("export"))
        XCTAssertTrue(caution.contains("スナップショット"))
    }

    /// 全部を一度に直させようとすると手が止まる。
    func test_closingNoteLimitsWhatTheAppClaims() {
        XCTAssertTrue(Remediation.closingNote.contains("場所を教える"))
        XCTAssertTrue(Remediation.closingNote.contains("いますぐ対処"))
    }

    /// 「平文で保存されます」では何が困るのか伝わらない。請求が来るところまで書く。
    func test_whyItMattersIsWrittenAsConsequence() {
        XCTAssertTrue(Remediation.whyItMatters.contains("クレジットカード"))
        XCTAssertTrue(Remediation.whyItMatters.contains("請求"))
    }

    /// 一番多い漏れ方は、難しい攻撃ではなく写り込みと GitHub。
    func test_neverShowNoteNamesTheCommonLeaks() {
        XCTAssertTrue(Remediation.neverShowNote.contains("スクリーンショット"))
        XCTAssertTrue(Remediation.neverShowNote.contains("GitHub"))
    }

    /// そもそも書く必要がない人が多い。金庫より先に「消すだけ」を出す。
    func test_easiestOptionComesFirst() {
        for kind in [LocationKind.shellConfig, .globalToolConfig] {
            let first = Remediation.guidance(for: kind).steps.first ?? ""
            XCTAssertTrue(first.contains("ログイン"), "\(kind) の最初の手順がログイン確認になっていません")
            XCTAssertTrue(first.contains("消すだけ"), "\(kind) の最初の手順に「消すだけ」がありません")
        }
    }

    /// コマンドが読めない層でも進めるように、画面操作の道を必ず用意する。
    func test_keychainHasAGuiRoute() {
        let steps = Remediation.guidance(for: .shellConfig).steps.joined()
        XCTAssertTrue(steps.contains("キーチェーンアクセス"))
    }

    /// 用語は消さない(あとで自分で調べられなくなる)。残して、その場で注釈をつける。
    func test_jargonKeepsItsNameAndGetsAnnotated() {
        let annotations: [String: String] = [
            "環境変数": "パソコン全体で使える設定",
            "キーチェーン": "金庫",
            ".zshrc": "ターミナルの設定ファイル",
            ".gitignore": "GitHubに上げないファイルを指定する設定",
        ]
        for kind in LocationKind.allCases {
            let guidance = Remediation.guidance(for: kind)
            let text = ([guidance.title, guidance.reason ?? "", guidance.caution ?? ""] + guidance.steps).joined()
            for (term, annotation) in annotations where text.contains(term) {
                XCTAssertTrue(
                    text.contains(annotation),
                    "\(kind) が「\(term)」を注釈なしで使っています"
                )
            }
        }
    }
}
