import Domain
import Foundation
import Testing

private let calendar = PlantingWindows.utcCalendar

private func day(_ year: Int, _ month: Int, _ dayOfMonth: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = dayOfMonth
    return calendar.date(from: components)!
}

private func monthDay(_ month: Int, _ dayOfMonth: Int) -> MonthDay {
    MonthDay(month: month, day: dayOfMonth)!
}

private let northern = FrostAnchors(
    lastFrost: monthDay(5, 10), firstFrost: monthDay(9, 28))
private let northernNoFall = FrostAnchors(lastFrost: monthDay(5, 10), firstFrost: nil)
private let southern = FrostAnchors(
    lastFrost: monthDay(9, 20), firstFrost: monthDay(5, 10), southernHemisphere: true)

private func assess(
    _ profile: PlantingWindowProfile,
    anchors: FrostAnchors,
    on reference: Date
) -> PlantingWindowAssessment {
    PlantingWindows.assess(profile, anchors: anchors, on: reference)
}

struct DirectSowMatrixTests {
    @Test func hardyOpensFourWeeksBeforeLastFrost() throws {
        let profile = PlantingWindowProfile(sowingMethod: .direct, frostTolerance: .hardy)
        let result = assess(profile, anchors: northernNoFall, on: day(2026, 4, 20))
        guard case .act(let opportunity) = result else {
            Issue.record("expected act, got \(result)")
            return
        }
        #expect(opportunity.action == .directSow)
        #expect(opportunity.window.lowerBound == day(2026, 4, 12))
        #expect(opportunity.window.upperBound == day(2026, 6, 7))
    }

    @Test func tenderWaitsForLastFrost() throws {
        let profile = PlantingWindowProfile(sowingMethod: .direct, frostTolerance: .tender)
        let result = assess(profile, anchors: northernNoFall, on: day(2026, 4, 20))
        guard case .upcoming(let opportunity) = result else {
            Issue.record("expected upcoming, got \(result)")
            return
        }
        #expect(opportunity.action == .directSow)
        #expect(opportunity.window.lowerBound == day(2026, 5, 10))
    }

    @Test func halfHardyOpensTwoWeeksBefore() throws {
        let profile = PlantingWindowProfile(sowingMethod: .direct, frostTolerance: .halfHardy)
        let result = assess(profile, anchors: northernNoFall, on: day(2026, 4, 20))
        guard case .upcoming(let opportunity) = result else {
            Issue.record("expected upcoming, got \(result)")
            return
        }
        #expect(opportunity.window.lowerBound == day(2026, 4, 26))
    }

    @Test func maturityClosesTheWindowBeforeFirstFrost() throws {
        let profile = PlantingWindowProfile(
            sowingMethod: .direct,
            frostTolerance: .tender,
            daysToMaturity: 90...120,
            daysToMaturityBasis: .fromDirectSow
        )
        let open = assess(profile, anchors: northern, on: day(2026, 5, 20))
        guard case .act(let opportunity) = open else {
            Issue.record("expected act, got \(open)")
            return
        }
        #expect(opportunity.window.upperBound == day(2026, 5, 31))

        let closed = assess(profile, anchors: northern, on: day(2026, 6, 5))
        guard case .upcoming(let next) = closed else {
            Issue.record("expected upcoming, got \(closed)")
            return
        }
        #expect(next.window.lowerBound == day(2027, 5, 10))
    }

    @Test func transplantBasisLeavesTheDirectWindowAlone() throws {
        let profile = PlantingWindowProfile(
            sowingMethod: .direct,
            frostTolerance: .tender,
            daysToMaturity: 90...120,
            daysToMaturityBasis: .fromTransplant
        )
        let result = assess(profile, anchors: northern, on: day(2026, 6, 5))
        guard case .act(let opportunity) = result else {
            Issue.record("expected act, got \(result)")
            return
        }
        #expect(opportunity.window.upperBound == day(2026, 9, 28))
    }

    @Test func missingFirstFrostFallsBackToTheDefaultRun() throws {
        let profile = PlantingWindowProfile(sowingMethod: .direct, frostTolerance: .tender)
        let result = assess(profile, anchors: northernNoFall, on: day(2026, 6, 1))
        guard case .act(let opportunity) = result else {
            Issue.record("expected act, got \(result)")
            return
        }
        #expect(opportunity.window.upperBound == day(2026, 7, 5))
    }

    @Test func aSeasonTooShortToMatureYieldsNoWindow() throws {
        let profile = PlantingWindowProfile(
            sowingMethod: .direct,
            frostTolerance: .tender,
            daysToMaturity: 200...300,
            daysToMaturityBasis: .fromDirectSow
        )
        let result = assess(profile, anchors: northern, on: day(2026, 5, 20))
        #expect(result == .notApplicable)
    }
}

struct TransplantMatrixTests {
    private let tomato = PlantingWindowProfile(
        sowingMethod: .both,
        frostTolerance: .tender,
        weeksIndoorsBeforeTransplant: 6...8
    )

    @Test func indoorWindowCountsBackFromTheSafeDate() throws {
        let result = assess(tomato, anchors: northern, on: day(2026, 3, 20))
        guard case .act(let opportunity) = result else {
            Issue.record("expected act, got \(result)")
            return
        }
        #expect(opportunity.action == .sowIndoors)
        #expect(opportunity.window.lowerBound == day(2026, 3, 15))
        #expect(opportunity.window.upperBound == day(2026, 3, 29))
    }

    @Test func transplantOutWinsWhileItsShorterWindowIsOpen() throws {
        let result = assess(tomato, anchors: northern, on: day(2026, 5, 15))
        guard case .act(let opportunity) = result else {
            Issue.record("expected act, got \(result)")
            return
        }
        #expect(opportunity.action == .transplantOut)
        #expect(opportunity.window.lowerBound == day(2026, 5, 10))
        #expect(opportunity.window.upperBound == day(2026, 5, 31))
    }

    @Test func hardyTransplantsGoOutEarly() throws {
        let profile = PlantingWindowProfile(
            sowingMethod: .transplant,
            frostTolerance: .hardy,
            weeksIndoorsBeforeTransplant: 4...6
        )
        let result = assess(profile, anchors: northern, on: day(2026, 4, 15))
        guard case .act(let opportunity) = result else {
            Issue.record("expected act, got \(result)")
            return
        }
        #expect(opportunity.action == .transplantOut)
        #expect(opportunity.window.lowerBound == day(2026, 4, 12))
    }

    @Test func offSeasonRollsToNextYear() throws {
        let result = assess(tomato, anchors: northern, on: day(2026, 12, 1))
        guard case .upcoming(let opportunity) = result else {
            Issue.record("expected upcoming, got \(result)")
            return
        }
        #expect(opportunity.action == .sowIndoors)
        #expect(opportunity.window.lowerBound == day(2027, 3, 15))
    }
}

struct HemisphereMatrixTests {
    private let profile = PlantingWindowProfile(sowingMethod: .direct, frostTolerance: .hardy)

    @Test func southernWindowOpensLateInTheCalendarYear() throws {
        let result = assess(profile, anchors: southern, on: day(2026, 10, 1))
        guard case .act(let opportunity) = result else {
            Issue.record("expected act, got \(result)")
            return
        }
        #expect(opportunity.window.lowerBound == day(2026, 8, 23))
        #expect(opportunity.window.upperBound == day(2027, 5, 10))
    }

    @Test func southernWinterIsUpcomingNotOpen() throws {
        let result = assess(profile, anchors: southern, on: day(2026, 8, 1))
        guard case .upcoming(let opportunity) = result else {
            Issue.record("expected upcoming, got \(result)")
            return
        }
        #expect(opportunity.window.lowerBound == day(2026, 8, 23))
    }
}

struct MissingFieldMatrixTests {
    @Test func everythingMissingNamesEverythingNeeded() throws {
        let result = assess(
            PlantingWindowProfile(),
            anchors: FrostAnchors(lastFrost: nil, firstFrost: nil),
            on: day(2026, 4, 1)
        )
        #expect(result == .cannotAssess([.lastFrost, .sowingMethod, .frostTolerance]))
    }

    @Test func transplantCropMissingWeeksNamesJustThat() throws {
        let profile = PlantingWindowProfile(sowingMethod: .transplant, frostTolerance: .tender)
        let result = assess(profile, anchors: northern, on: day(2026, 4, 1))
        #expect(result == .cannotAssess([.weeksIndoorsBeforeTransplant]))
    }

    @Test func directCropNeverNeedsWeeksIndoors() throws {
        let profile = PlantingWindowProfile(sowingMethod: .direct, frostTolerance: nil)
        let result = assess(profile, anchors: northern, on: day(2026, 4, 1))
        #expect(result == .cannotAssess([.frostTolerance]))
    }

    @Test func missingFrostDatesAloneAreNamed() throws {
        let profile = PlantingWindowProfile(sowingMethod: .direct, frostTolerance: .hardy)
        let result = assess(
            profile,
            anchors: FrostAnchors(lastFrost: nil, firstFrost: nil),
            on: day(2026, 4, 1)
        )
        #expect(result == .cannotAssess([.lastFrost]))
    }

    @Test func enhancingFieldsNeverBlockAssessment() throws {
        let profile = PlantingWindowProfile(sowingMethod: .direct, frostTolerance: .hardy)
        let result = assess(profile, anchors: northernNoFall, on: day(2026, 4, 20))
        guard case .act = result else {
            Issue.record("expected act, got \(result)")
            return
        }
    }

    @Test func plantingStockIsNotApplicableEvenWithGaps() throws {
        let profile = PlantingWindowProfile(sowingMethod: .plantingStock)
        let result = assess(
            profile,
            anchors: FrostAnchors(lastFrost: nil, firstFrost: nil),
            on: day(2026, 4, 1)
        )
        #expect(result == .notApplicable)
    }
}

struct CalculatorInputTests {
    @Test func cultivarMaturityOverridesTheSpecies() throws {
        var species = Species(
            id: Species.ID(rawValue: "sp"), genusID: Genus.ID(rawValue: "g"),
            scientificName: "Solanum lycopersicum")
        species.daysToMaturity = 90...120
        species.sowingMethod = .both
        var cultivar = Cultivar(
            id: Cultivar.ID(rawValue: "cv"), speciesID: species.id, name: "Cherry")
        cultivar.daysToMaturity = 60...70

        let merged = PlantingWindowProfile(species: species, cultivar: cultivar)
        #expect(merged.daysToMaturity == 60...70)

        let speciesOnly = PlantingWindowProfile(species: species)
        #expect(speciesOnly.daysToMaturity == 90...120)
    }

    @Test func leapDayAnchorsClampInCommonYears() throws {
        let anchors = FrostAnchors(lastFrost: monthDay(2, 29), firstFrost: nil)
        let profile = PlantingWindowProfile(sowingMethod: .direct, frostTolerance: .hardy)
        let result = assess(profile, anchors: anchors, on: day(2026, 2, 20))
        guard case .act(let opportunity) = result else {
            Issue.record("expected act, got \(result)")
            return
        }
        #expect(opportunity.action == .directSow)
    }

    @Test func anchorsDeriveHemisphereFromLatitude() throws {
        var property = Property(name: "Home")
        property.location = GeoCoordinate(latitude: -36.8, longitude: 174.7)
        #expect(FrostAnchors(property: property).southernHemisphere)
        property.location = GeoCoordinate(latitude: 44.5, longitude: -72.8)
        #expect(!FrostAnchors(property: property).southernHemisphere)
        property.location = nil
        #expect(!FrostAnchors(property: property).southernHemisphere)
    }
}
