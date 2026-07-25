import Foundation

/// 場所ごとの対処手順。文言だけを持ち、ファイルには一切触らない。
///
/// 実行はユーザーの手に残す。アプリが .zshrc や .env を書き換えて環境を壊すのは、
/// セキュリティツールとして最悪の結果になるため、見せるところで止める。
///
/// 27件あっても、対処の型は場所の種類ぶんしかない。
/// 消す・書き換える・そのままでよい、の3つを場所ごとに割り当てている。
public enum Remediation {
    public struct Guidance: Sendable {
        public let title: String
        /// なぜ危ないか。手順だけ出すと後回しにされるので、先に理由を置く。
        public let reason: String?
        public let steps: [String]
        /// コピーして使えるコマンド。実行はしない。
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

    /// できることの範囲を最後に必ず言う。全部を一度に直させようとすると、手が止まる。
    public static let closingNote =
        "このアプリができるのは、場所を教えるところまでです。"
        + "直すのはあなたの手で、1つずつ確認しながら進めてください。"
        + "全部を一度に直す必要はありません。まず「いますぐ対処」の分だけで、リスクの大半は減ります。"

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
            title: "消してよいキャッシュです",
            reason: "Codex が起動のたびに作るファイルです。そのときの環境変数がそのままコピーされるので、"
                + "キーも一緒に保存されます。消しても次の起動でまた作られます。",
            steps: [
                "下の「このファイルをゴミ箱に入れる」を押してください。キャッシュなので、消しても環境は壊れません。",
                "ただし再生成されるので、シェル設定(.zshrc など)の対処とセットでやってください。"
                    + "増殖の元はそちらです。",
            ],
            commands: ["rm \"\(file)\""],
            caution: "削除しても Codex の起動で再生成されます。"
                + "根本を直すにはシェル設定の修正が必要です。"
        )
    }

    private static func shellConfigGuidance(file: String) -> Guidance {
        Guidance(
            title: "キーチェーンに移してください",
            reason: "ここに書いた値が、開くシェル全部に読み込まれ、起動のたびにスナップショットへコピーされます。"
                + "増殖の元はここです。",
            steps: [
                "1つ目のコマンドでキーチェーンに保存します。値は対話入力なので、シェルの履歴には残りません。",
                "\(file) から `export ANTHROPIC_API_KEY=sk-ant-...` の行を消します。",
                "必要なときだけ2つ目のコマンドで取り出します。",
                "キーチェーンに移してもディスク上の平文が消えるだけで、"
                    + "実行中のプロセスから読まれるのは防げません。そこは正直に書いておきます。",
                "最後に、発行元でキーを再発行して古いキーを失効させてください。"
                    + "順番が大事です。先に失効させると、動いているものが止まります。",
            ],
            commands: [
                "security add-generic-password -a \"$USER\" -s ANTHROPIC_API_KEY -w",
                "security find-generic-password -a \"$USER\" -s ANTHROPIC_API_KEY -w",
            ],
            caution: "この結果を .zshrc で毎回 export すると、結局スナップショットに載ります。"
                + "使うときだけ実行する形にしてください。"
        )
    }

    private static func globalToolConfigGuidance(file: String) -> Guidance {
        Guidance(
            title: "設定から消して、ツール側で入れ直してください",
            reason: "ツール共通の設定ファイルです。プロジェクトを移っても付いて回るので、"
                + "平文のまま忘れられやすい場所です。",
            steps: [
                "\(file) をエディタで開き、キーが書かれている項目を削除してください。",
                "そのあとツール側でログインし直してください。多くのツールはキーチェーンに保存し直します。",
                "設定ファイルに平文で書く方式しか無いツールもあります。その場合は、"
                    + "ファイルの権限を自分だけに絞るところまでが現実的な対処です。",
            ],
            commands: ["chmod 600 \"\(file)\""]
        )
    }

    private static func authFileGuidance(file: String, directory: String, name: String) -> Guidance {
        Guidance(
            title: "使っているかどうかで分かれます",
            steps: [
                "使っていないサービスのものなら、そのまま消してください。",
                "使っているなら、発行元(Google Cloud Console など)でトークンを作り直せるか確認し、"
                    + "作り直したうえで古い方を無効化してください。中身を消すだけでは、"
                    + "すでに漏れていた場合に止まりません。",
                "残す場合は、git の管理下に入っていないかを確認してください。",
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
            steps: [
                "そのフォルダが GitHub に上がっていないか確認してください。"
                    + "ホームや Documents の直下は、どのプロジェクトのものか分からなくなり、忘れられがちです。",
                "使っているプロジェクトの中に移すのが安全です。不要なら、中身を確認したうえで削除してください。",
            ],
            commands: ["git -C \"\(directory)\" check-ignore -v \"\(name)\""]
        )
    }

    private static func projectEnvGuidance(directory: String, name: String) -> Guidance {
        Guidance(
            title: "通常はこのままで問題ありません",
            steps: [
                ".env にキーを書くのは通常の運用です。確認するのは1点だけ、.gitignore に入っているかどうか。",
                "1つ目のコマンドで、何か表示されれば git の管理から外れています。"
                    + "何も出なければ、.gitignore に \(name) を追加してください。",
                "2つ目のコマンドで、過去にコミットしていないかも確認できます。"
                    + "履歴に残っていると、いま消しても GitHub からは取り出せます。その場合はキーの再発行が要ります。",
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
                "場所からは判断できませんでした。\(file) を開いて、実際に使っているキーかどうか確かめてください。",
                "伏せ字処理そのものを書いたファイルなど、見本の値が書かれているだけのこともあります。",
            ]
        )
    }
}
