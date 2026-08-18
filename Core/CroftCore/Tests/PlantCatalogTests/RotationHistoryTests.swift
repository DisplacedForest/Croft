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

private let reference = day(2026, 6, 1)

private struct RotationFixture {
    let fixture: CatalogFixture
    let rotation: RotationHistory

    init() throws {
        fixture = try CatalogFixture()
        rotation = RotationHistory(fixture.database)
    }

    func plant(
        _ identity: PlantIdentity,
        in bed: Bed.ID,
        from plantedOn: Date,
        to endedOn: Date? = nil
    ) throws {
        let status: PlantingStatus = endedOn == nil ? .active : .finished
        try fixture.plantings.insert(
            Planting(
                identity: identity,
                bedID: bed,
                plantedOn: plantedOn,
                status: status,
                endedOn: endedOn
            ))
    }
}

struct RotationWarningTests {
    @Test func aPriorYearFamilyMatchWarnsWithTheYear() throws {
        let rotation = try RotationFixture()
        try rotation.plant(
            .species(tomato.id), in: longBed.id,
            from: day(2025, 5, 15), to: day(2025, 9, 20))
        let warning = try rotation.rotation.warning(
            for: .cultivar(brandywine.id), inBed: longBed.id,
            on: reference, calendar: calendar)
        #expect(warning == RotationWarning(familyName: "Solanaceae", year: 2025))
    }

    @Test func aDifferentFamilyStaysQuiet() throws {
        let rotation = try RotationFixture()
        try rotation.plant(
            .species(tomato.id), in: longBed.id,
            from: day(2025, 5, 15), to: day(2025, 9, 20))
        let warning = try rotation.rotation.warning(
            for: .species(basil.id), inBed: longBed.id,
            on: reference, calendar: calendar)
        #expect(warning == nil)
    }

    @Test func aSameYearReplantDoesNotWarn() throws {
        let rotation = try RotationFixture()
        try rotation.plant(
            .species(tomato.id), in: longBed.id,
            from: day(2026, 4, 1), to: day(2026, 5, 20))
        let warning = try rotation.rotation.warning(
            for: .species(tomato.id), inBed: longBed.id,
            on: reference, calendar: calendar)
        #expect(warning == nil)
    }

    @Test func anOpenEndedPlantingFromLastYearWarnsUnderLastYear() throws {
        let rotation = try RotationFixture()
        try rotation.plant(
            .species(tomato.id), in: longBed.id, from: day(2025, 5, 15))
        let warning = try rotation.rotation.warning(
            for: .species(tomato.id), inBed: longBed.id,
            on: reference, calendar: calendar)
        #expect(warning == RotationWarning(familyName: "Solanaceae", year: 2025))
    }

    @Test func historyOlderThanTheLookbackIsForgotten() throws {
        let rotation = try RotationFixture()
        try rotation.plant(
            .species(tomato.id), in: longBed.id,
            from: day(2022, 5, 15), to: day(2022, 9, 20))
        let warning = try rotation.rotation.warning(
            for: .species(tomato.id), inBed: longBed.id,
            on: reference, calendar: calendar)
        #expect(warning == nil)
    }

    @Test func theLookbackBoundaryYearStillWarns() throws {
        let rotation = try RotationFixture()
        try rotation.plant(
            .species(tomato.id), in: longBed.id,
            from: day(2023, 5, 15), to: day(2023, 9, 20))
        let warning = try rotation.rotation.warning(
            for: .species(tomato.id), inBed: longBed.id,
            on: reference, calendar: calendar)
        #expect(warning == RotationWarning(familyName: "Solanaceae", year: 2023))
    }

    @Test func undatedPlantingsAreIgnored() throws {
        let rotation = try RotationFixture()
        try rotation.fixture.plantings.insert(
            Planting(identity: .species(tomato.id), bedID: longBed.id, status: .planned))
        let warning = try rotation.rotation.warning(
            for: .species(tomato.id), inBed: longBed.id,
            on: reference, calendar: calendar)
        #expect(warning == nil)
    }

    @Test func aDifferentBedDoesNotLeak() throws {
        let rotation = try RotationFixture()
        try rotation.plant(
            .species(tomato.id), in: tunnelBed.id,
            from: day(2025, 5, 15), to: day(2025, 9, 20))
        let warning = try rotation.rotation.warning(
            for: .species(tomato.id), inBed: longBed.id,
            on: reference, calendar: calendar)
        #expect(warning == nil)
    }
}

struct RotationHistoryLineTests {
    @Test func multiplePriorFamiliesReportTheirMostRecentYears() throws {
        let rotation = try RotationFixture()
        try rotation.plant(
            .species(tomato.id), in: longBed.id,
            from: day(2024, 5, 1), to: day(2024, 9, 1))
        try rotation.plant(
            .species(tomato.id), in: longBed.id,
            from: day(2025, 5, 1), to: day(2025, 9, 1))
        try rotation.plant(
            .species(basil.id), in: longBed.id,
            from: day(2024, 6, 1), to: day(2024, 8, 1))
        let lines = try rotation.rotation.historyLines(
            inBed: longBed.id, on: reference, calendar: calendar)
        #expect(
            lines == [
                FamilyOccupancy(familyName: "Solanaceae", mostRecentYear: 2025),
                FamilyOccupancy(familyName: "Lamiaceae", mostRecentYear: 2024),
            ])
    }

    @Test func historyLinesCapAtThreeFamilies() throws {
        let rotation = try RotationFixture()
        let extraFamilies = ["Brassicaceae", "Fabaceae", "Apiaceae"]
        for (index, name) in extraFamilies.enumerated() {
            let family = PlantFamily(name: name)
            let genus = Genus(familyID: family.id, name: "Genus\(index)")
            let species = Species(genusID: genus.id, scientificName: "Species \(index)")
            try rotation.fixture.families.insert(family)
            try rotation.fixture.genera.insert(genus)
            try rotation.fixture.species.insert(species)
            try rotation.plant(
                .species(species.id), in: longBed.id,
                from: day(2023 + index, 5, 1), to: day(2023 + index, 9, 1))
        }
        try rotation.plant(
            .species(tomato.id), in: longBed.id,
            from: day(2025, 6, 1), to: day(2025, 10, 1))
        let lines = try rotation.rotation.historyLines(
            inBed: longBed.id, on: reference, calendar: calendar)
        #expect(lines.count == 3)
        #expect(lines.map(\.mostRecentYear) == [2025, 2025, 2024])
    }

    @Test func anEmptyBedHasNoLines() throws {
        let rotation = try RotationFixture()
        let lines = try rotation.rotation.historyLines(
            inBed: longBed.id, on: reference, calendar: calendar)
        #expect(lines.isEmpty)
    }
}
