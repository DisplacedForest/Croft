import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

let plantingIdentifier = "v009-plantings"

struct PlantingFixture {
    let database: AppDatabase
    let families: PlantFamilyRepository
    let genera: GenusRepository
    let species: SpeciesRepository
    let cultivars: CultivarRepository
    let seedLots: SeedLotRepository
    let starterBatches: StarterBatchRepository
    let structures: GardenStructureRepository
    let plantings: PlantingRepository
    let plant: Species
    let cultivar: Cultivar
    let property: Property
    let garden: Garden
    let growingArea: GrowingArea
    let bed: Bed
    let tunnelBed: Bed
    let otherGarden: Garden
    let otherBed: Bed
    let seedLot: SeedLot
    let starterBatch: StarterBatch

    init() throws {
        database = try AppDatabase.inMemory()
        families = PlantFamilyRepository(database)
        genera = GenusRepository(database)
        species = SpeciesRepository(database)
        cultivars = CultivarRepository(database)
        seedLots = SeedLotRepository(database)
        starterBatches = StarterBatchRepository(database)
        structures = GardenStructureRepository(database)
        plantings = PlantingRepository(database)

        let family = PlantFamily(name: "Solanaceae")
        let genus = Genus(familyID: family.id, name: "Solanum")
        plant = Species(genusID: genus.id, scientificName: "Solanum lycopersicum")
        cultivar = Cultivar(speciesID: plant.id, name: "Brandywine")
        try families.insert(family)
        try genera.insert(genus)
        try species.insert(plant)
        try cultivars.insert(cultivar)

        property = Property(name: "Home")
        garden = Garden(name: "Kitchen Garden")
        growingArea = GrowingArea(name: "Polytunnel")
        bed = Bed(name: "Long Bed", kind: .raised)
        tunnelBed = Bed(name: "Tunnel Bed", kind: .inGround)
        otherGarden = Garden(name: "Orchard")
        otherBed = Bed(name: "Orchard Bed", kind: .container)
        try structures.create(property)
        try structures.create(garden, in: property.id)
        try structures.create(growingArea, in: garden.id)
        try structures.create(bed, in: .garden(garden.id))
        try structures.create(tunnelBed, in: .growingArea(growingArea.id))
        try structures.create(otherGarden, in: property.id)
        try structures.create(otherBed, in: .garden(otherGarden.id))

        seedLot = SeedLot(cultivarID: cultivar.id, source: "Baker Creek")
        try seedLots.insert(seedLot)
        starterBatch = StarterBatch(seedLotID: seedLot.id)
        try starterBatches.insert(starterBatch)
    }

    func addCultivar(named name: String) throws -> Cultivar {
        let added = Cultivar(speciesID: cultivar.speciesID, name: name)
        try cultivars.insert(added)
        return added
    }

    func planting(
        source: PlantingSource? = nil,
        status: PlantingStatus = .planned
    ) -> Planting {
        Planting(
            identity: .cultivar(cultivar.id),
            bedID: bed.id,
            source: source,
            status: status
        )
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

let plantingDate = Date(timeIntervalSince1970: 1_710_000_000)
let transplantDate = Date(timeIntervalSince1970: 1_712_000_000)
let maturityDate = Date(timeIntervalSince1970: 1_715_000_000)
let endDate = Date(timeIntervalSince1970: 1_718_000_000)
