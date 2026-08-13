import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

let observationIdentifier = "v012-observations"

final class ObservationFixture {
    let database: AppDatabase
    let photoRoot: URL
    let photos: PhotoStore
    let structures: GardenStructureRepository
    let plantings: PlantingRepository
    let cultivars: CultivarRepository
    let observations: ObservationRepository
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
        photoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        photos = PhotoStore(baseURL: photoRoot)
        structures = GardenStructureRepository(database)
        plantings = PlantingRepository(database)
        cultivars = CultivarRepository(database)
        observations = ObservationRepository(database, photos: photos)

        let family = PlantFamily(name: "Solanaceae")
        let genus = Genus(familyID: family.id, name: "Solanum")
        species = Species(genusID: genus.id, scientificName: "Solanum lycopersicum")
        cultivar = Cultivar(speciesID: species.id, name: "Brandywine")
        try PlantFamilyRepository(database).insert(family)
        try GenusRepository(database).insert(genus)
        try SpeciesRepository(database).insert(species)
        try cultivars.insert(cultivar)

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

    deinit {
        try? FileManager.default.removeItem(at: photoRoot)
    }

    func observation(
        on target: ObservationTarget? = nil,
        at date: Date = observedDate
    ) -> Observation {
        Observation(target: target ?? .bed(bed.id), observedAt: date)
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

    func photoRowCount(_ id: Observation.ID) throws -> Int? {
        try database.writer.read { db in
            try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM observation_photo WHERE observation_id = ?",
                arguments: [id.rawValue]
            )
        }
    }

    func observationRow(_ id: String) throws -> Row? {
        try database.writer.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM observation WHERE id = ?", arguments: [id])
        }
    }

    func fileExists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: photos.url(forRelativePath: relativePath).path)
    }

    func targets() -> [ObservationTarget] {
        [
            .planting(planting.id),
            .plant(.cultivar(cultivar.id)),
            .plant(.species(species.id)),
            .bed(bed.id),
            .garden(garden.id),
        ]
    }
}

let observedDate = Date(timeIntervalSince1970: 1_720_000_000)
let laterObservedDate = Date(timeIntervalSince1970: 1_722_000_000)
let latestObservedDate = Date(timeIntervalSince1970: 1_724_000_000)
