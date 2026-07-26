import Foundation

/// パスの見せ方。ホームディレクトリは `~` に畳む。
///
/// 画面に出るパスには使っている人の名前が入る(`/Users/akio/...`)。
/// このアプリの結果はスクリーンショットで人に見せる前提なので、
/// 見出しだけでなく手順の文章とコマンド欄も `~` に統一する。
public enum PathDisplay {
    /// 表示用。`/Users/akio/.zshrc` → `~/.zshrc`
    public static func abbreviate(
        _ path: String,
        home: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> String {
        guard let relative = relativeToHome(path, home: home) else { return path }
        return relative.isEmpty ? "~" : "~/\(relative)"
    }

    /// コマンド用。`"~/.zshrc"` と引用符で囲むと `~` が展開されず、
    /// 貼り付けても動かないコマンドになる。`~/` だけ引用符の外に出す。
    ///
    /// `/Users/akio/My Project/.env` → `~/"My Project/.env"`
    /// (空白を含むパスがあるので、引用符自体は外せない)
    public static func shellArgument(
        _ path: String,
        home: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> String {
        guard let relative = relativeToHome(path, home: home) else { return "\"\(path)\"" }
        return relative.isEmpty ? "~" : "~/\"\(relative)\""
    }

    /// ホーム配下ならホームからの相対パス、そうでなければ nil。
    /// `home + "/"` で見るのは、`/Users/akio2` が `/Users/akio` に
    /// 誤って一致するのを防ぐため。
    private static func relativeToHome(_ path: String, home: String) -> String? {
        if path == home { return "" }
        let prefix = home.hasSuffix("/") ? home : home + "/"
        guard path.hasPrefix(prefix) else { return nil }
        return String(path.dropFirst(prefix.count))
    }
}
