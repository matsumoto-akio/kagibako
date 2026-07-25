import Foundation

public struct ScanSummary: Sendable {
    public let findings: [Finding]
    public let scannedFileCount: Int
    public let unreadableFileCount: Int

    public init(findings: [Finding], scannedFileCount: Int, unreadableFileCount: Int) {
        self.findings = findings
        self.scannedFileCount = scannedFileCount
        self.unreadableFileCount = unreadableFileCount
    }
}

/// 検出結果を3段階に分ける。CLIとアプリで同じ数字を出すため、
/// 分け方はここ1箇所だけに置く。
public extension ScanSummary {
    /// 本物の可能性が高い。画面の主役にする数字。
    var realFindings: [Finding] {
        findings.filter { $0.confidence == .high && !$0.isLikelyTest }
    }

    /// テスト用・サンプルの可能性が高い。参考として別枠で出す。
    var testFindings: [Finding] {
        findings.filter { $0.confidence == .high && $0.isLikelyTest }
    }

    /// 変数名からの推定のみ。誤検出の可能性が高い。
    var suspiciousFindings: [Finding] {
        findings.filter { $0.confidence == .low }
    }
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
