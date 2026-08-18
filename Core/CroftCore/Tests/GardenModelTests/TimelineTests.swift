import Domain
import Foundation
import GardenModel
import Persistence
import Testing

struct PlantingTimelineTests {
    private let fixture: GardenFixture
    private let photoRoot: URL
    private let photos: PhotoStore
    private let observations: ObservationRepository
    private let harvests: HarvestRepository

    init() throws {
        fixture = try GardenFixture()
        photoRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        photos = PhotoStore(baseURL: photoRoot)
        observations = ObservationRepository(fixture.database, photos: photos)
        harvests = HarvestRepository(fixture.database)
    }

    private func day(_ offset: Int) throws -> Date {
        let start = Calendar.current.startOfDay(for: march)
        return try #require(Calendar.current.date(byAdding: .day, value: offset, to: start))
    }

    private func load(
        _ planting: Planting,
        display: UnitSystem = .metric,
        threatNames: Set<String> = []
    ) throws -> PlantingTimeline {
        try #require(
            try PlantingTimeline.load(
                planting.id,
                from: fixture.database,
                photos: photos,
                display: display,
                threatNames: threatNames))
    }

    private func stage(
        _ stage: LifecycleStage,
        on planting: Planting,
        at date: Date
    ) throws {
        try observations.insert(
            Observation(target: .planting(planting.id), observedAt: date, stage: stage))
    }

    private func makeFullSeason() throws -> Planting {
        let lots = SeedLotRepository(fixture.database)
        let lot = SeedLot(cultivarID: fixture.tomatoCultivar.id, source: "Baker Creek")
        try lots.insert(lot)
        let planting = Planting(
            identity: .cultivar(fixture.tomatoCultivar.id),
            bedID: fixture.bed.id,
            source: .seedLot(lot.id),
            plantedOn: try day(0),
            status: .active,
            notes: "Six cells on the heat mat."
        )
        try fixture.plantings.insert(planting)
        try stage(.germinated, on: planting, at: try day(7))
        try stage(.transplanted, on: planting, at: try day(42))
        try stage(.firstFlower, on: planting, at: try day(67))
        try stage(.firstFruitSet, on: planting, at: try day(87))
        try observations.insert(
            Observation(
                target: .planting(planting.id),
                observedAt: try day(80),
                notes: "Hornworm frass on lower leaves\nPicked two off by hand."))
        try harvests.insert(
            Harvest(
                plantingID: planting.id,
                harvestedOn: try day(119),
                yield: .measured(try Quantity(amount: 410, unit: .gram)),
                harvestedPart: .fruit,
                notes: "Two big ones off the lowest truss."))
        try harvests.insert(
            Harvest(
                plantingID: planting.id,
                harvestedOn: try day(125),
                yield: .measured(try Quantity(amount: 940, unit: .gram)),
                harvestedPart: .fruit,
                quality: .good))
        return planting
    }

    @Test func aFullSeasonRendersEveryEventKindNewestFirst() throws {
        let timeline = try load(try makeFullSeason())
        #expect(
            timeline.entries.map(\.kind) == [
                .harvest(first: false),
                .harvest(first: true),
                .stage(.firstFruitSet),
                .observation(threat: false),
                .stage(.firstFlower),
                .stage(.transplanted),
                .stage(.germinated),
                .planted,
            ])
        #expect(timeline.entries.first?.title == "940 g, fruit")
        #expect(timeline.entries.first?.excerpt == "Quality good.")
        let first = timeline.entries[1]
        #expect(first.title == "410 g, fruit")
        #expect(first.detail == "119 days from sowing")
        #expect(first.excerpt == "Two big ones off the lowest truss.")
        let germinated = try #require(
            timeline.entries.first { $0.kind == .stage(.germinated) })
        #expect(germinated.detail == "7 days from sowing")
        let fruitSet = try #require(
            timeline.entries.first { $0.kind == .stage(.firstFruitSet) })
        #expect(fruitSet.detail == "day 87")
        let observation = try #require(
            timeline.entries.first { $0.kind == .observation(threat: false) })
        #expect(observation.title == "Hornworm frass on lower leaves")
        #expect(observation.excerpt == "Picked two off by hand.")
        let planted = try #require(timeline.entries.last)
        #expect(planted.title == "Sown from seed, Baker Creek")
        #expect(planted.excerpt == "Six cells on the heat mat.")
        #expect(timeline.stats.daysToFirstHarvest == 119)
        #expect(timeline.stats.harvestCount == 2)
        #expect(timeline.stats.totalYield == "1.35 kg")
    }

    @Test func aJustPlantedTimelineIsOneEntry() throws {
        let planting = try fixture.addPlanting(status: .active, plantedOn: try day(0))
        let timeline = try load(planting)
        #expect(timeline.entries.count == 1)
        #expect(timeline.entries.first?.kind == .planted)
        #expect(timeline.stats.daysToFirstHarvest == nil)
        #expect(timeline.stats.totalYield == nil)
        #expect(timeline.stats.harvestCount == 0)
    }

    @Test func sameDayEventsOrderByKindThenIdentifier() throws {
        let planting = try fixture.addPlanting(status: .active, plantedOn: try day(0))
        let collision = try day(30)
        try stage(.firstFlower, on: planting, at: collision)
        try observations.insert(
            Observation(
                target: .planting(planting.id), observedAt: collision, notes: "Buds everywhere."))
        try harvests.insert(
            Harvest(
                plantingID: planting.id,
                harvestedOn: collision,
                yield: .measured(try Quantity(amount: 2, unit: .count))))

        let timeline = try load(planting)
        #expect(
            timeline.entries.map(\.kind) == [
                .harvest(first: true),
                .observation(threat: false),
                .stage(.firstFlower),
                .planted,
            ])
        #expect(timeline.entries.map(\.kind) == (try load(planting)).entries.map(\.kind))
    }

    @Test func photolessObservationsCarryNoPhotoPath() throws {
        let planting = try fixture.addPlanting(status: .active, plantedOn: try day(0))
        try observations.insert(
            Observation(
                target: .planting(planting.id), observedAt: try day(10), notes: "Looking strong."))
        var withPhoto = Observation(
            target: .planting(planting.id), observedAt: try day(12), notes: "Leaf close-up.")
        try observations.insert(withPhoto)
        let path = try observations.addPhoto(Data([0xFF, 0xD8]), to: withPhoto.id)
        withPhoto.photos = [path]

        let timeline = try load(planting)
        let photoless = try #require(timeline.entries.first { $0.title == "Looking strong." })
        #expect(photoless.photoPath == nil)
        let pictured = try #require(timeline.entries.first { $0.title == "Leaf close-up." })
        #expect(pictured.photoPath == path)
    }

    @Test func yieldsFollowTheDisplayUnitSystem() throws {
        let planting = try fixture.addPlanting(status: .active, plantedOn: try day(0))
        let quantity = try Quantity(amount: 500, unit: .gram)
        try harvests.insert(
            Harvest(
                plantingID: planting.id,
                harvestedOn: try day(100),
                yield: .measured(quantity)))

        let metric = try load(planting, display: .metric)
        #expect(
            metric.entries.first?.title == QuantityFormatter(system: .metric).string(from: quantity)
        )
        let imperial = try load(planting, display: .imperial)
        #expect(
            imperial.entries.first?.title
                == QuantityFormatter(system: .imperial).string(from: quantity))
        #expect(imperial.entries.first?.title != metric.entries.first?.title)
    }

    @Test func threatContextComesFromSymptomsOrKnownNames() throws {
        let planting = try fixture.addPlanting(status: .active, plantedOn: try day(0))
        try observations.insert(
            Observation(
                target: .planting(planting.id),
                observedAt: try day(20),
                notes: "Something chewing the leaves.",
                symptoms: ["holes in leaves"]))
        try observations.insert(
            Observation(
                target: .planting(planting.id),
                observedAt: try day(21),
                notes: "Hornworm frass again."))
        try observations.insert(
            Observation(
                target: .planting(planting.id),
                observedAt: try day(22),
                notes: "Tied the main stem."))

        let timeline = try load(planting, threatNames: ["Tomato Hornworm", "Hornworm"])
        let flagged = timeline.entries.filter { $0.kind == .observation(threat: true) }
        #expect(flagged.map(\.title) == ["Hornworm frass again.", "Something chewing the leaves."])
        let calm = try #require(timeline.entries.first { $0.title == "Tied the main stem." })
        #expect(calm.kind == .observation(threat: false))
    }

    @Test func stageEventsSupersedePlantingDatePills() throws {
        let planting = try fixture.addPlanting(
            status: .finished,
            plantedOn: try day(0),
            transplantedOn: try day(40),
            endedOn: try day(150))
        try stage(.transplanted, on: planting, at: try day(42))
        try stage(.pulled, on: planting, at: try day(150))

        let timeline = try load(planting)
        let transplants = timeline.entries.filter { $0.kind == .stage(.transplanted) }
        #expect(transplants.map(\.date) == [try day(42)])
        #expect(!timeline.entries.contains { $0.kind == .ended(.finished) })
        #expect(timeline.entries.contains { $0.kind == .stage(.pulled) })
    }

    @Test func plantingDatesStandInWhenNoStageWasRecorded() throws {
        let planting = try fixture.addPlanting(
            status: .failed,
            plantedOn: try day(0),
            transplantedOn: try day(40),
            endedOn: try day(90))

        let timeline = try load(planting)
        #expect(
            timeline.entries.map(\.kind) == [
                .ended(.failed),
                .stage(.transplanted),
                .planted,
            ])
        let ended = try #require(timeline.entries.first)
        #expect(ended.title == "Failed")
    }
}
