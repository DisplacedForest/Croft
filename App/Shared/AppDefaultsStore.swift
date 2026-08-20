import Foundation

enum AppDefaultsStore {
    static let suiteVariable = "CROFT_DEFAULTS_SUITE"

    static func resolve(choice: DatabaseLocation.Choice, suite: String?) -> UserDefaults {
        guard choice != .release, let suite, !suite.isEmpty,
            let defaults = UserDefaults(suiteName: suite)
        else {
            return .standard
        }
        return defaults
    }

    static var current: UserDefaults {
        resolve(
            choice: DatabaseLocation.current,
            suite: ProcessInfo.processInfo.environment[suiteVariable]
        )
    }
}
