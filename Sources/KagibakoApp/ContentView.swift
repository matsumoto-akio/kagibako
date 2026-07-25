import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ScanViewModel()

    var body: some View {
        Group {
            switch viewModel.phase {
            case .idle:
                IdleView(onStart: viewModel.start)
            case .scanning:
                ScanningView(
                    scannedFileCount: viewModel.scannedFileCount,
                    currentPath: viewModel.currentPath,
                    onCancel: viewModel.cancel
                )
            case .finished:
                if let result = viewModel.result {
                    ResultView(
                        result: result,
                        trashedPaths: viewModel.trashedPaths,
                        trashFailure: viewModel.trashFailure,
                        onCopy: { copyToPasteboard(viewModel.reportText()) },
                        onRescan: viewModel.start,
                        onTrash: viewModel.moveToTrash
                    )
                } else {
                    IdleView(onStart: viewModel.start)
                }
            case let .failed(message):
                FailureView(message: message, onRetry: viewModel.start)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func copyToPasteboard(_ text: String?) {
        guard let text else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

struct FailureView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text("調べられませんでした")
                .font(.title2.bold())
            Text(message)
                .font(AppFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("もう一度試す", action: onRetry)
                .keyboardShortcut(.defaultAction)
        }
    }
}
