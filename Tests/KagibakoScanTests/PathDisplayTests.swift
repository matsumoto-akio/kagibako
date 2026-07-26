import XCTest
@testable import KagibakoScan

/// 手順とコマンド欄に本名(`/Users/akio/...`)が出ないこと。
/// 結果画面はスクリーンショットで人に見せる前提なので、見出しだけでなく全体を `~` にそろえる。
final class PathDisplayTests: XCTestCase {
    private let home = "/Users/akio"

    func test_homeIsFoldedIntoTilde() {
        XCTAssertEqual(PathDisplay.abbreviate("/Users/akio/.zshrc", home: home), "~/.zshrc")
    }

    func test_pathOutsideHomeIsLeftAsIs() {
        XCTAssertEqual(PathDisplay.abbreviate("/etc/hosts", home: home), "/etc/hosts")
    }

    /// `/Users/akio2` が `/Users/akio` に一致してはいけない。
    func test_similarlyNamedHomeIsNotFolded() {
        XCTAssertEqual(PathDisplay.abbreviate("/Users/akio2/.zshrc", home: home), "/Users/akio2/.zshrc")
    }

    /// `"~/.zshrc"` と引用符で囲むと `~` が展開されず、貼り付けても動かないコマンドになる。
    func test_tildeStaysOutsideTheQuotesSoItExpands() {
        XCTAssertEqual(PathDisplay.shellArgument("/Users/akio/.zshrc", home: home), #"~/".zshrc""#)
    }

    /// 空白を含むパスがあるので、引用符自体は外せない。
    func test_pathWithSpacesStaysQuoted() {
        XCTAssertEqual(
            PathDisplay.shellArgument("/Users/akio/My Project/.env", home: home),
            #"~/"My Project/.env""#
        )
    }

    func test_pathOutsideHomeIsQuotedWhole() {
        XCTAssertEqual(PathDisplay.shellArgument("/etc/hosts", home: home), #""/etc/hosts""#)
    }

    /// 全 LocationKind の手順・コマンドにフルパスが残っていないこと。
    func test_noGuidanceLeaksTheHomePath() {
        let realHome = FileManager.default.homeDirectoryForCurrentUser.path
        let path = realHome + "/.hermes/.env"
        for kind in LocationKind.allCases {
            let guidance = Remediation.guidance(for: kind, path: path)
            for text in guidance.steps + guidance.commands {
                XCTAssertFalse(text.contains(realHome), "\(kind) にフルパスが残っています: \(text)")
            }
        }
    }

    /// パスを含むコマンドは `~/"..."` の形になっていること(貼り付けてそのまま動く形)。
    func test_commandsUseExpandableTilde() {
        let realHome = FileManager.default.homeDirectoryForCurrentUser.path
        let path = realHome + "/.hermes/.env"
        for kind in LocationKind.allCases {
            let commands = Remediation.guidance(for: kind, path: path).commands
            for command in commands where command.contains("~") {
                XCTAssertTrue(
                    command.contains(#"~/""#),
                    "\(kind) の `~` が引用符の中に入っています(展開されません): \(command)"
                )
            }
        }
    }
}
