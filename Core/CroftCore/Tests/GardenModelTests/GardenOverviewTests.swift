import Domain
import Foundation
import GardenModel
import Persistence
import Testing

struct GardenOverviewTests {
    @Test func groupsBedsUnderGardensAndGrowingAreas() throws {
        let fixture = try GardenFixture()
        let overview = try GardenOverview.load(from: fixture.database)

        let group = try #require(overview.gardens.first)
        #expect(group.garden == fixture.garden)
        #expect(group.beds.map(\.bed) == [fixture.bed])
        #expect(group.areas.map(\.area) == [fixture.growingArea])
        #expect(group.areas.first?.beds.map(\.bed) == [fixture.tunnelBed])
    }

    @Test func bedSummariesCarryCurrentPlantingsWithPlantNames() throws {
        let fixture = try GardenFixture()
        let active = try fixture.addPlanting(status: .active, plantedOn: april)
        let planned = try fixture.addPlanting(
            identity: .species(fixture.tomatoSpecies.id), status: .planned)
        try fixture.addPlanting(status: .finished, plantedOn: march, endedOn: may)

        let overview = try GardenOverview.load(from: fixture.database)
        let summary = try #require(overview.gardens.first?.beds.first)
        #expect(summary.plantings.map(\.planting.id) == [active.id, planned.id])
        #expect(summary.plantings.map(\.plantName) == ["Brandywine", "Tomato"])
    }

    @Test func latestActivityIsTheMostRecentLifecycleEvent() throws {
        let fixture = try GardenFixture()
        try fixture.addPlanting(status: .active, plantedOn: march, transplantedOn: april)
        try fixture.addPlanting(status: .finished, plantedOn: march, endedOn: june)

        let overview = try GardenOverview.load(from: fixture.database)
        let activity = try #require(overview.gardens.first?.beds.first?.latestActivity)
        #expect(activity.kind == .finished)
        #expect(activity.date == june)
        #expect(activity.plantName == "Brandywine")
    }

    @Test func archivedStructuresAreExcluded() throws {
        let fixture = try GardenFixture()
        try fixture.structures.setBedArchived(fixture.bed.id, true)
        try fixture.structures.setGrowingAreaArchived(fixture.growingArea.id, true)

        let overview = try GardenOverview.load(from: fixture.database)
        let group = try #require(overview.gardens.first)
        #expect(group.beds.isEmpty)
        #expect(group.areas.isEmpty)
    }

    @Test func anEmptyDatabaseYieldsAnEmptyOverview() throws {
        let database = try AppDatabase.inMemory()
        let overview = try GardenOverview.load(from: database)
        #expect(overview.gardens.isEmpty)
        #expect(overview.isEmpty)
    }

    @Test func aGardenWithNoBedsIsNotEmpty() throws {
        let fixture = try GardenFixture()
        let overview = try GardenOverview.load(from: fixture.database)
        #expect(!overview.isEmpty)
    }
}
