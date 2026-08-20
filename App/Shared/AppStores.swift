import Persistence
import PlantCatalog
import SwiftUI

struct AppStores: Sendable {
    let database: AppDatabase
    let knowledgeDatabase: AppDatabase?

    var plantPages: PlantPageLoader {
        if let knowledgeDatabase {
            PlantPageLoader(knowledge: knowledgeDatabase, personal: database)
        } else {
            PlantPageLoader(database)
        }
    }

    static func open() -> AppStores? {
        guard let url = try? DatabaseLocation.url(),
            let database = try? AppDatabase.open(at: url)
        else {
            return nil
        }
        return AppStores(
            database: database,
            knowledgeDatabase: KnowledgeStore.openBundled()?.database
        )
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
