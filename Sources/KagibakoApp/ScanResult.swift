import Foundation
import KagibakoScan

/// 画面表示のために ScanSummary を整形したもの。値は一切持たない(マスク済みのみ)。
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
    let groups: [FileGroup]
    let kindCounts: [KindCount]
    let suspiciousCount: Int

    var findingCount: Int { groups.reduce(0) { $0 + $1.findings.count } }
    var fileCount: Int { groups.count }
    var isClean: Bool { findingCount == 0 }

    init(summary: ScanSummary) {
        let high = summary.findings.filter { $0.confidence == .high }

        self.scannedFileCount = summary.scannedFileCount
        self.unreadableFileCount = summary.unreadableFileCount
        self.suspiciousCount = summary.findings.count - high.count

        self.groups = Dictionary(grouping: high, by: { $0.path })
            .map { FileGroup(path: $0.key, findings: $0.value.sorted { $0.lineNumber < $1.lineNumber }) }
            .sorted { ($0.findings.count, $1.path) > ($1.findings.count, $0.path) }

        self.kindCounts = Dictionary(grouping: high, by: { $0.kind })
            .map { KindCount(kind: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    /// ホームディレクトリを `~` に畳む。スクショを人に見せても個人名が出ないようにするため。
    static func abbreviate(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard path.hasPrefix(home) else { return path }
        return "~" + path.dropFirst(home.count)
    }
}
