import Foundation

/// どのファイルを見るか / どのディレクトリを避けるかの判断だけを持つ。
public enum ScanTargets {
    /// 走査対象にするファイルの上限サイズ。これを超えるものはデータファイルとみなす。
    public static let maxFileSizeBytes = 2 * 1024 * 1024

    /// 中身を見に行かないディレクトリ。依存物とキャッシュで時間を溶かさないため。
    public static let skippedDirectoryNames: Set<String> = [
        "node_modules", ".git", "Library", ".Trash", "Pods", ".build",
        "DerivedData", "venv", ".venv", "__pycache__", ".next", "dist",
        "build", "target", "Applications", ".cache", ".npm", "vendor",
        "Movies", "Music", "Pictures", ".gradle", ".rustup", ".cargo",
        "site-packages", ".terraform",
    ]

    /// 拡張子が無い/特殊でも必ず見るファイル名。
    private static let alwaysScannedFileNames: Set<String> = [
        ".zshrc", ".zprofile", ".zshenv", ".bashrc", ".bash_profile", ".profile",
        ".netrc", ".npmrc", ".pypirc", ".claude.json", ".mcp.json",
        "credentials", "settings.json", "config.toml", "mcp.json",
    ]

    private static let scannedExtensions: Set<String> = [
        "env", "sh", "zsh", "bash", "json", "toml", "yml", "yaml", "txt",
        "md", "py", "js", "ts", "jsx", "tsx", "rb", "go", "swift", "php",
        "ini", "cfg", "conf", "properties", "plist", "xml", "java", "rs",
    ]

    public static func shouldScan(fileName: String) -> Bool {
        if fileName.hasPrefix(".env") { return true }
        if alwaysScannedFileNames.contains(fileName) { return true }
        let ext = (fileName as NSString).pathExtension.lowercased()
        return scannedExtensions.contains(ext)
    }

    public static func shouldSkip(directoryName: String) -> Bool {
        skippedDirectoryNames.contains(directoryName)
    }
}
