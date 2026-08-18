import Domain
import Foundation

public struct PropertySetupDefaults {
    private let store: UserDefaults
    private static let promptedKey = "property.setupPrompted"

    public init(store: UserDefaults = .standard) {
        self.store = store
    }

    public var hasBeenPrompted: Bool {
        get { store.bool(forKey: PropertySetupDefaults.promptedKey) }
        nonmutating set { store.set(newValue, forKey: PropertySetupDefaults.promptedKey) }
    }
}

public enum PropertySetupGate {
    public static func shouldOffer(
        property: Property?,
        defaults: PropertySetupDefaults
    ) -> Bool {
        guard !defaults.hasBeenPrompted else {
            return false
        }
        guard let property else {
            return true
        }
        return !property.hasFrostDates
    }
}
