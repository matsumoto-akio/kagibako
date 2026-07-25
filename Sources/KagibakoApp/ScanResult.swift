import Foundation
import KagibakoScan

/// 画面表示のために ScanSummary を整形したもの。値は一切持たない(マスク済みのみ)。
///
/// 検出は3段階に分ける。主役は `groups`(本物の可能性が高い)だけで、
/// テスト用と誤検出は参考として下に出す。分け方の判断は ScanSummary 側にあり、
/// ここでは表示の都合だけを扱う。
struct ScanResult {
    struct FileGroup: Identifiable {
        let path: String
        let findings: [Finding]

        var id: String { path }
        var displayPath: String { ScanResult.abbreviate(path) }
    }

    struct KindCount: Identifiable {
        let kind: String
        let count: Int

        var id: String { kind }
    }

    let scannedFileCount: Int
    let unreadableFileCount: Int
    /// 本物の可能性が高い検出。ファイル単位。
    let groups: [FileGroup]
    let kindCounts: [KindCount]
    /// テスト用・サンプルの可能性が高い検出。
    let testGroups: [FileGroup]
    /// 誤検出の可能性が高い検出(変数名からの推定のみ)。
    let suspiciousCount: Int
    let suspiciousFileCount: Int

    var findingCount: Int { groups.reduce(0) { $0 + $1.findings.count } }
    var fileCount: Int { groups.count }
    var isClean: Bool { findingCount == 0 }

    var testFindingCount: Int { testGroups.reduce(0) { $0 + $1.findings.count } }
    var testFileCount: Int { testGroups.count }

    init(summary: ScanSummary) {
        let real = summary.realFindings
        let test = summary.testFindings
        let suspicious = summary.suspiciousFindings

        self.scannedFileCount = summary.scannedFileCount
        self.unreadableFileCount = summary.unreadableFileCount
        self.suspiciousCount = suspicious.count
        self.suspiciousFileCount = Set(suspicious.map(\.path)).count

        self.groups = ScanResult.grouped(real)
        self.testGroups = ScanResult.grouped(test)

        self.kindCounts = Dictionary(grouping: real, by: { $0.kind })
            .map { KindCount(kind: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private static func grouped(_ findings: [Finding]) -> [FileGroup] {
        Dictionary(grouping: findings, by: { $0.path })
            .map { FileGroup(path: $0.key, findings: $0.value.sorted { $0.lineNumber < $1.lineNumber }) }
            .sorted { ($0.findings.count, $1.path) > ($1.findings.count, $0.path) }
    }

    /// ホームディレクトリを `~` に畳む。スクショを人に見せても個人名が出ないようにするため。
    static func abbreviate(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard path.hasPrefix(home) else { return path }
        return "~" + path.dropFirst(home.count)
    }
}
