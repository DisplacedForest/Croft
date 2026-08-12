import Domain
import GRDB
import Graph
import Testing

@testable import Persistence

let diseaseIdentifier = "v007-diseases"

struct DiseaseFixture {
    let database: AppDatabase
    let repository: DiseaseRepository
    let pathogens: PathogenRepository
    let environmentalConditions: EnvironmentalConditionRepository

    init() throws {
        database = try AppDatabase.inMemory()
        repository = DiseaseRepository(database)
        pathogens = PathogenRepository(database)
        environmentalConditions = EnvironmentalConditionRepository(database)
    }

    func registerPlant(_ id: String) throws {
        try database.writer.write { db in
            try GraphStore.register(EntityRef(id: id, type: .plant), in: db)
        }
    }

    func relate(
        _ source: EntityRef,
        _ type: RelationshipType,
        _ target: EntityRef,
        provenance: Provenance = Provenance()
    ) throws {
        try database.writer.write { db in
            try GraphStore.relate(
                from: source, type, to: target, provenance: provenance, in: db)
        }
    }

    func edgeCount(referencing id: String) throws -> Int? {
        try database.writer.read { db in
            try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM relationship
                    WHERE from_entity_id = ? OR to_entity_id = ?
                    """,
                arguments: [id, id]
            )
        }
    }
}

let earlyBlight = Disease(
    name: "Early Blight",
    pathogen: "Alternaria solani",
    pathogenType: .fungal,
    symptoms: "Dark concentric spots on lower leaves",
    affectedPlantParts: [.leaf, .stem, .fruit],
    transmission: "Wind and splashing water",
    prevention: ["Crop rotation", "Mulching"],
    management: ["Remove infected foliage", "Apply fungicide"]
)

let powderyMildew = Disease(
    name: "Powdery Mildew",
    pathogen: "Erysiphe cichoracearum",
    pathogenType: .fungal,
    symptoms: "White powdery coating on leaves"
)
