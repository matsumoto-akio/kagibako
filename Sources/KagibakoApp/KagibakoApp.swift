import SwiftUI

@main
struct KagibakoApp: App {
    var body: some Scene {
        WindowGroup("カギバコ") {
            ContentView()
                .frame(minWidth: 640, minHeight: 580)
                // note記事のサムネイルと結果画面の件数がオレンジ。
                // 既定の青のままだと起動画面だけ色がつながらない。
                .tint(AppColor.accent)
        }
        .windowResizability(.contentMinSize)
    }
}
