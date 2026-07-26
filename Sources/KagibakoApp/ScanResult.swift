import Foundation
import KagibakoScan

/// 画面表示のために ScanSummary を整形したもの。値は一切持たない(マスク済みのみ)。
///
/// 検出は3段階に分ける。主役は `layers`(本物の可能性が高い)だけで、
/// テスト用と誤検出は参考として下に出す。さらに主役の中を危険度で3層に分ける。
/// 分け方の判断は ScanSummary / LocationKind 側にあり、ここでは表示の都合だけを扱う。
struct ScanResult {
    struct FileGroup: Identifiable {
        let path: String
        let findings: [Finding]
        let location: LocationKind

        var id: String { path }
        var displayPath: String { ScanResult.abbreviate(path) }
        var guidance: Remediation.Guidance { Remediation.guidance(for: location, path: path) }
        /// 削除ボタンを出してよいのはキャッシュだけ。それ以外は手順を見せるところで止める。
        var isTrashable: Bool { LocationKind.isTrashable(path: path) }
    }

    /// 危険度ごとのまとまり。同じ危険度でも対処は場所ごとに違うので、手順はファイル単位に持つ。
    struct RiskLayer: Identifiable {
        let risk: Risk
        let groups: [FileGroup]

        var id: Int { risk.rawValue }
        var findingCount: Int { groups.reduce(0) { $0 + $1.findings.count } }
        var fileCount: Int { groups.count }
    }

    struct KindCount: Identifiable {
        let kind: String
        let count: Int

        var id: String { kind }
    }

    let scannedFileCount: Int
    let unreadableFileCount: Int
    /// 本物の可能性が高い検出を、危険度の高い順に並べたもの。中身が空の層は含まない。
    let layers: [RiskLayer]
    let kindCounts: [KindCount]
    /// テスト用・サンプルの可能性が高い検出。
    let testGroups: [FileGroup]
    /// 誤検出の可能性が高い検出(変数名からの推定のみ)。
    let suspiciousCount: Int
    let suspiciousFileCount: Int

    var findingCount: Int { layers.reduce(0) { $0 + $1.findingCount } }
    var fileCount: Int { layers.reduce(0) { $0 + $1.fileCount } }
    var isClean: Bool { findingCount == 0 }

    /// 画面トップの大きな数字。ここだけ見れば、今日やることが決まる。
    var actNowFindingCount: Int { layer(.actNow)?.findingCount ?? 0 }
    var actNowFileCount: Int { layer(.actNow)?.fileCount ?? 0 }

    /// 最初から開いておくファイル。手順がそこにあることを、一目で分かるようにするため。
    var firstActNowPath: String? { layer(.actNow)?.groups.first?.path }

    var testFindingCount: Int { testGroups.reduce(0) { $0 + $1.findings.count } }
    var testFileCount: Int { testGroups.count }

    func layer(_ risk: Risk) -> RiskLayer? {
        layers.first { $0.risk == risk }
    }

    init(summary: ScanSummary) {
        let real = summary.realFindings
        let suspicious = summary.suspiciousFindings

        self.scannedFileCount = summary.scannedFileCount
        self.unreadableFileCount = summary.unreadableFileCount
        self.suspiciousCount = suspicious.count
        self.suspiciousFileCount = Set(suspicious.map(\.path)).count

        self.layers = Risk.allCases.compactMap { risk in
            let groups = ScanResult.grouped(summary.realFindings(risk: risk))
            return groups.isEmpty ? nil : RiskLayer(risk: risk, groups: groups)
        }
        self.testGroups = ScanResult.grouped(summary.testFindings)

        self.kindCounts = Dictionary(grouping: real, by: { $0.kind })
            .map { KindCount(kind: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private static func grouped(_ findings: [Finding]) -> [FileGroup] {
        Dictionary(grouping: findings, by: { $0.path })
            .map { path, items in
                FileGroup(
                    path: path,
                    findings: items.sorted { $0.lineNumber < $1.lineNumber },
                    location: LocationKind.of(path: path)
                )
            }
            .sorted { ($0.findings.count, $1.path) > ($1.findings.count, $0.path) }
    }

    /// ホームディレクトリを `~` に畳む。スクショを人に見せても個人名が出ないようにするため。
    /// 手順とコマンド欄も同じ表記にそろえるため、実体は `PathDisplay` に置いてある。
    static func abbreviate(_ path: String) -> String { PathDisplay.abbreviate(path) }
}
