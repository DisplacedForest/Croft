import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

let gardenTaskIdentifier = "v014-garden-tasks"

final class GardenTaskFixture {
    let database: AppDatabase
    let structures: GardenStructureRepository
    let plantings: PlantingRepository
    let tasks: GardenTaskRepository
    let species: Species
    let cultivar: Cultivar
    let property: Property
    let garden: Garden
    let otherGarden: Garden
    let bed: Bed
    let otherBed: Bed
    let planting: Planting

    init() throws {
        database = try AppDatabase.inMemory()
        structures = GardenStructureRepository(database)
        plantings = PlantingRepository(database)
        tasks = GardenTaskRepository(database)

        let family = PlantFamily(name: "Solanaceae")
        let genus = Genus(familyID: family.id, name: "Solanum")
        species = Species(genusID: genus.id, scientificName: "Solanum lycopersicum")
        cultivar = Cultivar(speciesID: species.id, name: "Brandywine")
        try PlantFamilyRepository(database).insert(family)
        try GenusRepository(database).insert(genus)
        try SpeciesRepository(database).insert(species)
        try CultivarRepository(database).insert(cultivar)

        property = Property(name: "Home")
        garden = Garden(name: "Kitchen Garden")
        otherGarden = Garden(name: "Orchard")
        bed = Bed(name: "Long Bed", kind: .raised)
        otherBed = Bed(name: "Orchard Bed", kind: .container)
        try structures.create(property)
        try structures.create(garden, in: property.id)
        try structures.create(otherGarden, in: property.id)
        try structures.create(bed, in: .garden(garden.id))
        try structures.create(otherBed, in: .garden(otherGarden.id))

        planting = Planting(identity: .cultivar(cultivar.id), bedID: bed.id)
        try plantings.insert(planting)
    }

    func task(
        type: GardenTaskType = .water,
        customType: String? = nil,
        title: String = "Water the long bed",
        dueOn: Date? = dueDate,
        target: GardenTaskTarget? = nil
    ) -> GardenTask {
        GardenTask(
            type: type,
            customType: customType,
            title: title,
            dueOn: dueOn,
            target: target
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

    func taskRow(_ id: String) throws -> Row? {
        try database.writer.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM task WHERE id = ?", arguments: [id])
        }
    }

    func insertUnchecked(
        id: String,
        type: String = "water",
        customType: String? = nil,
        completed: Bool = false,
        completedOn: Date? = nil,
        gardenID: String? = nil,
        bedID: String? = nil
    ) throws {
        try database.writer.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints = ON")
            try db.execute(
                sql: """
                    INSERT INTO task
                        (id, type, custom_type, title, completed, completed_on,
                         garden_id, bed_id)
                    VALUES (?, ?, ?, 'corrupted', ?, ?, ?, ?)
                    """,
                arguments: [id, type, customType, completed, completedOn, gardenID, bedID]
            )
            try db.execute(sql: "PRAGMA ignore_check_constraints = OFF")
        }
    }
}

let dueDate = Date(timeIntervalSince1970: 1_720_000_000)
let laterDueDate = Date(timeIntervalSince1970: 1_722_000_000)
let latestDueDate = Date(timeIntervalSince1970: 1_724_000_000)
let completionDate = Date(timeIntervalSince1970: 1_725_000_000)
