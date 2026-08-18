import Foundation

public struct UnitSystemPreference {
    private let store: UserDefaults
    private let locale: Locale
    private static let key = "measurement.unitSystem"

    public init(store: UserDefaults = .standard, locale: Locale = .current) {
        self.store = store
        self.locale = locale
    }

    public var system: UnitSystem {
        get {
            store.string(forKey: Self.key).flatMap(UnitSystem.init(rawValue:))
                ?? Self.localeDefault(for: locale)
        }
        nonmutating set {
            store.set(newValue.rawValue, forKey: Self.key)
        }
    }

    static func localeDefault(for locale: Locale) -> UnitSystem {
        locale.measurementSystem == .metric ? .metric : .imperial
    }
}
