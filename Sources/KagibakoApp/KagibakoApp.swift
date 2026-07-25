import SwiftUI

@main
struct KagibakoApp: App {
    var body: some Scene {
        WindowGroup("カギバコ") {
            ContentView()
                .frame(minWidth: 640, minHeight: 580)
        }
        .windowResizability(.contentMinSize)
    }
}
