import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

struct HarvestAggregationTests {
    private func seeded() throws -> HarvestFixture {
        let fixture = try HarvestFixture()
        let tomato = fixture.tomatoPlanting
        let basil = fixture.basilPlanting
        let seeds = [
            fixture.harvest(of: tomato, quantity: 1.5, unit: .kilogram),
            fixture.harvest(of: tomato, quantity: 2.5, unit: .kilogram),
            fixture.harvest(of: tomato, quantity: 3, unit: .count),
            fixture.harvest(of: tomato, quantity: 2, unit: .custom, customUnit: "crate"),
            fixture.harvest(of: tomato, quantity: 1, unit: .custom, customUnit: "flat"),
            fixture.harvest(of: basil, quantity: 4, unit: .bunch),
            fixture.harvest(of: basil, quantity: 6, unit: .bunch),
            fixture.harvest(of: basil, quantity: 1, unit: .custom, customUnit: "crate"),
        ]
        for seed in seeds {
            try fixture.harvests.insert(seed)
        }
        return fixture
    }

    @Test func totalsPerPlantingGroupByUnitAndCustomLabel() throws {
        let fixture = try seeded()
        #expect(
            try fixture.harvests.totals(forPlanting: fixture.tomatoPlanting.id) == [
                HarvestTotal(unit: .count, customUnit: nil, total: 3, count: 1),
                HarvestTotal(unit: .custom, customUnit: "crate", total: 2, count: 1),
                HarvestTotal(unit: .custom, customUnit: "flat", total: 1, count: 1),
                HarvestTotal(unit: .kilogram, customUnit: nil, total: 4, count: 2),
            ])
    }

    @Test func totalsPerPlantingCoverOnlyThatPlanting() throws {
        let fixture = try seeded()
        #expect(
            try fixture.harvests.totals(forPlanting: fixture.basilPlanting.id) == [
                HarvestTotal(unit: .bunch, customUnit: nil, total: 10, count: 2),
                HarvestTotal(unit: .custom, customUnit: "crate", total: 1, count: 1),
            ])
    }

    @Test func totalsForACultivarIdentityJoinThroughPlanting() throws {
        let fixture = try seeded()
        let byIdentity = try fixture.harvests.totals(of: .cultivar(fixture.brandywine.id))
        let byPlanting = try fixture.harvests.totals(forPlanting: fixture.tomatoPlanting.id)
        #expect(byIdentity == byPlanting)
    }

    @Test func totalsForASpeciesIdentityJoinThroughPlanting() throws {
        let fixture = try seeded()
        #expect(
            try fixture.harvests.totals(of: .species(fixture.basil.id)) == [
                HarvestTotal(unit: .bunch, customUnit: nil, total: 10, count: 2),
                HarvestTotal(unit: .custom, customUnit: "crate", total: 1, count: 1),
            ])
    }

    @Test func aSpeciesIdentityIgnoresCultivarPlantings() throws {
        let fixture = try seeded()
        #expect(try fixture.harvests.totals(of: .species(fixture.tomato.id)).isEmpty)
    }

    @Test func anUnharvestedPlantingTotalsNothing() throws {
        let fixture = try HarvestFixture()
        #expect(try fixture.harvests.totals(forPlanting: fixture.tomatoPlanting.id).isEmpty)
    }

    @Test func totalsAcrossPlantingsOfTheSameIdentityAreCombined() throws {
        let fixture = try HarvestFixture()
        let second = Planting(identity: .species(fixture.basil.id), bedID: fixture.bed.id)
        try fixture.plantings.insert(second)
        try fixture.harvests.insert(
            fixture.harvest(of: fixture.basilPlanting, quantity: 2, unit: .bunch))
        try fixture.harvests.insert(fixture.harvest(of: second, quantity: 5, unit: .bunch))
        #expect(
            try fixture.harvests.totals(of: .species(fixture.basil.id)) == [
                HarvestTotal(unit: .bunch, customUnit: nil, total: 7, count: 2)
            ])
    }

    @Test func anUnknownStoredUnitFailsTheAggregation() throws {
        let fixture = try HarvestFixture()
        try fixture.insertUnchecked(id: "h1", unit: "stone", customUnit: nil)
        let expected = TaxonomyCodingError.unknownRawValue(
            table: "harvest", column: "unit", value: "stone")
        #expect(throws: expected) {
            try fixture.harvests.totals(forPlanting: fixture.tomatoPlanting.id)
        }
        #expect(throws: expected) {
            try fixture.harvests.totals(of: .cultivar(fixture.brandywine.id))
        }
    }
}
