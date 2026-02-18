import SwiftUI

@main
struct QuickPizzaIosApp: App {
    init() {
        Bootstrap.initialize()
    }

    var body: some Scene {
        WindowGroup {
            MainShell()
        }
    }
}
