import SwiftUI
import KagibakoScan

/// 危険度の高い順に並べたファイル一覧と、その場所ごとの手順。
///
/// 手順とコマンドを見せるだけ。実行はしない(再生成されるキャッシュの削除だけが例外)。
struct FileListView: View {
    let result: ScanResult
    let trashedPaths: Set<String>
    let onTrash: (String) -> Void

    @State private var expandedPaths: Set<String> = []
    @State private var expandedCommandPaths: Set<String> = []
    @State private var trashCandidate: String?
    @State private var didExpandFirstFile = false

    var body: some View {
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
                            .font(AppFont.smallBold)
                    }
                }
            }
        }
        .frame(minHeight: 260)
        .onAppear(perform: expandFirstActNowFile)
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
                        .font(AppFont.mono)
                        .textSelection(.enabled)
                    if trashedPaths.contains(group.path) {
                        Text("ゴミ箱に移動済み")
                            .font(AppFont.small)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
                ForEach(Array(group.findings.enumerated()), id: \.offset) { _, finding in
                    Text("L\(finding.lineNumber)  \(finding.kind)  \(finding.masked)")
                        .font(AppFont.small)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
        }
    }

    private func guidanceView(_ group: ScanResult.FileGroup) -> some View {
        let guidance = group.guidance
        return VStack(alignment: .leading, spacing: 8) {
            Text(guidance.title)
                .font(AppFont.bodyBold)

            if let reason = guidance.reason {
                Text("なぜ危ないか: \(reason)")
                    .font(AppFont.small)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(Array(guidance.steps.enumerated()), id: \.offset) { index, step in
                Text("\(index + 1). \(step)")
                    .font(AppFont.small)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !guidance.commands.isEmpty {
                expertCommands(guidance.commands, path: group.path)
            }

            if let caution = guidance.caution {
                Label(caution, systemImage: "exclamationmark.triangle")
                    .font(AppFont.small)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if group.isTrashable, !trashedPaths.contains(group.path) {
                Button("このファイルをゴミ箱に入れる") { trashCandidate = group.path }
                    .font(AppFont.small)
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 4)
    }

    /// コマンドは最後の手段。読めない人が手順の途中で止まらないよう、畳んでおく。
    private func expertCommands(_ commands: [String], path: String) -> some View {
        DisclosureGroup(isExpanded: commandExpansion(of: path)) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(commands.enumerated()), id: \.offset) { _, command in
                    commandRow(command)
                }
            }
            .padding(.top, 4)
        } label: {
            Label("詳しい人向け(ターミナルのコマンド)", systemImage: "terminal")
                .font(AppFont.small)
                .foregroundStyle(.secondary)
        }
    }

    private func commandRow(_ command: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(command)
                .font(AppFont.mono)
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

    private func commandExpansion(of path: String) -> Binding<Bool> {
        Binding(
            get: { expandedCommandPaths.contains(path) },
            set: { isExpanded in
                if isExpanded {
                    expandedCommandPaths.insert(path)
                } else {
                    expandedCommandPaths.remove(path)
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
