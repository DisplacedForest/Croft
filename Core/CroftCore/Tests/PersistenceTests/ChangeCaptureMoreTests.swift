import Domain
import Foundation
import GRDB
import Testing

@testable import Persistence

private func capturePhotoStore() -> PhotoStore {
    PhotoStore(
        baseURL: FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true))
}

private func captureBed(_ capture: ChangeCapture) throws -> Planting {
    let planting = Planting(identity: .cultivar(capture.cultivar.id), bedID: capture.bed.id)
    try PlantingRepository(capture.database).insert(planting)
    return planting
}

@Test func seedLotWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    let lots = SeedLotRepository(capture.database)
    var added = SeedLot(cultivarID: capture.cultivar.id, source: "Baker Creek")
    try capture.expectLifecycle(.seedLot, added.id.rawValue) {
        try lots.insert(added)
    } update: {
        added.notes = "Stored in the cellar"
        try lots.update(added)
    } delete: {
        try lots.delete(id: added.id)
    }
}

@Test func starterBatchWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    let lots = SeedLotRepository(capture.database)
    let batches = StarterBatchRepository(capture.database)
    let lot = SeedLot(cultivarID: capture.cultivar.id, source: "Baker Creek")
    try lots.insert(lot)
    var added = StarterBatch(seedLotID: lot.id)
    try capture.expectLifecycle(.starterBatch, added.id.rawValue) {
        try batches.insert(added)
    } update: {
        added.quantity = 24
        try batches.update(added)
    } delete: {
        try batches.delete(id: added.id)
    }
}

@Test func plantingWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    let plantings = PlantingRepository(capture.database)
    var added = Planting(identity: .cultivar(capture.cultivar.id), bedID: capture.bed.id)
    try capture.expectLifecycle(.planting, added.id.rawValue) {
        try plantings.insert(added)
    } update: {
        added.notes = "Second sowing"
        try plantings.update(added)
    } delete: {
        try plantings.delete(id: added.id)
    }
}

@Test func harvestWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    let planting = try captureBed(capture)
    let harvests = HarvestRepository(capture.database)
    var added = Harvest(
        plantingID: planting.id,
        harvestedOn: harvestedDate,
        yield: try measured(1.5, .kilogram)
    )
    try capture.expectLifecycle(.harvest, added.id.rawValue) {
        try harvests.insert(added)
    } update: {
        added.notes = "Weighed twice"
        try harvests.update(added)
    } delete: {
        try harvests.delete(id: added.id)
    }
}

@Test func observationWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    let observations = ObservationRepository(capture.database, photos: capturePhotoStore())
    var added = Observation(target: .bed(capture.bed.id), observedAt: observedDate)
    try capture.expectLifecycle(.observation, added.id.rawValue) {
        try observations.insert(added)
    } update: {
        added.notes = "Leaves curling"
        try observations.update(added)
    } delete: {
        try observations.delete(id: added.id)
    }
}

@Test func observationPhotoWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    let observations = ObservationRepository(capture.database, photos: capturePhotoStore())
    let observed = Observation(target: .bed(capture.bed.id), observedAt: observedDate)
    try observations.insert(observed)
    let photo = ObservationPhoto(
        id: UUID().uuidString,
        observationID: observed.id,
        relativePath: "observations/\(observed.id.rawValue)/one.jpg",
        createdAt: observedDate
    )
    let before = try capture.log.count()
    try observations.applyPhoto(photo)
    #expect(try capture.operations(.observationPhoto, photo.id) == [.create])
    try observations.applyPhoto(photo)
    #expect(try capture.operations(.observationPhoto, photo.id) == [.create, .update])
    #expect(try capture.log.count() == before + 2)
}

@Test func gardenTaskWritesAreCaptured() throws {
    let capture = try ChangeCapture()
    let tasks = GardenTaskRepository(capture.database)
    var added = GardenTask(type: .water, title: "Water the long bed")
    try capture.expectLifecycle(.task, added.id.rawValue) {
        try tasks.insert(added)
    } update: {
        added.title = "Water the long bed twice"
        try tasks.update(added)
    } delete: {
        try tasks.delete(id: added.id)
    }
}

@Test func gardenTaskCompletionAndReopeningLogUpdates() throws {
    let capture = try ChangeCapture()
    let tasks = GardenTaskRepository(capture.database)
    let added = GardenTask(type: .water, title: "Water the long bed")
    try tasks.insert(added)
    let before = try capture.log.count()
    try tasks.complete(id: added.id, on: completionDate)
    #expect(try capture.operations(.task, added.id.rawValue) == [.create, .update])
    try tasks.reopen(id: added.id)
    #expect(try capture.operations(.task, added.id.rawValue) == [.create, .update, .update])
    #expect(try capture.log.count() == before + 2)
}

@Test func dailyWeatherUpsertLogsCreateThenUpdate() throws {
    let capture = try ChangeCapture()
    let weather = DailyWeatherRepository(capture.database)
    let day = try #require(DayStamp(year: 2026, month: 8, day: 18))
    let entityID = "\(capture.property.id.rawValue)/\(day.storageValue)"
    let reading = DailyWeather(
        propertyID: capture.property.id,
        day: day,
        highCelsius: 24,
        provenance: .observed
    )
    let before = try capture.log.count()
    try weather.upsert(reading)
    #expect(try capture.operations(.dailyWeather, entityID) == [.create])
    var revised = reading
    revised.highCelsius = 26
    try weather.upsert(revised)
    #expect(try capture.operations(.dailyWeather, entityID) == [.create, .update])
    #expect(try capture.log.count() == before + 2)
}

@Test func applyInsertsThenUpdatesTheSameRecord() throws {
    let capture = try ChangeCapture()
    let plantings = PlantingRepository(capture.database)
    var planting = Planting(identity: .cultivar(capture.cultivar.id), bedID: capture.bed.id)
    try plantings.apply(planting)
    #expect(try capture.operations(.planting, planting.id.rawValue) == [.create])
    planting.notes = "Applied twice"
    try plantings.apply(planting)
    #expect(try capture.operations(.planting, planting.id.rawValue) == [.create, .update])
    #expect(try plantings.fetch(id: planting.id)?.notes == "Applied twice")
}

@Test func databaseWithoutRecordingLogsNothing() throws {
    let capture = try ChangeCapture(recordingChanges: false)
    #expect(try capture.log.count() == 0)
    let plantings = PlantingRepository(capture.database)
    let planting = Planting(identity: .cultivar(capture.cultivar.id), bedID: capture.bed.id)
    try plantings.insert(planting)
    try plantings.delete(id: planting.id)
    #expect(try capture.log.count() == 0)
    #expect(try capture.log.all().isEmpty)
}
