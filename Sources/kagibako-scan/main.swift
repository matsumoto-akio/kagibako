import Foundation
import KagibakoScan

let arguments = CommandLine.arguments
let rootPath = arguments.count > 1
    ? (arguments[1] as NSString).expandingTildeInPath
    : FileManager.default.homeDirectoryForCurrentUser.path

do {
    let detector = try Detector()
    let scanner = Scanner(detector: detector)

    FileHandle.standardError.write("走査中: \(rootPath)\n".data(using: .utf8) ?? Data())
    let summary = scanner.scan(rootPath: rootPath)

    print(Report.render(summary, rootPath: rootPath))
} catch {
    FileHandle.standardError.write("エラー: \(error)\n".data(using: .utf8) ?? Data())
    exit(1)
}
