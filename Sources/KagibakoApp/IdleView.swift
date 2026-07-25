import SwiftUI

struct IdleView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("カギバコ")
                    .font(.system(size: 30, weight: .bold))
                Text("このMacの中に、そのまま置かれているAPIキーを数えます。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                PromiseRow(icon: "wifi.slash", text: "外部に一切送信しません。全部このMacの中だけで動きます。")
                PromiseRow(icon: "eye.slash", text: "キーの中身は画面にも出しません。先頭7文字と文字数だけです。")
                PromiseRow(icon: "hand.raised", text: "読むだけです。ファイルを書き換えたり消したりしません。")
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))

            Button(action: onStart) {
                Text("このMacを調べる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Text("だいたい1〜3分かかります。途中でやめても大丈夫です。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

struct PromiseRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.tint)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
