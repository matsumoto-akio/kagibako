import SwiftUI
import KagibakoScan

/// 結果画面を組み立てる部品。3ステップ表示と「全部まとめて見る」の両方から同じものを使う。
/// どちらか片方だけ直して食い違うのを避けるため、部品はここに1つだけ置く。

/// 0件の人には「何もしなくていい」とはっきり言う。
/// 曖昧に終わらせると、分からないまま不安だけが残る。
struct ResultHeadline: View {
    let result: ScanResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if result.actNowFindingCount == 0 {
                Label("いますぐ対処した方がいいキーは見つかりませんでした", systemImage: "checkmark.circle.fill")
                    .font(.title2.bold())
                    .foregroundStyle(.green)
                Text("このままで大丈夫です。何もしなくて構いません。")
                    .font(.title3)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(result.actNowFindingCount)")
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("件は、いますぐ対処した方がいいキーです")
                        .font(.title3.bold())
                }
                Text("\(result.actNowFileCount) ファイル。ほうっておくと勝手に増える場所と、ターミナルを開くたびに読み込まれる場所です。")
                    .font(AppFont.body)
                    .foregroundStyle(.secondary)
            }
            if !result.isClean {
                Text("本物の可能性が高い検出は全部で \(result.findingCount) 件 / \(result.fileCount) ファイルです。")
                    .font(AppFont.small)
                    .foregroundStyle(.secondary)
            }
            Text("\(result.scannedFileCount) ファイルを確認しました。")
                .font(AppFont.small)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 「平文で保存されます」だけでは、何が困るのか伝わらない。
struct WhyItMattersBox: View {
    var body: some View {
        Text(Remediation.whyItMatters)
            .font(AppFont.body)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// 件数だけ出して手順をファイルの中に隠すと、次に何をすればいいか分からない。
/// 全体の答えは常に見えている状態にする。
struct TodoSummaryBox: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("やることは3つです")
                .font(AppFont.bodyBold)
            step(1, "スナップショットをゴミ箱に入れる(このアプリのボタンから)")
            step(2, ".zshrc の export を消して、キーチェーンに移す")
            step(3, "プロジェクトの .env は .gitignore に入っているか確認する")
            Text("※ ファイルごとの詳しい手順は、次の画面で出ます")
                .font(AppFont.small)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(number).")
                .font(AppFont.bodyDigits)
                .foregroundStyle(.secondary)
            Text(text)
                .font(AppFont.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 一番多い漏れ方は難しい攻撃ではない。0件の人にも必ず見せる。
struct NeverShowNoteBox: View {
    var body: some View {
        Label(Remediation.neverShowNote, systemImage: "eye.slash")
            .font(AppFont.bodyBold)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct KindSummaryChips: View {
    let counts: [ScanResult.KindCount]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(counts) { item in
                    Text("\(item.kind) \(item.count)")
                        .font(AppFont.small)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
    }
}

/// 参考枠。ここの数字は主役と混ぜない。混ぜると全体が信用されなくなるため。
struct ReferenceSection: View {
    let result: ScanResult

    @State private var isShowingTestFiles = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if result.testFileCount > 0 {
                DisclosureGroup(isExpanded: $isShowingTestFiles) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(result.testGroups) { group in
                            Text("\(group.displayPath)  (\(group.findings.count))")
                                .font(AppFont.mono)
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
                    .font(AppFont.small)
                }
            }

            if result.suspiciousCount > 0 {
                Label(
                    "誤検出の可能性が高い: \(result.suspiciousCount) 件 / \(result.suspiciousFileCount) ファイル(変数名からの推定のみ)",
                    systemImage: "questionmark.circle"
                )
                .font(AppFont.small)
                .foregroundStyle(.secondary)
            }

            if result.testFileCount == 0, result.suspiciousCount == 0 {
                Label("参考として出すものはありませんでした。", systemImage: "checkmark")
                    .font(AppFont.small)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NotesSection: View {
    let result: ScanResult
    let trashFailure: String?

    var body: some View {
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
        .font(AppFont.small)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
