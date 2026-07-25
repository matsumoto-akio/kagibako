import SwiftUI
import KagibakoScan

/// 結果画面。1画面に全部出すと情報量が多すぎるので、3ステップに分ける。
///
/// 1. 結果とやること  2. ファイルごとの対処  3. 参考と注意書き
/// 慣れている人は「全部まとめて見る」で従来の1画面表示に切り替えられる。
struct ResultView: View {
    let result: ScanResult
    let trashedPaths: Set<String>
    let trashFailure: String?
    let onCopy: () -> Void
    let onRescan: () -> Void
    let onTrash: (String) -> Void

    private enum Step {
        case summary
        case files
        case reference
    }

    @State private var step: Step = .summary
    @State private var isShowingEverything = false

    var body: some View {
        if isShowingEverything {
            everything
        } else {
            switch step {
            case .summary: summaryStep
            case .files: filesStep
            case .reference: referenceStep
            }
        }
    }

    // MARK: - 画面1: 結果とやること

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("調べ終わりました")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ResultHeadline(result: result)
                    if result.actNowFindingCount > 0 {
                        WhyItMattersBox()
                        TodoSummaryBox()
                    }
                    NeverShowNoteBox()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            HStack {
                Button("全部まとめて見る") { isShowingEverything = true }
                    .buttonStyle(.link)
                    .font(.caption)
                Spacer()
                summaryStepButton
            }
        }
    }

    /// 0件の人に「対処をはじめる」は出さない。押す必要がないため。
    @ViewBuilder
    private var summaryStepButton: some View {
        if result.actNowFindingCount > 0 {
            Button("対処をはじめる") { step = .files }
                .keyboardShortcut(.defaultAction)
        } else if !result.isClean {
            Button("見つかったファイルを確認する") { step = .files }
                .keyboardShortcut(.defaultAction)
        } else {
            Button("調べた内容と注意点を見る") { step = .reference }
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - 画面2: 各ファイルの対処

    private var filesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("見つかったファイルと、その対処")
                .font(.callout.bold())
            KindSummaryChips(counts: result.kindCounts)
            FileListView(result: result, trashedPaths: trashedPaths, onTrash: onTrash)
            HStack {
                Button("結果の要約に戻る") { step = .summary }
                Spacer()
                Button("ほかの検出結果を見る") { step = .reference }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - 画面3: 参考

    private var referenceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("参考")
                        .font(.callout.bold())
                    ReferenceSection(result: result)
                    Divider()
                    NotesSection(result: result, trashFailure: trashFailure)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
            HStack {
                if !result.isClean {
                    Button("ファイルの対処に戻る") { step = .files }
                }
                Button("結果をコピー(値は含まれません)", action: onCopy)
                Spacer()
                Button("もう一度調べる", action: onRescan)
                Button("最初に戻る") { step = .summary }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - 従来の1画面表示

    private var everything: some View {
        VStack(alignment: .leading, spacing: 16) {
            ResultHeadline(result: result)
            if result.actNowFindingCount > 0 {
                WhyItMattersBox()
                TodoSummaryBox()
            }
            if !result.isClean {
                KindSummaryChips(counts: result.kindCounts)
                FileListView(result: result, trashedPaths: trashedPaths, onTrash: onTrash)
            }
            if result.testFileCount > 0 || result.suspiciousCount > 0 {
                Divider()
                Text("参考")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                ReferenceSection(result: result)
            }
            NotesSection(result: result, trashFailure: trashFailure)
            NeverShowNoteBox()
            HStack {
                Button("3ステップの表示に戻す") { isShowingEverything = false }
                    .buttonStyle(.link)
                    .font(.caption)
                Spacer()
                Button("結果をコピー(値は含まれません)", action: onCopy)
                Button("もう一度調べる", action: onRescan)
            }
        }
    }
}
