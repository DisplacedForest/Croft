import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

private let nextSeasonDate = Date(timeIntervalSince1970: 1_755_000_000)

struct HarvestAggregationTests {
    private func seeded() throws -> HarvestFixture {
        let fixture = try HarvestFixture()
        let tomato = fixture.tomatoPlanting
        let basil = fixture.basilPlanting
        let seeds = [
            try fixture.harvest(of: tomato, yield: measured(500, .gram)),
            try fixture.harvest(of: tomato, yield: measured(1, .pound)),
            try fixture.harvest(of: tomato, yield: measured(3, .count)),
            try fixture.harvest(of: tomato, yield: .custom(amount: 2, label: "crate")),
            try fixture.harvest(of: tomato, yield: .custom(amount: 1, label: "flat")),
            try fixture.harvest(of: basil, yield: measured(2, .liter)),
            try fixture.harvest(of: basil, yield: measured(1, .quart)),
            try fixture.harvest(of: basil, yield: .custom(amount: 1, label: "crate")),
        ]
        for seed in seeds {
            try fixture.harvests.insert(seed)
        }
        return fixture
    }

    @Test func totalsPerPlantingSumMixedUnitsWithinAFamily() throws {
        let fixture = try seeded()
        #expect(
            try fixture.harvests.totals(forPlanting: fixture.tomatoPlanting.id) == [
                HarvestTotal(kind: .family(.count), total: 3, count: 1),
                HarvestTotal(
                    kind: .family(.mass), total: 500 + QuantityUnit.pound.canonicalFactor, count: 2),
                HarvestTotal(kind: .custom("crate"), total: 2, count: 1),
                HarvestTotal(kind: .custom("flat"), total: 1, count: 1),
            ])
    }

    @Test func totalsPerPlantingCoverOnlyThatPlanting() throws {
        let fixture = try seeded()
        #expect(
            try fixture.harvests.totals(forPlanting: fixture.basilPlanting.id) == [
                HarvestTotal(
                    kind: .family(.volume), total: 2000 + QuantityUnit.quart.canonicalFactor,
                    count: 2),
                HarvestTotal(kind: .custom("crate"), total: 1, count: 1),
            ])
    }

    @Test func totalsPerBedSpanEveryPlantingInTheBed() throws {
        let fixture = try seeded()
        #expect(
            try fixture.harvests.totals(forBed: fixture.bed.id) == [
                HarvestTotal(kind: .family(.count), total: 3, count: 1),
                HarvestTotal(
                    kind: .family(.mass), total: 500 + QuantityUnit.pound.canonicalFactor, count: 2),
                HarvestTotal(
                    kind: .family(.volume), total: 2000 + QuantityUnit.quart.canonicalFactor,
                    count: 2),
                HarvestTotal(kind: .custom("crate"), total: 3, count: 2),
                HarvestTotal(kind: .custom("flat"), total: 1, count: 1),
            ])
    }

    @Test func totalsPerCultivarJoinThroughPlanting() throws {
        let fixture = try seeded()
        #expect(
            try fixture.harvests.totals(of: .cultivar(fixture.brandywine.id)) == [
                HarvestTotal(kind: .family(.count), total: 3, count: 1),
                HarvestTotal(
                    kind: .family(.mass), total: 500 + QuantityUnit.pound.canonicalFactor, count: 2),
                HarvestTotal(kind: .custom("crate"), total: 2, count: 1),
                HarvestTotal(kind: .custom("flat"), total: 1, count: 1),
            ])
    }

    @Test func totalsPerSpeciesJoinThroughPlanting() throws {
        let fixture = try seeded()
        #expect(
            try fixture.harvests.totals(of: .species(fixture.basil.id)) == [
                HarvestTotal(
                    kind: .family(.volume), total: 2000 + QuantityUnit.quart.canonicalFactor,
                    count: 2),
                HarvestTotal(kind: .custom("crate"), total: 1, count: 1),
            ])
    }

    @Test func totalsPerSeasonSplitOnTheHarvestYear() throws {
        let fixture = try HarvestFixture()
        try fixture.harvests.insert(try fixture.harvest(yield: measured(500, .gram)))
        try fixture.harvests.insert(
            try fixture.harvest(on: nextSeasonDate, yield: measured(1, .pound)))
        #expect(
            try fixture.harvests.totals(inSeason: 2024) == [
                HarvestTotal(kind: .family(.mass), total: 500, count: 1)
            ])
        #expect(
            try fixture.harvests.totals(inSeason: 2025) == [
                HarvestTotal(kind: .family(.mass), total: 453.592_37, count: 1)
            ])
        #expect(try fixture.harvests.totals(inSeason: 2023).isEmpty)
    }

    @Test func customYieldsAreNeverConvertedIntoAFamily() throws {
        let fixture = try HarvestFixture()
        try fixture.harvests.insert(
            try fixture.harvest(yield: .custom(amount: 2, label: "gram")))
        #expect(
            try fixture.harvests.totals(forPlanting: fixture.tomatoPlanting.id) == [
                HarvestTotal(kind: .custom("gram"), total: 2, count: 1)
            ])
    }

    @Test func anUnharvestedScopeHasNoTotals() throws {
        let fixture = try seeded()
        let empty = Planting(identity: .species(fixture.basil.id), bedID: fixture.bed.id)
        try fixture.plantings.insert(empty)
        #expect(try fixture.harvests.totals(forPlanting: empty.id).isEmpty)
    }
}
