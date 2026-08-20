import Domain
import Foundation
import GRDB
import Testing

@testable import Persistence

private let seasonTables: [(table: String, order: String)] = [
    ("property", "id"), ("garden", "id"), ("growing_area", "id"), ("bed", "id"),
    ("plant_family", "id"), ("genus", "id"), ("species", "id"), ("cultivar", "id"),
    ("pest", "id"), ("disease", "id"), ("pathogen", "id"), ("environmental_condition", "id"),
    ("seed_lot", "id"), ("starter_batch", "id"), ("planting", "id"),
    ("observation", "id"), ("observation_photo", "id"), ("harvest", "id"), ("task", "id"),
    ("daily_weather", "property_id, date"),
    ("entity", "id"),
]

private let edgeQuery = """
    SELECT from_entity_id, relationship_type, to_entity_id,
        source, source_type, confidence, notes
    FROM relationship
    ORDER BY from_entity_id, relationship_type, to_entity_id
    """

private func snapshot(_ database: AppDatabase) throws -> [String: [Row]] {
    try database.writer.read { db in
        var result: [String: [Row]] = [:]
        for entry in seasonTables {
            result[entry.table] = try Row.fetchAll(
                db, sql: "SELECT * FROM \(entry.table) ORDER BY \(entry.order)")
        }
        result["relationship"] = try Row.fetchAll(db, sql: edgeQuery)
        return result
    }
}

private func expectIdenticalState(_ left: AppDatabase, _ right: AppDatabase) throws {
    let leftState = try snapshot(left)
    let rightState = try snapshot(right)
    for table in seasonTables.map(\.table) + ["relationship"] {
        #expect(leftState[table] == rightState[table], "table \(table) diverged")
    }
}

private struct Season {
    let database: AppDatabase
    let photoRoot: URL
    var day = Date(timeIntervalSince1970: 1_710_000_000)

    init() throws {
        database = try AppDatabase.inMemory()
        photoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("season-\(UUID().uuidString)", isDirectory: true)
    }

    mutating func advance() -> Date {
        day = day.addingTimeInterval(86_400)
        return day
    }

    mutating func live() throws {
        let structures = GardenStructureRepository(database)
        let property = Property(name: "Home")
        try structures.create(property)
        try structures.updatePropertyDetails(
            property.id,
            PropertyDetails(
                location: GeoCoordinate(latitude: 44.5, longitude: -72.8),
                hardinessZone: HardinessZone(number: 4),
                lastFrost: MonthDay(month: 5, day: 15),
                firstFrost: MonthDay(month: 9, day: 28),
                zoneSource: .user,
                frostDatesSource: .user
            )
        )
        let garden = Garden(name: "Kitchen Garden")
        try structures.create(garden, in: property.id)
        let tunnel = GrowingArea(name: "Polytunnel")
        try structures.create(tunnel, in: garden.id)
        let bed = Bed(name: "Long Bed", kind: .raised)
        try structures.create(bed, in: .garden(garden.id))
        let spare = Bed(name: "Spare Bed", kind: .container)
        try structures.create(spare, in: .growingArea(tunnel.id))
        try structures.renameBed(spare.id, to: "Herb Bed")
        try structures.moveBed(spare.id, to: .garden(garden.id))
        try structures.setBedArchived(spare.id, true)

        let family = PlantFamily(name: "Solanaceae")
        let genus = Genus(familyID: family.id, name: "Solanum")
        let species = Species(
            genusID: genus.id, scientificName: "Solanum lycopersicum", commonNames: ["Tomato"])
        let cultivar = Cultivar(speciesID: species.id, name: "Brandywine")
        try PlantFamilyRepository(database).insert(family)
        try GenusRepository(database).insert(genus)
        try SpeciesRepository(database).insert(species)
        try CultivarRepository(database).insert(cultivar)

        let lot = SeedLot(cultivarID: cultivar.id, source: "Baker Creek")
        try SeedLotRepository(database).insert(lot)
        let batch = StarterBatch(seedLotID: lot.id, sownOn: advance())
        try StarterBatchRepository(database).insert(batch)

        var planting = Planting(
            identity: .cultivar(cultivar.id),
            bedID: bed.id,
            source: .seedLot(lot.id),
            plantedOn: advance(),
            status: .active
        )
        try PlantingRepository(database).insert(planting)
        planting.quantity = 4
        try PlantingRepository(database).update(planting)

        try growingSeason(planting: planting, bed: bed, property: property)
    }

    private mutating func growingSeason(
        planting: Planting,
        bed: Bed,
        property: Property
    ) throws {
        try observe(planting: planting, bed: bed)
        try harvestAndTend(planting: planting, property: property)
    }

    private mutating func observe(planting: Planting, bed: Bed) throws {
        let observations = ObservationRepository(
            database, photos: PhotoStore(baseURL: photoRoot))
        try observations.insert(
            Observation(
                target: .planting(planting.id), observedAt: advance(), stage: .germinated))
        var note = Observation(
            target: .planting(planting.id), observedAt: advance(),
            notes: "Hornworm frass on lower leaves")
        try observations.insert(note)
        _ = try observations.addPhoto(Data([0xFF, 0xD8]), to: note.id)
        note.notes = "Hornworm frass, picked two off"
        try observations.update(note)
        let doomed = Observation(target: .bed(bed.id), observedAt: advance(), notes: "scratch")
        try observations.insert(doomed)
        _ = try observations.delete(id: doomed.id)

    }

    private mutating func harvestAndTend(planting: Planting, property: Property) throws {
        let harvests = HarvestRepository(database)
        var harvest = Harvest(
            plantingID: planting.id,
            harvestedOn: advance(),
            yield: .measured(try Quantity(amount: 410, unit: .gram)),
            harvestedPart: .fruit
        )
        try harvests.insert(harvest)
        harvest.quality = .good
        try harvests.update(harvest)
        let extra = Harvest(
            plantingID: planting.id,
            harvestedOn: advance(),
            yield: .measured(try Quantity(amount: 2, unit: .count))
        )
        try harvests.insert(extra)
        _ = try harvests.delete(id: extra.id)

        let tasks = GardenTaskRepository(database)
        let task = GardenTask(
            type: .water, title: "Water the tomatoes", dueOn: advance(),
            target: .planting(planting.id))
        try tasks.insert(task)
        try tasks.complete(id: task.id, on: advance())
        try tasks.reopen(id: task.id)
        try tasks.complete(id: task.id, on: advance())

        let weather = DailyWeatherRepository(database)
        for offset in 0..<3 {
            let stamp = try #require(DayStamp(year: 2026, month: 8, day: 10 + offset))
            try weather.upsert(
                DailyWeather(
                    propertyID: property.id, day: stamp, highCelsius: 20 + Double(offset),
                    provenance: .observed))
        }
        let repeated = try #require(DayStamp(year: 2026, month: 8, day: 10))
        try weather.upsert(
            DailyWeather(
                propertyID: property.id, day: repeated, highCelsius: 27,
                provenance: .backfilled))
    }
}

private func interleavedShuffle(_ records: [ChangeRecord]) -> [ChangeRecord] {
    var result: [ChangeRecord] = []
    var front = 0
    var back = records.count - 1
    while front <= back {
        result.append(records[back])
        if front != back {
            result.append(records[front])
        }
        front += 1
        back -= 1
    }
    return result
}

struct ChangeReplayTests {
    @Test func aLoggedSeasonReplaysIntoAnIdenticalDatabase() throws {
        var season = try Season()
        try season.live()
        let target = try AppDatabase.inMemory()
        try ChangeReplayer(source: season.database, target: target).replayAll()
        try expectIdenticalState(season.database, target)
    }

    @Test func shuffledAndDuplicatedReplayConverges() throws {
        var season = try Season()
        try season.live()
        let records = try ChangeLogRepository(season.database).all()
        let mangled = interleavedShuffle(records) + records + interleavedShuffle(records)
        let target = try AppDatabase.inMemory()
        try ChangeReplayer(source: season.database, target: target).replay(mangled)
        try expectIdenticalState(season.database, target)
    }

    @Test func replayingTwiceIntoTheSameTargetIsIdempotent() throws {
        var season = try Season()
        try season.live()
        let target = try AppDatabase.inMemory()
        let replayer = ChangeReplayer(source: season.database, target: target)
        try replayer.replayAll()
        try replayer.replayAll()
        try expectIdenticalState(season.database, target)
    }

    @Test func theSeasonLogCoversEveryLoggedKindItTouched() throws {
        var season = try Season()
        try season.live()
        let kinds = Set(try ChangeLogRepository(season.database).all().map(\.kind))
        let expected: Set<ChangeKind> = [
            .property, .garden, .growingArea, .bed,
            .plantFamily, .genus, .species, .cultivar,
            .seedLot, .starterBatch, .planting,
            .observation, .observationPhoto, .harvest, .task, .dailyWeather,
        ]
        #expect(kinds == expected)
    }
}
