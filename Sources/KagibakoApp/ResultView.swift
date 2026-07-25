import SwiftUI
import KagibakoScan

struct ResultView: View {
    let result: ScanResult
    let trashedPaths: Set<String>
    let trashFailure: String?
    let onCopy: () -> Void
    let onRescan: () -> Void
    let onTrash: (String) -> Void

    @State private var isShowingTestFiles = false
    @State private var expandedPaths: Set<String> = []
    @State private var trashCandidate: String?
    @State private var didExpandFirstFile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headline
            if result.actNowFindingCount > 0 {
                todoSummary
            }
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
                    Text("\(result.actNowFindingCount)")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(result.actNowFindingCount > 0 ? .orange : .green)
                    Text(
                        result.actNowFindingCount > 0
                            ? "件は、いますぐ対処した方がいいキーです"
                            : "件。いますぐ対処が要るものはありませんでした"
                    )
                    .font(.title3.bold())
                }
                if result.actNowFindingCount > 0 {
                    Text("\(result.actNowFileCount) ファイル。勝手に増える場所と、シェル全体に読み込まれる場所です。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text("本物の可能性が高い検出は全部で \(result.findingCount) 件 / \(result.fileCount) ファイルです。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("\(result.scannedFileCount) ファイルを確認しました。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// 件数だけ出して手順をファイルの中に隠すと、次に何をすればいいか分からない。
    /// 全体の答えは常に見えている状態にする。
    private var todoSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("やることは3つです")
                .font(.callout.bold())
            todoStep(1, "スナップショットをゴミ箱に入れる(このアプリのボタンから)")
            todoStep(2, ".zshrc の export を消して、キーチェーンに移す")
            todoStep(3, "プロジェクトの .env は .gitignore に入っているか確認する")
            Text("※ ファイルごとの詳しい手順は、各ファイルを開くと出ます")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func todoStep(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(number).")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
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

    /// 危険度の高い順に並べる。同じ枠の中でも、対処の内容はファイルごとに違う。
    private var fileList: some View {
        List {
            ForEach(result.layers) { layer in
                Section {
                    ForEach(layer.groups) { group in
                        fileRow(group)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: icon(for: layer.risk))
                            .foregroundStyle(color(for: layer.risk))
                        Text("\(layer.risk.label)  \(layer.findingCount) 件 / \(layer.fileCount) ファイル")
                            .font(.caption.bold())
                    }
                }
            }
        }
        .frame(minHeight: 260)
        .onAppear(perform: expandFirstActNowFile)
    }

    /// 一番上の1件だけ開いておく。手順が畳まれた中にあることに気づけないため。
    private func expandFirstActNowFile() {
        guard !didExpandFirstFile, let path = result.firstActNowPath else { return }
        didExpandFirstFile = true
        expandedPaths.insert(path)
    }

    private func fileRow(_ group: ScanResult.FileGroup) -> some View {
        DisclosureGroup(isExpanded: expansion(of: group.path)) {
            guidanceView(group)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.displayPath)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                    if trashedPaths.contains(group.path) {
                        Text("ゴミ箱に移動済み")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                ForEach(Array(group.findings.enumerated()), id: \.offset) { _, finding in
                    Text("L\(finding.lineNumber)  \(finding.kind)  \(finding.masked)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
        }
    }

    /// 手順とコマンドを見せるだけ。実行はしない(キャッシュの削除だけが例外)。
    private func guidanceView(_ group: ScanResult.FileGroup) -> some View {
        let guidance = group.guidance
        return VStack(alignment: .leading, spacing: 8) {
            Text(guidance.title)
                .font(.callout.bold())

            if let reason = guidance.reason {
                Text("なぜ危ないか: \(reason)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(guidance.steps.enumerated()), id: \.offset) { index, step in
                Text("\(index + 1). \(step)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(guidance.commands.enumerated()), id: \.offset) { _, command in
                commandRow(command)
            }

            if let caution = guidance.caution {
                Label(caution, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if group.isTrashable, !trashedPaths.contains(group.path) {
                Button("このファイルをゴミ箱に入れる") { trashCandidate = group.path }
                    .font(.caption)
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 4)
    }

    private func commandRow(_ command: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(command)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            Button {
                copy(command)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("コマンドをコピー(実行はしません)")
        }
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
                Label(
                    "このアプリはファイルを書き換えません。手順を見せるところまでです(再生成されるキャッシュのみ、ゴミ箱に移せます)。",
                    systemImage: "hand.raised"
                )
                Label(Remediation.closingNote, systemImage: "hand.wave")
            }
            if let trashFailure {
                Label(trashFailure, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
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
        .confirmationDialog(
            "ゴミ箱に移動しますか?",
            isPresented: Binding(
                get: { trashCandidate != nil },
                set: { if !$0 { trashCandidate = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("ゴミ箱に入れる", role: .destructive) {
                if let path = trashCandidate { onTrash(path) }
                trashCandidate = nil
            }
            Button("やめる", role: .cancel) { trashCandidate = nil }
        } message: {
            Text("削除しても Codex の起動で再生成されます。根本を直すにはシェル設定の修正が必要です。")
        }
    }

    private func expansion(of path: String) -> Binding<Bool> {
        Binding(
            get: { expandedPaths.contains(path) },
            set: { isExpanded in
                if isExpanded {
                    expandedPaths.insert(path)
                } else {
                    expandedPaths.remove(path)
                }
            }
        )
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func icon(for risk: Risk) -> String {
        switch risk {
        case .actNow: return "exclamationmark.triangle.fill"
        case .shouldCheck: return "eye"
        case .likelyFine: return "checkmark.circle"
        }
    }

    private func color(for risk: Risk) -> Color {
        switch risk {
        case .actNow: return .orange
        case .shouldCheck: return .yellow
        case .likelyFine: return .secondary
        }
    }
}
