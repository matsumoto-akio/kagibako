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

    /// 直す順番。先に古いキーを止めると、動いているものが止まる。
    public static let reissueOrder = [
        "新しいキーを発行する",
        "使っている場所を全部、新しいキーに差し替える",
        "最後に、古いキーを失効させる",
    ]

    /// 順番を間違えたときに何が起きるか。番号だけ出しても伝わらない。
    public static let reissueOrderCaution = "先に古いキーを止めると、動いているものが止まります。"

    /// 「消すだけで終わり」は、公式ログインを持つツールにしか当てはまらない。
    /// どのツールのファイルか分からないまま消させると、そのツールが動かなくなる。
    ///
    /// 分からない人に「試しに消して動かしてみる」をさせない。
    /// 何を動かせばいいか分からないから分からないのであって、確かめようがない。
    /// 触らせずに、確認できる1点(GitHub)だけを残す。
    private static let identifyToolFirst =
        "まず、このファイルがどのツールのものか確認してください。"
        + "Claude Code や Codex のように公式のログインがあるツールなら、"
        + "キーを消してログインし直すだけで済みます。"
        + "そうでないツールは、キーを消すと動かなくなります。"

    /// 分からない場合の受け皿。ここで止まれる形にしておかないと、
    /// 分からないまま次の手順(削除)に進んでしまう。
    private static let unknownToolIsSafeToLeave =
        "どのツールのものか分からない場合は、そのファイルは触らないでください。"
        + "消して動かなくなるより、そのままにしておく方が安全です。"
        + "確認するのは1点だけです。そのフォルダを GitHub に上げていないか。"
        + "上げていなければ、いまのままで大きな問題はありません。"

    /// 手順どおりにやっても戻せなくなる人が出る。編集の前に必ず退避させる。
    private static let backupFirst =
        "編集する前に、そのファイルをコピーして別の場所に置いておいてください。"
        + "うまくいかなかったときに戻せます。"
        + "そのコピーにもキーが書かれています。うまくいったら、コピーの方も消してください。"

    public static func guidance(for kind: LocationKind, path: String? = nil) -> Guidance {
        // 文章は `~` 表記、コマンドは貼り付けて動く形。同じパスでも別物になる。
        let file = path.map { PathDisplay.abbreviate($0) } ?? "<このファイル>"
        let fileArg = path.map { PathDisplay.shellArgument($0) } ?? "\"<このファイル>\""
        // 引用符の外に `.bak` を足すと `~/".zshrc".bak` になる。動きはするが読みにくいので、
        // 退避先は元のパスに `.bak` を付けてから組み立てる。
        let backupArg = path.map { PathDisplay.shellArgument($0 + ".bak") } ?? "\"<このファイル>.bak\""
        let directoryPath = path.map { ($0 as NSString).deletingLastPathComponent }
        let directoryArg = directoryPath.map { PathDisplay.shellArgument($0) }
            ?? "\"<プロジェクトのフォルダ>\""
        let name = path.map { ($0 as NSString).lastPathComponent } ?? ".env"

        switch kind {
        case .shellSnapshot:
            return snapshotGuidance(file: file, fileArg: fileArg)
        case .shellConfig:
            return shellConfigGuidance(file: file, fileArg: fileArg, backupArg: backupArg)
        case .globalToolConfig:
            return globalToolConfigGuidance(file: file, fileArg: fileArg, backupArg: backupArg)
        case .authFile:
            return authFileGuidance(file: file, fileArg: fileArg, directoryArg: directoryArg, name: name)
        case .looseEnv:
            return looseEnvGuidance(directoryArg: directoryArg, name: name)
        case .projectEnv:
            return projectEnvGuidance(directoryArg: directoryArg, name: name)
        case .other:
            return otherGuidance(file: file, fileArg: fileArg, directoryArg: directoryArg, name: name)
        }
    }

    private static func snapshotGuidance(file: String, fileArg: String) -> Guidance {
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
            commands: ["rm \(fileArg)"],
            caution: "削除しても Codex の起動で再生成されます。"
                + "根本を直すにはターミナルの設定ファイルの修正が必要です。"
        )
    }

    private static func shellConfigGuidance(file: String, fileArg: String, backupArg: String) -> Guidance {
        Guidance(
            title: "書いた1行を消すのが一番かんたんです",
            reason: "~/.zshrc(ターミナルの設定ファイル。ターミナルを開くたびに読み込まれます)に書いた値は、"
                + "ターミナルを開くたびに読み込まれ、Codex が自動で作るコピーにも毎回書き写されます。"
                + "キーが知らないうちに増えていく元が、ここです。",
            steps: [
                identifyToolFirst,
                unknownToolIsSafeToLeave,
                backupFirst,
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
                "最後に、キーを配っているサイトでキーを再発行(新しいキーを作り直すこと)します。"
                    + "順番が大事です。1. 新しいキーを発行する → 2. 使っている場所を全部、新しいキーに差し替える"
                    + " → 3. 最後に、古いキーを失効(使えなくすること)させる、の順です。"
                    + "\(reissueOrderCaution)",
            ],
            commands: [
                "cp \(fileArg) \(backupArg)",
                "security add-generic-password -a \"$USER\" -s ANTHROPIC_API_KEY -w",
                "security find-generic-password -a \"$USER\" -s ANTHROPIC_API_KEY -w",
            ],
            caution: "取り出すコマンドを ~/.zshrc に export として書いてしまうと、"
                + "結局 Codex が自動で作るコピー(スナップショット)に載ります。"
                + "使うときだけ実行する形にしてください。"
        )
    }

    private static func globalToolConfigGuidance(file: String, fileArg: String, backupArg: String) -> Guidance {
        Guidance(
            title: "設定から消して、ツール側で入れ直してください",
            reason: "ツール全体の設定ファイルです。どのフォルダで作業しても読み込まれるので、"
                + "書いたまま忘れられやすい場所です。",
            steps: [
                identifyToolFirst,
                unknownToolIsSafeToLeave,
                backupFirst,
                "\(file) をテキストエディタで開き、キーが書かれている項目を削除して保存します。",
                "そのあと、ツールをもう一度開いてログインし直してください。"
                    + "公式のログインがあるツールは、ログインし直すと安全な場所に保存されます。",
                "設定ファイルに直接書く方式しかないツールもあります。"
                    + "その場合は、そのファイルを自分だけが読める設定にするところまでが現実的な対処です"
                    + "(下の「詳しい人向け」のコマンド)。",
            ],
            commands: [
                "cp \(fileArg) \(backupArg)",
                "chmod 600 \(fileArg)",
            ]
        )
    }

    private static func authFileGuidance(file: String, fileArg: String, directoryArg: String, name: String) -> Guidance {
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
                "git -C \(directoryArg) check-ignore -v \"\(name)\"",
                "chmod 600 \(fileArg)",
            ]
        )
    }

    private static func looseEnvGuidance(directoryArg: String, name: String) -> Guidance {
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
            commands: ["git -C \(directoryArg) check-ignore -v \"\(name)\""]
        )
    }

    private static func projectEnvGuidance(directoryArg: String, name: String) -> Guidance {
        Guidance(
            title: "通常はこのままで問題ありません",
            steps: [
                "この場所は「\(Risk.likelyFine.label)」です。"
                    + "プロジェクトのフォルダの中の .env にキーを書くのは、ふつうのやり方で、"
                    + "移したり消したりする必要はありません。"
                    + "確認することは1つだけ、GitHub に上がっていないかどうかです。",
                "そのフォルダの .gitignore(GitHubに上げないファイルを指定する設定)を"
                    + "テキストエディタで開いて、\(name) と書かれた行があるか見てください。"
                    + "なければ、その1行を追加します。",
                "過去に一度でも GitHub に上げていた場合は、あとから消しても取り出せてしまいます。"
                    + "心当たりがあれば、キーを作り直してください。",
            ],
            commands: [
                "git -C \(directoryArg) check-ignore -v \"\(name)\"",
                "git -C \(directoryArg) log --oneline -- \"\(name)\"",
            ]
        )
    }

    private static func otherGuidance(file: String, fileArg: String, directoryArg: String, name: String) -> Guidance {
        Guidance(
            title: "中身を見て判断してください",
            steps: [
                "場所からは判断できませんでした。\(file) を開いて、"
                    + "実際に使っているキーが書かれているのか確かめてください。",
                "説明用の見本の値が書かれているだけのこともあります。"
                    + "その場合は、何もしなくて大丈夫です。",
                "本物のキーだった場合は、そのファイルが GitHub に上がらない設定になっているかを確認し、"
                    + "自分だけが読める設定にしてください(下の「詳しい人向け」のコマンド)。",
            ],
            commands: [
                "git -C \(directoryArg) check-ignore -v \"\(name)\"",
                "chmod 600 \(fileArg)",
            ]
        )
    }
}
