import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

let harvestIdentifier = "v013-harvests"

final class HarvestFixture {
    let database: AppDatabase
    let structures: GardenStructureRepository
    let plantings: PlantingRepository
    let harvests: HarvestRepository
    let tomato: Species
    let brandywine: Cultivar
    let basil: Species
    let property: Property
    let garden: Garden
    let bed: Bed
    let tomatoPlanting: Planting
    let basilPlanting: Planting

    init() throws {
        database = try AppDatabase.inMemory()
        structures = GardenStructureRepository(database)
        plantings = PlantingRepository(database)
        harvests = HarvestRepository(database)

        let families = PlantFamilyRepository(database)
        let genera = GenusRepository(database)
        let speciesRepository = SpeciesRepository(database)
        let solanaceae = PlantFamily(name: "Solanaceae")
        let solanum = Genus(familyID: solanaceae.id, name: "Solanum")
        tomato = Species(genusID: solanum.id, scientificName: "Solanum lycopersicum")
        brandywine = Cultivar(speciesID: tomato.id, name: "Brandywine")
        let lamiaceae = PlantFamily(name: "Lamiaceae")
        let ocimum = Genus(familyID: lamiaceae.id, name: "Ocimum")
        basil = Species(genusID: ocimum.id, scientificName: "Ocimum basilicum")
        try families.insert(solanaceae)
        try families.insert(lamiaceae)
        try genera.insert(solanum)
        try genera.insert(ocimum)
        try speciesRepository.insert(tomato)
        try speciesRepository.insert(basil)
        try CultivarRepository(database).insert(brandywine)

        property = Property(name: "Home")
        garden = Garden(name: "Kitchen Garden")
        bed = Bed(name: "Long Bed", kind: .raised)
        try structures.create(property)
        try structures.create(garden, in: property.id)
        try structures.create(bed, in: .garden(garden.id))

        tomatoPlanting = Planting(identity: .cultivar(brandywine.id), bedID: bed.id)
        basilPlanting = Planting(identity: .species(basil.id), bedID: bed.id)
        try plantings.insert(tomatoPlanting)
        try plantings.insert(basilPlanting)
    }

    func harvest(
        of planting: Planting? = nil,
        on date: Date = harvestedDate,
        yield: HarvestYield? = nil,
        part: HarvestablePart? = nil
    ) throws -> Harvest {
        Harvest(
            plantingID: (planting ?? tomatoPlanting).id,
            harvestedOn: date,
            yield: try yield ?? measured(1.5, .kilogram),
            harvestedPart: part
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

    func harvestRow(_ id: String) throws -> Row? {
        try database.writer.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM harvest WHERE id = ?", arguments: [id])
        }
    }

    func insertUnchecked(
        id: String,
        unit: String,
        family: String?,
        customUnit: String?
    ) throws {
        try database.writer.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints = ON")
            try db.execute(
                sql: """
                    INSERT INTO harvest
                        (id, planting_id, harvested_on, yield_amount, yield_unit,
                         yield_family, custom_unit)
                    VALUES (?, ?, '2024-07-03 12:00:00', 2.0, ?, ?, ?)
                    """,
                arguments: [id, tomatoPlanting.id.rawValue, unit, family, customUnit]
            )
            try db.execute(sql: "PRAGMA ignore_check_constraints = OFF")
        }
    }
}

func measured(_ amount: Double, _ unit: QuantityUnit) throws -> HarvestYield {
    .measured(try Quantity(amount: amount, unit: unit))
}

let harvestedDate = Date(timeIntervalSince1970: 1_720_000_000)
let laterHarvestedDate = Date(timeIntervalSince1970: 1_722_000_000)
let latestHarvestedDate = Date(timeIntervalSince1970: 1_724_000_000)
