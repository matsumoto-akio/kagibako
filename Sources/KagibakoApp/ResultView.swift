import SwiftUI

struct ResultView: View {
    let result: ScanResult
    let onCopy: () -> Void
    let onRescan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headline
            if !result.isClean {
                kindSummary
                fileList
            }
            notes
            actions
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            if result.isClean {
                Text("平文のAPIキーは見つかりませんでした")
                    .font(.title2.bold())
                    .foregroundStyle(.green)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(result.fileCount)")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("個のファイルに、キーがそのまま書かれています")
                        .font(.title3.bold())
                }
                Text("見つかった箇所は \(result.findingCount) 件です。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text("\(result.scannedFileCount) ファイルを確認しました。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var kindSummary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(result.kindCounts) { item in
                    Text("\(item.kind) \(item.count)")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
    }

    private var fileList: some View {
        List(result.groups) { group in
            VStack(alignment: .leading, spacing: 4) {
                Text(group.displayPath)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                ForEach(Array(group.findings.enumerated()), id: \.offset) { _, finding in
                    Text("L\(finding.lineNumber)  \(finding.kind)  \(finding.masked)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
        }
        .frame(minHeight: 200)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !result.isClean {
                Label("直す前に、まず発行元でキーを再発行するのが安全です。", systemImage: "arrow.clockwise")
            }
            if result.suspiciousCount > 0 {
                Label("ほかに疑わしい記述が \(result.suspiciousCount) 件ありました(誤検出を含みます)。", systemImage: "questionmark.circle")
            }
            if result.unreadableFileCount > 0 {
                Label(
                    "\(result.unreadableFileCount) 件は読めませんでした。デスクトップや書類の中まで調べるには、システム設定 → プライバシーとセキュリティ → フルディスクアクセス でこのアプリを許可してください。",
                    systemImage: "lock"
                )
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var actions: some View {
        HStack {
            Button("結果をコピー(値は含まれません)", action: onCopy)
            Spacer()
            Button("もう一度調べる", action: onRescan)
        }
    }
}
