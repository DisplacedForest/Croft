import Sparkle
import SwiftUI

@main
struct CroftApp: App {
    private let stores = AppStores.open()
    private let updaterPolicy: UpdaterPolicy
    private let updaterController: SPUStandardUpdaterController

    init() {
        let policy = UpdaterPolicy.resolve(
            bundleSignedForUpdates: BundleSignature.isDeveloperIDSigned())
        updaterPolicy = policy
        updaterController = SPUStandardUpdaterController(
            startingUpdater: policy.startsUpdater, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var body: some Scene {
        WindowGroup {
            CroftShell()
                .environment(\.appStores, stores)
        }
        .defaultSize(width: 1040, height: 700)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(
                    updater: updaterController.updater,
                    unavailableExplanation: updaterPolicy.unavailableExplanation)
            }
        }

        Settings {
            PropertySettingsView()
                .environment(\.appStores, stores)
        }
    }
}
