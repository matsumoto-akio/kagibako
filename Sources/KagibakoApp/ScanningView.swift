import SwiftUI

struct ScanningView: View {
    let scannedFileCount: Int
    let currentPath: String
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .controlSize(.large)

            Text("調べています…")
                .font(.title3.bold())

            Text("\(scannedFileCount) ファイル")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text(currentPath.isEmpty ? " " : currentPath)
                .font(AppFont.small)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)

            Button("やめる", action: onCancel)
                .controlSize(.large)

            Spacer()
        }
    }
}
