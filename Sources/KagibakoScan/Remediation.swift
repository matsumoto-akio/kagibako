import Foundation

/// 場所ごとの対処手順。文言だけを持ち、ファイルには一切触らない。
///
/// 実行はユーザーの手に残す。アプリが .zshrc や .env を書き換えて環境を壊すのは、
/// セキュリティツールとして最悪の結果になるため、見せるところで止める。
public enum Remediation {
    public struct Guidance: Sendable {
        public let title: String
        public let steps: [String]
        /// コピーして使えるコマンド。実行はしない。
        public let commands: [String]
        /// 実行前に必ず読ませたい注意書き。
        public let caution: String?

        public init(title: String, steps: [String], commands: [String] = [], caution: String? = nil) {
            self.title = title
            self.steps = steps
            self.commands = commands
            self.caution = caution
        }
    }

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
            steps: [
                "Codex が起動のたびに書き出す、シェル環境の写しです。消してもツールは壊れません。",
                "ただし次に Codex を起動すると再生成されます。ここを消すのは対症療法で、"
                    + "根本はシェル設定にキーが書かれていることです。先に .zshrc 側を直してください。",
            ],
            commands: ["rm \"\(file)\""],
            caution: "削除しても Codex の起動で再生成されます。"
                + "根本を直すにはシェル設定の修正が必要です。"
        )
    }

    private static func shellConfigGuidance(file: String) -> Guidance {
        Guidance(
            title: "キーチェーンに移してください",
            steps: [
                "この設定は、開くシェル全部に読み込まれます。ここに平文で書くと、"
                    + "そこから起動したツールが写しを作り、知らないところに増えていきます。",
                "1つ目のコマンドでキーチェーンに登録します。値は対話入力なので、シェルの履歴には残りません。",
                "次に \(file) の `export ANTHROPIC_API_KEY=sk-ant-...` の行を消し、2つ目の行に置き換えます。",
                "置き換えたら、発行元でキーを再発行してください。すでに漏れていた場合、消すだけでは止まりません。",
                "正直に書いておくと、キーチェーンに移してもディスク上の平文が消えるだけです。"
                    + "シェルから起動したプログラムにはキーが渡るので、実行中のプロセスから読まれるのは防げません。",
            ],
            commands: [
                "security add-generic-password -s ANTHROPIC_API_KEY -a \"$USER\" -w",
                "export ANTHROPIC_API_KEY=\"$(security find-generic-password -s ANTHROPIC_API_KEY -w)\"",
            ]
        )
    }

    private static func globalToolConfigGuidance(file: String) -> Guidance {
        Guidance(
            title: "設定から消して、ツール側で入れ直してください",
            steps: [
                "ツール共通の設定ファイルです。プロジェクトを移っても付いて回るので、平文のまま残りやすい場所です。",
                "\(file) をエディタで開き、キーが書かれている項目を削除してください。",
                "そのあとツール側の案内で再ログイン・再認証します。多くのツールはキーチェーンに保存し直します。",
                "設定ファイルに平文で書く方式しか無いツールもあります。その場合は、"
                    + "ファイルの権限を自分だけに絞るところまでが現実的な対処です。",
            ],
            commands: ["chmod 600 \"\(file)\""]
        )
    }

    private static func authFileGuidance(file: String, directory: String, name: String) -> Guidance {
        Guidance(
            title: "発行元で作り直してください",
            steps: [
                "OAuth のクライアントシークレットやトークンです。中身を消すだけでは、"
                    + "すでに漏れていた場合に止まりません。",
                "発行元のコンソール(Google Cloud Console など)で作り直し、古い方を無効化してください。",
                "作り直したら、このファイルが git の管理下に入っていないか確認してください。",
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
                "ホームや Documents の直下にある .env は、どのプロジェクトのものか分からなくなり、"
                    + "忘れられたまま残りがちです。",
                "いま使っているプロジェクトの中へ移すか、不要なら中身を確認したうえで削除してください。",
                "動かす前に、git の管理下に入っていないか確認してください。",
            ],
            commands: ["git -C \"\(directory)\" check-ignore -v \"\(name)\""]
        )
    }

    private static func projectEnvGuidance(directory: String, name: String) -> Guidance {
        Guidance(
            title: "通常はこのままで問題ありません",
            steps: [
                "プロジェクト配下の .env は普通の運用です。.gitignore に入っていれば、まず問題になりません。",
                "1つ目のコマンドで確認できます。無視の指定が表示されれば大丈夫です。"
                    + "何も表示されない場合は .gitignore に入っていないので、追記してください。",
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
