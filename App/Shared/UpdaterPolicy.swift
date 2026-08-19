import Foundation

struct UpdaterPolicy: Equatable {
    let startsUpdater: Bool
    let unavailableExplanation: String?

    static let unavailableMessage = "Updates require a signed build."

    static func resolve(bundleSignedForUpdates: Bool) -> UpdaterPolicy {
        if bundleSignedForUpdates {
            return UpdaterPolicy(startsUpdater: true, unavailableExplanation: nil)
        }
        return UpdaterPolicy(startsUpdater: false, unavailableExplanation: unavailableMessage)
    }
}
