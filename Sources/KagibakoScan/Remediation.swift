import Foundation

/// 場所ごとの対処手順。文言だけを持ち、ファイルには一切触らない。
///
/// 実行はユーザーの手に残す。アプリが .zshrc や .env を書き換えて環境を壊すのは、
/// セキュリティツールとして最悪の結果になるため、見せるところで止める。
///
/// 想定読者は「流行っているから AI を入れてみた」初心者。
/// 手順の難易度は下げるが、用語のレベルは下げない。
/// 用語を言い換えて消すと、あとで自分で調べられなくなるため、
/// 用語は残したまま、初出の1回だけ短い注釈を添える。
public enum Remediation {
    public struct Guidance: Sendable {
        public let title: String
        /// なぜ危ないか。手順だけ出すと後回しにされるので、先に理由を置く。
        public let reason: String?
        public let steps: [String]
        /// 詳しい人向け。コマンドが読めなくても、手順だけで進める形にしてある。実行はしない。
        public let commands: [String]
        /// 実行前に必ず読ませたい注意書き。
        public let caution: String?

        public init(
            title: String,
            reason: String? = nil,
            steps: [String],
            commands: [String] = [],
            caution: String? = nil
        ) {
            self.title = title
            self.reason = reason
            self.steps = steps
            self.commands = commands
            self.caution = caution
        }
    }

    /// 「平文で保存されます」では何が困るのか伝わらない。請求が来るところまで書く。
    public static let whyItMatters =
        "APIキー(AIを使うための、あなた専用の合鍵)は、あなたのクレジットカードの番号みたいなものです。"
        + "これを他の人に見られると、勝手にAIを使われて、その料金があなたに請求されます。"
        + "実際に何十万円も請求された人がいます。"

    /// 一番多い漏れ方は、難しい攻撃ではない。ここを最後に必ず言う。
    public static let neverShowNote =
        "キーは、誰にも見せないでください。"
        + "配信やスクリーンショットに写り込むこと、GitHubに上げてしまうことが、一番多い漏れ方です。"

    /// できることの範囲を最後に必ず言う。全部を一度に直させようとすると、手が止まる。
    public static let closingNote =
        "このアプリができるのは、場所を教えるところまでです。"
        + "直すのはあなたの手で、1つずつ確認しながら進めてください。"
        + "全部を一度に直す必要はありません。まず「いますぐ対処」の分だけで、リスクの大半は減ります。"

    /// 多くの人は、そもそもキーを書く必要がない。金庫に移す話より先にこれを出す。
    private static let tryLoginFirst =
        "まず確認してください。Claude Code や Codex は、公式のログインだけで使えます。"
        + "その場合、書いてあるキーは消すだけで終わりです。"
        + "消したあとターミナルを開き直して、いつも通り使えれば大丈夫です。"
        + "これが一番かんたんで、一番安全です。"

    public static func guidance(for kind: LocationKind, path: String? = nil) -> Guidance {
        let file = path ?? "<このファイル>"
        let directory = path.map { ($0 as NSString).deletingLastPathComponent } ?? "<プロジェクトのフォルダ>"
        let name = path.map { ($0 as NSString).lastPathComponent } ?? ".env"

        switch kind {
        case .shellSnapshot:
            return snapshotGuidance(file: file)
        case .shellConfig:
            return shellConfigGuidance(file: file)
        case .globalToolConfig:
            return globalToolConfigGuidance(file: file)
        case .authFile:
            return authFileGuidance(file: file, directory: directory, name: name)
        case .looseEnv:
            return looseEnvGuidance(directory: directory, name: name)
        case .projectEnv:
            return projectEnvGuidance(directory: directory, name: name)
        case .other:
            return otherGuidance(file: file)
        }
    }

    private static func snapshotGuidance(file: String) -> Guidance {
        Guidance(
            title: "消してよいコピーです",
            reason: "Codex が起動するたびに自動で作るコピーです。"
                + "そのときの環境変数(パソコン全体で使える設定のこと)がまるごと書き写されるので、"
                + "キーも一緒に保存されます。消しても、次に Codex を開くとまた作られます。",
            steps: [
                "下の「このファイルをゴミ箱に入れる」を押してください。"
                    + "自動で作り直されるコピーなので、消してもパソコンは壊れません。",
                "ただし、次に Codex を開くとまた作られます(再生成されます)。"
                    + "元をたどるとシェル設定ファイル"
                    + "(~/.zshrc。ターミナルの設定ファイルで、ターミナルを開くたびに読み込まれます)"
                    + "にキーが書いてあるせいなので、そちらもセットで直してください。",
            ],
            commands: ["rm \"\(file)\""],
            caution: "削除しても Codex の起動で再生成されます。"
                + "根本を直すにはターミナルの設定ファイルの修正が必要です。"
        )
    }

    private static func shellConfigGuidance(file: String) -> Guidance {
        Guidance(
            title: "書いた1行を消すのが一番かんたんです",
            reason: "~/.zshrc(ターミナルの設定ファイル。ターミナルを開くたびに読み込まれます)に書いた値は、"
                + "ターミナルを開くたびに読み込まれ、Codex が自動で作るコピーにも毎回書き写されます。"
                + "キーが知らないうちに増えていく元が、ここです。",
            steps: [
                tryLoginFirst,
                "消すのは、\(file) の中の「キーを書いた1行」です。"
                    + "`export ANTHROPIC_API_KEY=sk-ant-...` のように書かれている行を、まるごと削除します。",
                "消したら困った(ツールが動かなくなった)場合だけ、次に進んでください。"
                    + "キーチェーン(Macに最初から入っている、パスワードをしまう金庫)にキーを預けます。",
                "「キーチェーンアクセス」というアプリを開きます"
                    + "(Launchpad で「キーチェーン」と検索すると出ます)。"
                    + "メニューの ファイル → 新規パスワードアイテム を選び、"
                    + "名前に ANTHROPIC_API_KEY、パスワード欄にキーを貼り付けて保存します。",
                "取り出すのは、使うときだけにしてください。取り出し方は下の「詳しい人向け」にあります。",
                "正直に書いておくと、金庫に預けても、ファイルに置きっぱなしにするのをやめられるだけです。"
                    + "動いているプログラム(実行中のプロセス)にはキーが渡るので、"
                    + "そこから読まれるのは防げません。",
                "最後に、キーを配っているサイトでキーを再発行(新しいキーを作り直すこと)し、"
                    + "古いキーを失効(使えなくすること)させてください。"
                    + "順番が大事です。先に古いキーを止めると、いま動いているものが止まります。",
            ],
            commands: [
                "security add-generic-password -a \"$USER\" -s ANTHROPIC_API_KEY -w",
                "security find-generic-password -a \"$USER\" -s ANTHROPIC_API_KEY -w",
            ],
            caution: "取り出すコマンドを ~/.zshrc に export として書いてしまうと、"
                + "結局 Codex が自動で作るコピー(スナップショット)に載ります。"
                + "使うときだけ実行する形にしてください。"
        )
    }

    private static func globalToolConfigGuidance(file: String) -> Guidance {
        Guidance(
            title: "設定から消して、ツール側で入れ直してください",
            reason: "ツール全体の設定ファイルです。どのフォルダで作業しても読み込まれるので、"
                + "書いたまま忘れられやすい場所です。",
            steps: [
                tryLoginFirst,
                "\(file) をテキストエディタで開き、キーが書かれている項目を削除して保存します。",
                "そのあと、ツールをもう一度開いてログインし直してください。"
                    + "多くのツールは、キーチェーン(Macに最初から入っている、パスワードをしまう金庫)に自動でしまい直します。",
                "設定ファイルに直接書く方式しかないツールもあります。"
                    + "その場合は、そのファイルを自分だけが読める設定にするところまでが現実的な対処です"
                    + "(下の「詳しい人向け」のコマンド)。",
            ],
            commands: ["chmod 600 \"\(file)\""]
        )
    }

    private static func authFileGuidance(file: String, directory: String, name: String) -> Guidance {
        Guidance(
            title: "使っているかどうかで分かれます",
            reason: "アプリがあなたの代わりにログインするための鍵が入ったファイルです。"
                + "これを持っている人は、あなたとして操作できてしまいます。",
            steps: [
                "心当たりがない、もう使っていないサービスのものなら、そのまま削除してください。",
                "使っているなら、そのサービスのサイト(Google Cloud Console など)で鍵を作り直し、"
                    + "新しいものに差し替えてから、古いものを使えなくしてください。"
                    + "ファイルを消すだけでは、すでに見られていた場合に止まりません。",
                "残す場合は、そのファイルが GitHub に上がっていないか確認してください。"
                    + ".gitignore(GitHubに上げないファイルを指定する設定)に入っていれば大丈夫です。",
            ],
            commands: [
                "git -C \"\(directory)\" check-ignore -v \"\(name)\"",
                "chmod 600 \"\(file)\"",
            ]
        )
    }

    private static func looseEnvGuidance(directory: String, name: String) -> Guidance {
        Guidance(
            title: "置き場所を決め直してください",
            reason: "ホームや書類フォルダの直下にある .env は、どのプロジェクトのものか分からなくなり、"
                + "そのまま忘れられがちです。",
            steps: [
                "このファイルが入っているフォルダが、GitHub に上がっていないか確認してください。"
                    + "上がっている場合は、.gitignore(GitHubに上げないファイルを指定する設定)に"
                    + " \(name) を追加してください。",
                "いま使っているプロジェクトのフォルダの中に移すのが安全です。"
                    + "心当たりがなければ、中身を見たうえで削除してください。",
            ],
            commands: ["git -C \"\(directory)\" check-ignore -v \"\(name)\""]
        )
    }

    private static func projectEnvGuidance(directory: String, name: String) -> Guidance {
        Guidance(
            title: "通常はこのままで問題ありません",
            steps: [
                "プロジェクトのフォルダの中の .env にキーを書くのは、ふつうのやり方です。"
                    + "確認することは1つだけ、GitHub に上がっていないかどうかです。",
                "そのフォルダの .gitignore(GitHubに上げないファイルを指定する設定)を"
                    + "テキストエディタで開いて、\(name) と書かれた行があるか見てください。"
                    + "なければ、その1行を追加します。",
                "過去に一度でも GitHub に上げていた場合は、あとから消しても取り出せてしまいます。"
                    + "心当たりがあれば、キーを作り直してください。",
            ],
            commands: [
                "git -C \"\(directory)\" check-ignore -v \"\(name)\"",
                "git -C \"\(directory)\" log --oneline -- \"\(name)\"",
            ]
        )
    }

    private static func otherGuidance(file: String) -> Guidance {
        Guidance(
            title: "中身を見て判断してください",
            steps: [
                "場所からは判断できませんでした。\(file) を開いて、"
                    + "実際に使っているキーが書かれているのか確かめてください。",
                "説明用の見本の値が書かれているだけのこともあります。"
                    + "その場合は、何もしなくて大丈夫です。",
            ]
        )
    }
}
