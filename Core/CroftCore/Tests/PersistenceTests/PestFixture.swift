import Domain
import GRDB
import Graph
import Testing

@testable import Persistence

let pestIdentifier = "v005-pests"

struct PestFixture {
    let database: AppDatabase
    let repository: PestRepository

    init() throws {
        database = try AppDatabase.inMemory()
        repository = PestRepository(database)
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

let hornworm = Pest(
    commonName: "Tomato Hornworm",
    scientificName: "Manduca quinquemaculata",
    organismType: .pest,
    description: "Large green caterpillar with a rear horn",
    lifeCycle: "One to two generations per year",
    affectedPlantParts: [.leaf, .stem, .fruit],
    typicalDamage: "Defoliation and scarred fruit",
    activeSeasons: [.summer, .fall],
    geographicRange: "North America"
)

let braconidWasp = Pest(
    commonName: "Braconid Wasp",
    scientificName: "Cotesia congregata",
    organismType: .beneficial,
    description: "Parasitoid wasp of hornworm larvae",
    activeSeasons: [.spring, .summer],
    geographicRange: "North America"
)
