import Persistence
import PlantCatalog
import SwiftUI

struct AppStores: Sendable {
    let database: AppDatabase

    var plantPages: PlantPageLoader {
        PlantPageLoader(database)
    }

    static func open() -> AppStores? {
        guard let url = try? AppDatabase.defaultURL(),
            let database = try? AppDatabase.open(at: url)
        else {
            return nil
        }
        return AppStores(database: database)
    }
}

private struct AppStoresKey: EnvironmentKey {
    static let defaultValue: AppStores? = nil
}

extension EnvironmentValues {
    var appStores: AppStores? {
        get { self[AppStoresKey.self] }
        set { self[AppStoresKey.self] = newValue }
    }
}
