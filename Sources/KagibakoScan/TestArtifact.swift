import Foundation

/// 「テスト用・サンプルの可能性が高い検出」を本体の件数から切り離すための判定。
///
/// 誤検出が多いセキュリティツールは信用されなくなる。伏せ字処理のテスト、
/// フィクスチャ、ドキュメントの見本に置かれたダミーキーを主役の数字に混ぜないため、
/// パスと値の両面から分離する。
///
/// 除外(スキャンしない)ではなく分離(数えるが別枠)にしているのは、
/// テストディレクトリに本物のキーが置かれている事故が実在するため。
/// 見なかったことにはせず、「参考」として必ず出す。
public enum TestArtifact {
    public static func isLikelyTest(path: String, value: String) -> Bool {
        isTestPath(path) || isTestValue(value)
    }

    /// パス要素のいずれかがテスト・見本・自プロジェクトを示すか。
    ///
    /// 部分一致で見ると `latest` や `protest` を巻き込むため、必ず要素単位で判定する。
    static func isTestPath(_ path: String) -> Bool {
        path.split(separator: "/").contains { isTestComponent($0.lowercased()) }
    }

    private static func isTestComponent(_ component: String) -> Bool {
        if testDirectoryNames.contains(component) { return true }
        if testComponentPrefixes.contains(where: { component.hasPrefix($0) }) { return true }
        if component.contains("mock") { return true }
        let stem = (component as NSString).deletingPathExtension
        return testStemSuffixes.contains { stem.hasSuffix($0) }
    }

    /// 値そのものがテスト用と分かる書き出しか。Stripe の `sk_test_` など。
    static func isTestValue(_ value: String) -> Bool {
        let lowered = value.lowercased()
        if testValueMarkers.contains(where: { lowered.contains($0) }) { return true }
        return testValuePrefixes.contains { lowered.hasPrefix($0) }
    }

    private static let testDirectoryNames: Set<String> = [
        "test", "tests", "testing", "spec", "specs", "e2e",
        "fixture", "fixtures", "testdata", "test-data", "test_data",
        "__tests__", "__mocks__", "__fixtures__", "snapshots",
        "example", "examples", "sample", "samples", "demo", "demos",
        "doc", "docs", "documentation",
        // カギバコ自身のリポジトリ。自分の検出パターンとテストフィクスチャを
        // 自分で拾って件数を水増ししないため。
        "kagibako",
    ]

    private static let testComponentPrefixes = ["test_", "test-", "spec_", "spec-"]

    private static let testStemSuffixes = ["_test", "-test", ".test", "_spec", "-spec", ".spec"]

    private static let testValueMarkers = [
        "sk-test", "sk_test", "pk_test", "rk_test", "sk-ant-test", "sk-proj-test",
    ]

    private static let testValuePrefixes = ["test_", "test-", "fake", "notreal"]
}
