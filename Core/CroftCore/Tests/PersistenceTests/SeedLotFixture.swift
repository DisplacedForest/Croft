import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

let seedLotIdentifier = "v008-seed-lots"

struct SeedLotFixture {
    let database: AppDatabase
    let families: PlantFamilyRepository
    let genera: GenusRepository
    let species: SpeciesRepository
    let cultivars: CultivarRepository
    let seedLots: SeedLotRepository
    let starterBatches: StarterBatchRepository
    let cultivar: Cultivar

    init() throws {
        database = try AppDatabase.inMemory()
        families = PlantFamilyRepository(database)
        genera = GenusRepository(database)
        species = SpeciesRepository(database)
        cultivars = CultivarRepository(database)
        seedLots = SeedLotRepository(database)
        starterBatches = StarterBatchRepository(database)

        let family = PlantFamily(name: "Solanaceae")
        let genus = Genus(familyID: family.id, name: "Solanum")
        let plant = Species(genusID: genus.id, scientificName: "Solanum lycopersicum")
        cultivar = Cultivar(speciesID: plant.id, name: "Brandywine")
        try families.insert(family)
        try genera.insert(genus)
        try species.insert(plant)
        try cultivars.insert(cultivar)
    }

    func addCultivar(named name: String) throws -> Cultivar {
        let added = Cultivar(speciesID: cultivar.speciesID, name: name)
        try cultivars.insert(added)
        return added
    }

    func outgoing(_ id: String, _ type: RelationshipType) throws -> [Edge] {
        try database.writer.read { db in
            try GraphStore.outgoing(from: id, via: type, in: db)
        }
    }

    func incoming(_ id: String, _ type: RelationshipType) throws -> [Edge] {
        try database.writer.read { db in
            try GraphStore.incoming(to: id, via: type, in: db)
        }
    }

    func registered(_ id: String) throws -> EntityRef? {
        try database.writer.read { db in
            try GraphStore.registered(id, in: db)
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

    func row(_ table: String, _ id: String) throws -> Row? {
        try database.writer.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM \(table) WHERE id = ?", arguments: [id])
        }
    }
}

let acquisitionDate = Date(timeIntervalSince1970: 1_700_000_000)
let sowingDate = Date(timeIntervalSince1970: 1_705_000_000)
