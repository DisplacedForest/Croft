import Domain
import Foundation
import Persistence
import PlantCatalog
import Testing

private let calendar = PlantingWindows.utcCalendar

private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = dayOfMonth
    return calendar.date(from: components)!
}

private let radish = Species(
    genusID: solanum.id,
    scientificName: "Raphanus sativus",
    commonNames: ["Radish"],
    daysToMaturity: 25...35,
    sowingMethod: .direct,
    frostTolerance: .hardy,
    daysToMaturityBasis: .fromDirectSow
)

private let pepper = Species(
    genusID: solanum.id,
    scientificName: "Capsicum annuum",
    commonNames: ["Pepper"],
    sowingMethod: .both,
    weeksIndoorsBeforeTransplant: 8...10,
    frostTolerance: .tender
)

private struct SeasonFixture {
    let fixture: CatalogFixture
    let planner: SeasonPlanner

    init(frostDates: Bool = true) throws {
        fixture = try CatalogFixture()
        try fixture.species.insert(radish)
        try fixture.species.insert(pepper)
        if frostDates {
            try fixture.structures.updatePropertyDetails(
                homeProperty.id,
                PropertyDetails(
                    location: nil,
                    hardinessZone: nil,
                    lastFrost: MonthDay(month: 5, day: 10),
                    firstFrost: MonthDay(month: 9, day: 28),
                    zoneSource: .user,
                    frostDatesSource: .user
                )
            )
        }
        planner = SeasonPlanner(fixture.database)
    }
}

struct SeasonPlannerWindowTests {
    @Test func plantableNowHoldsOnlyOpenWindows() throws {
        let season = try SeasonFixture()
        let overview = try season.planner.overview(on: day(2026, 4, 20), calendar: calendar)
        #expect(overview.hasFrostDates)
        #expect(overview.plantableNow.map(\.displayName) == ["Radish"])
        guard case .act(let opportunity) = overview.plantableNow[0].assessment else {
            Issue.record("expected act")
            return
        }
        #expect(opportunity.action == .directSow)
        #expect(opportunity.window.lowerBound == day(2026, 4, 12))
    }

    @Test func speciesMissingFieldsLandInUnassessed() throws {
        let season = try SeasonFixture()
        let overview = try season.planner.overview(on: day(2026, 4, 20), calendar: calendar)
        #expect(overview.unassessed.map(\.displayName) == ["Basil", "Tomato"])
        #expect(
            overview.unassessed.map(\.assessment).allSatisfy {
                if case .cannotAssess = $0 { true } else { false }
            })
    }

    @Test func upcomingIsBoundedByTheHorizon() throws {
        let season = try SeasonFixture()
        let overview = try season.planner.overview(on: day(2026, 2, 1), calendar: calendar)
        #expect(overview.plantableNow.isEmpty)
        #expect(overview.upcoming.map(\.displayName) == ["Pepper"])
        guard case .upcoming(let opportunity) = overview.upcoming[0].assessment else {
            Issue.record("expected upcoming")
            return
        }
        #expect(opportunity.action == .sowIndoors)
        #expect(opportunity.window.lowerBound == day(2026, 3, 1))
    }

    @Test func missingFrostDatesDegradeExplicitly() throws {
        let season = try SeasonFixture(frostDates: false)
        let overview = try season.planner.overview(on: day(2026, 4, 20), calendar: calendar)
        #expect(!overview.hasFrostDates)
        #expect(overview.plantableNow.isEmpty)
        #expect(overview.upcoming.isEmpty)
        #expect(overview.unassessed.isEmpty)
    }
}

struct SeasonPlannerGroupingTests {
    @Test func plantingsGroupByStatusAndYear() throws {
        let season = try SeasonFixture()
        let plantings = season.fixture.plantings

        let planned = Planting(identity: .species(radish.id), bedID: longBed.id, status: .planned)
        let active = Planting(
            identity: .cultivar(brandywine.id), bedID: tunnelBed.id,
            plantedOn: day(2026, 5, 12), status: .active)
        let finishedThisYear = Planting(
            identity: .species(radish.id), bedID: longBed.id,
            plantedOn: day(2026, 4, 1), status: .finished, endedOn: day(2026, 6, 1))
        let failedLastYear = Planting(
            identity: .species(radish.id), bedID: longBed.id,
            plantedOn: day(2025, 4, 1), status: .failed, endedOn: day(2025, 6, 1))
        try plantings.insert(planned)
        try plantings.insert(active)
        try plantings.insert(finishedThisYear)
        try plantings.insert(failedLastYear)

        let overview = try season.planner.overview(on: day(2026, 7, 1), calendar: calendar)
        #expect(overview.planned.map(\.id) == [planned.id.rawValue])
        #expect(overview.inGround.map(\.id) == [active.id.rawValue])
        #expect(overview.finished.map(\.id) == [finishedThisYear.id.rawValue])
        #expect(overview.planned[0].plantName == "Radish")
        #expect(overview.planned[0].locationName == "Long Bed, Kitchen Garden")
        #expect(overview.inGround[0].plantName == "Tomato")
        #expect(overview.inGround[0].varietal == "Brandywine")
        #expect(overview.inGround[0].locationName == "Tunnel Bed, Polytunnel")
    }

    @Test func anEmptyGardenGroupsToEmptyLists() throws {
        let season = try SeasonFixture()
        let overview = try season.planner.overview(on: day(2026, 7, 1), calendar: calendar)
        #expect(overview.planned.isEmpty)
        #expect(overview.inGround.isEmpty)
        #expect(overview.finished.isEmpty)
    }
}

struct SeasonPlannerSplitStoreNameTests {
    @Test func namesResolveAcrossKnowledgeAndPersonalStores() throws {
        let knowledge = try CatalogFixture()
        let personal = try CatalogFixture()
        let carrot = Species(
            genusID: solanum.id,
            scientificName: "Daucus carota",
            commonNames: ["Carrot"]
        )
        let nantes = Cultivar(speciesID: carrot.id, name: "Nantes")
        try personal.species.insert(carrot)
        try personal.cultivars.insert(nantes)

        let planned = Planting(identity: .cultivar(nantes.id), bedID: longBed.id, status: .planned)
        let active = Planting(
            identity: .species(carrot.id), bedID: tunnelBed.id,
            plantedOn: day(2026, 5, 12), status: .active)
        let finished = Planting(
            identity: .species(tomato.id), bedID: longBed.id,
            plantedOn: day(2026, 4, 1), status: .finished, endedOn: day(2026, 6, 1))
        try personal.plantings.insert(planned)
        try personal.plantings.insert(active)
        try personal.plantings.insert(finished)

        let planner = SeasonPlanner(knowledge: knowledge.database, personal: personal.database)
        let overview = try planner.overview(on: day(2026, 7, 1), calendar: calendar)
        #expect(overview.planned.map(\.plantName) == ["Carrot"])
        #expect(overview.planned.map(\.varietal) == ["Nantes"])
        #expect(overview.inGround.map(\.plantName) == ["Carrot"])
        #expect(overview.finished.map(\.plantName) == ["Tomato"])
    }
}
