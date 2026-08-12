import GRDB
import Graph
import Persistence

struct FixturePlant: Codable, Equatable, FetchableRecord, PersistableRecord, GraphEntity {
    static let databaseTableName = "fixture_plant"
    static var entityType: EntityType { .plant }

    var id: String
    var name: String

    var entityID: String { id }
}

func makeDatabase() throws -> AppDatabase {
    try AppDatabase.inMemory()
}

func attribution(for type: RelationshipType) -> Provenance {
    guard type.requiresProvenance else {
        return Provenance()
    }
    return Provenance(source: "fixture", sourceType: .imported)
}
