import SwiftUI

struct ResultView: View {
    let result: ScanResult
    let onCopy: () -> Void
    let onRescan: () -> Void

    @State private var isShowingTestFiles = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headline
            if !result.isClean {
                kindSummary
                fileList
            }
            reference
            notes
            actions
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            if result.isClean {
                Text("本物らしい平文のAPIキーは見つかりませんでした")
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
            fileRow(group)
        }
        .frame(minHeight: 200)
    }

    private func fileRow(_ group: ScanResult.FileGroup) -> some View {
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

    /// 参考枠。ここの数字は主役と混ぜない。混ぜると全体が信用されなくなるため。
    @ViewBuilder
    private var reference: some View {
        if result.testFileCount > 0 || result.suspiciousCount > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                Text("参考")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                if result.testFileCount > 0 {
                    DisclosureGroup(isExpanded: $isShowingTestFiles) {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(result.testGroups) { group in
                                Text("\(group.displayPath)  (\(group.findings.count))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(.top, 4)
                    } label: {
                        Label(
                            "テスト用・サンプルの可能性が高い: \(result.testFindingCount) 件 / \(result.testFileCount) ファイル",
                            systemImage: "flask"
                        )
                        .font(.caption)
                    }
                }

                if result.suspiciousCount > 0 {
                    Label(
                        "誤検出の可能性が高い: \(result.suspiciousCount) 件 / \(result.suspiciousFileCount) ファイル(変数名からの推定のみ)",
                        systemImage: "questionmark.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !result.isClean {
                Label("直す前に、まず発行元でキーを再発行するのが安全です。", systemImage: "arrow.clockwise")
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
