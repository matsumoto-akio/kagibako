import SwiftUI

@main
struct KagibakoApp: App {
    var body: some Scene {
        WindowGroup("カギバコ") {
            ContentView()
                .frame(minWidth: 560, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
    }
}
