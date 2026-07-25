import Foundation
import KagibakoScan

/// 進捗を毎ファイル通知するとUIが詰まるので、この件数ごとにまとめて更新する。
private let progressUpdateInterval = 200

@MainActor
final class ScanViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning
        case finished
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var scannedFileCount = 0
    @Published private(set) var currentPath = ""
    @Published private(set) var result: ScanResult?

    let rootPath = FileManager.default.homeDirectoryForCurrentUser.path

    private var task: Task<Void, Never>?

    var isScanning: Bool { phase == .scanning }

    func start() {
        guard !isScanning else { return }

        phase = .scanning
        scannedFileCount = 0
        currentPath = ""
        result = nil

        let root = rootPath
        task = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                // Foundation.Scanner と名前が衝突するため明示する。
                let scanner = KagibakoScan.Scanner(detector: try Detector())
                var processed = 0
                let summary = scanner.scan(
                    rootPath: root,
                    isCancelled: { Task.isCancelled },
                    onProgress: { path in
                        processed += 1
                        guard processed % progressUpdateInterval == 0 else { return }
                        let count = processed
                        Task { @MainActor [weak self] in
                            self?.updateProgress(count: count, path: path)
                        }
                    }
                )
                guard !Task.isCancelled else { return }
                await self?.finish(with: summary)
            } catch {
                await self?.fail(with: error)
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    /// マスク済みのテキスト。値は含まれないので、そのまま人に見せられる。
    func reportText() -> String? {
        guard let summary = lastSummary else { return nil }
        return Report.render(summary, rootPath: ScanResult.abbreviate(rootPath))
    }

    private var lastSummary: ScanSummary?

    private func updateProgress(count: Int, path: String) {
        guard isScanning else { return }
        scannedFileCount = count
        currentPath = ScanResult.abbreviate(path)
    }

    private func finish(with summary: ScanSummary) {
        lastSummary = summary
        scannedFileCount = summary.scannedFileCount
        currentPath = ""
        result = ScanResult(summary: summary)
        phase = .finished
        task = nil
    }

    private func fail(with error: Error) {
        phase = .failed(String(describing: error))
        task = nil
    }
}
