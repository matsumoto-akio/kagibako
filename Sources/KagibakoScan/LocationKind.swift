import Foundation

/// 対処の急ぎ具合。27件をフラットに並べても、どこから手を付ければいいか分からない。
public enum Risk: Int, Sendable, Comparable, CaseIterable {
    /// 勝手に増える場所、全シェルに読み込まれる場所。
    case actNow = 0
    /// 置き場所として不自然。中身を見て判断する。
    case shouldCheck = 1
    /// プロジェクト配下の .env など、通常の運用の範囲。
    case likelyFine = 2

    public static func < (lhs: Risk, rhs: Risk) -> Bool { lhs.rawValue < rhs.rawValue }

    public var label: String {
        switch self {
        case .actNow: return "いますぐ対処"
        case .shouldCheck: return "確認した方がいい"
        case .likelyFine: return "そのままでよい可能性が高い"
        }
    }
}

/// キーが置かれている「場所の性格」。危険度と対処手順の両方がここから決まる。
///
/// 危険度だけを持つ enum にしなかったのは、同じ「いますぐ対処」でも
/// やることが全く違うため(キャッシュの削除 / キーチェーンへの移動 / 再ログイン)。
public enum LocationKind: String, Sendable, CaseIterable {
    /// Codex が毎回書き出すシェル環境のスナップショット。キャッシュ。
    case shellSnapshot
    /// .zshrc など。開くシェル全部に読み込まれる。
    case shellConfig
    /// ~/.claude/settings.local.json など、ツールのグローバル設定。
    case globalToolConfig
    /// token.json / auth.json など、発行元での再発行が要るもの。
    case authFile
    /// ホーム直下や Documents 直下に転がっている .env。
    case looseEnv
    /// プロジェクトフォルダ配下の .env。
    case projectEnv
    /// 上のどれでもない。判断を保留する。
    case other

    public var risk: Risk {
        switch self {
        case .shellSnapshot, .shellConfig, .globalToolConfig: return .actNow
        case .authFile, .looseEnv, .other: return .shouldCheck
        case .projectEnv: return .likelyFine
        }
    }

    /// 判定は上から順に。認証ファイルを隠しディレクトリ判定より先に見るのは、
    /// ~/.hermes/auth.json のように両方に当てはまる場所で、案内する手順が
    /// 「再発行」であって「設定から消す」ではないため。
    public static func of(
        path: String,
        home: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> LocationKind {
        let components = path.split(separator: "/").map(String.init)
        let name = components.last ?? ""

        if components.contains(shellSnapshotDirectory) { return .shellSnapshot }
        if shellConfigNames.contains(name) { return .shellConfig }
        if authFileNames.contains(name.lowercased()) { return .authFile }

        let relative = relativeComponents(of: path, under: home)
        if isInsideHiddenToolDirectory(relative), isConfigFile(name) { return .globalToolConfig }
        guard isEnvFile(name) else { return .other }
        // 親がホーム直下 / Documents 直下なら、プロジェクトに属さない置きっぱなし。
        return relative.count <= 2 ? .looseEnv : .projectEnv
    }

    /// 自動削除してよいか。キャッシュである shell_snapshots だけを許す。
    ///
    /// アプリがユーザーの .zshrc や .env を書き換えて環境を壊すのは、
    /// セキュリティツールとして最悪の結果になる。手順を見せるところで止める。
    public static func isTrashable(
        path: String,
        home: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> Bool {
        of(path: path, home: home) == .shellSnapshot
    }

    /// home 配下なら home からの相対要素、そうでなければ全要素。
    private static func relativeComponents(of path: String, under home: String) -> [String] {
        let all = path.split(separator: "/").map(String.init)
        let homeComponents = home.split(separator: "/").map(String.init)
        guard all.count > homeComponents.count, Array(all.prefix(homeComponents.count)) == homeComponents
        else { return all }
        return Array(all.dropFirst(homeComponents.count))
    }

    /// `.claude/` `.codex/` のような、ツールが自分の設定を置く隠しディレクトリの中か。
    /// 先頭要素だけを見るので、`.env` のような隠し「ファイル」は含まれない。
    private static func isInsideHiddenToolDirectory(_ relative: [String]) -> Bool {
        guard relative.count >= 2, let first = relative.first else { return false }
        return first.hasPrefix(".")
    }

    private static func isConfigFile(_ name: String) -> Bool {
        if isEnvFile(name) { return true }
        let ext = (name as NSString).pathExtension.lowercased()
        return configExtensions.contains(ext)
    }

    /// `.env` `.env.local` に加えて `.jijipuchi.env` のような接尾辞型も拾う。
    /// 実測でホーム直下に転がっていた形。
    private static func isEnvFile(_ name: String) -> Bool {
        name.hasPrefix(".env") || name.hasSuffix(".env")
    }

    private static let shellSnapshotDirectory = "shell_snapshots"

    private static let shellConfigNames: Set<String> = [
        ".zshrc", ".zprofile", ".zshenv", ".zlogin",
        ".bashrc", ".bash_profile", ".profile",
    ]

    private static let authFileNames: Set<String> = [
        "auth.json", "token.json", "credentials.json", "credentials",
        "client_secret.json", "client_secrets.json", "google_client_secrets.json",
    ]

    private static let configExtensions: Set<String> = ["json", "yaml", "yml", "toml", "ini", "conf"]
}
