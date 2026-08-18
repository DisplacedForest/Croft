import Sparkle
import SwiftUI

@main
struct CroftApp: App {
    private let stores = AppStores.open()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var body: some Scene {
        WindowGroup {
            CroftShell()
                .environment(\.appStores, stores)
        }
        .defaultSize(width: 1040, height: 700)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }

        Settings {
            PropertySettingsView()
                .environment(\.appStores, stores)
        }
    }
}
