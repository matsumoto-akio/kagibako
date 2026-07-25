import Foundation

public struct ScanSummary: Sendable {
    public let findings: [Finding]
    public let scannedFileCount: Int
    public let unreadableFileCount: Int
}

/// ディレクトリを走査して Detector に食わせる層。
public struct Scanner {
    private let detector: Detector
    private let fileManager: FileManager

    public init(detector: Detector, fileManager: FileManager = .default) {
        self.detector = detector
        self.fileManager = fileManager
    }

    /// - Parameter isCancelled: 中断したい場合に true を返す。GUIの「中止」から使う。
    public func scan(
        rootPath: String,
        isCancelled: () -> Bool = { false },
        onProgress: (String) -> Void = { _ in }
    ) -> ScanSummary {
        let rootURL = URL(fileURLWithPath: rootPath)
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsPackageDescendants]
        ) else {
            return ScanSummary(findings: [], scannedFileCount: 0, unreadableFileCount: 0)
        }

        var findings: [Finding] = []
        var scannedCount = 0
        var unreadableCount = 0

        for case let url as URL in enumerator {
            if isCancelled() { break }
            let name = url.lastPathComponent

            if isDirectory(url) {
                if ScanTargets.shouldSkip(directoryName: name) { enumerator.skipDescendants() }
                continue
            }

            guard ScanTargets.shouldScan(fileName: name), isSmallEnough(url) else { continue }

            switch readText(at: url) {
            case let .some(text):
                scannedCount += 1
                onProgress(url.path)
                findings.append(contentsOf: detector.scan(text: text, path: url.path))
            case .none:
                unreadableCount += 1
            }
        }

        return ScanSummary(
            findings: findings,
            scannedFileCount: scannedCount,
            unreadableFileCount: unreadableCount
        )
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private func isSmallEnough(_ url: URL) -> Bool {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return false }
        return size <= ScanTargets.maxFileSizeBytes
    }

    /// 読めないファイル(権限・バイナリ)は数えるだけにして、走査全体は止めない。
    private func readText(at url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
