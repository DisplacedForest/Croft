import SwiftUI

@main
struct CroftApp: App {
    private let stores = AppStores.open()

    var body: some Scene {
        WindowGroup {
            CroftShell()
                .environment(\.appStores, stores)
        }
        .defaultSize(width: 1040, height: 700)

        Settings {
            PropertySettingsView()
                .environment(\.appStores, stores)
        }
    }
}
