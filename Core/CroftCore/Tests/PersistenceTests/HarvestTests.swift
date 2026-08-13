import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

struct HarvestStorageTests {
    @Test func everyAttributeRoundTrips() throws {
        let fixture = try HarvestFixture()
        let harvest = Harvest(
            plantingID: fixture.tomatoPlanting.id,
            harvestedOn: harvestedDate,
            quantity: 3.25,
            unit: .custom,
            customUnit: "half flat",
            quality: .excellent,
            notes: "first picking of the season"
        )
        try fixture.harvests.insert(harvest)
        #expect(try fixture.harvests.fetch(id: harvest.id) == harvest)
    }

    @Test func aMinimalHarvestRoundTrips() throws {
        let fixture = try HarvestFixture()
        let harvest = fixture.harvest()
        try fixture.harvests.insert(harvest)
        let fetched = try #require(try fixture.harvests.fetch(id: harvest.id))
        #expect(fetched == harvest)
        #expect(fetched.customUnit == nil)
        #expect(fetched.quality == nil)
        #expect(fetched.notes == nil)
    }

    @Test(arguments: HarvestUnit.allCases)
    func everyUnitRoundTrips(unit: HarvestUnit) throws {
        let fixture = try HarvestFixture()
        let harvest = fixture.harvest(
            unit: unit, customUnit: unit == .custom ? "crate" : nil)
        try fixture.harvests.insert(harvest)
        let fetched = try #require(try fixture.harvests.fetch(id: harvest.id))
        #expect(fetched.unit == unit)
        #expect(fetched.customUnit == harvest.customUnit)
    }

    @Test(arguments: HarvestQuality.allCases)
    func everyQualityRoundTrips(quality: HarvestQuality) throws {
        let fixture = try HarvestFixture()
        var harvest = fixture.harvest()
        harvest.quality = quality
        try fixture.harvests.insert(harvest)
        #expect(try fixture.harvests.fetch(id: harvest.id)?.quality == quality)
    }

    @Test func unitRawValuesMatchTheDatabaseCheck() throws {
        #expect(
            HarvestUnit.allCases.map(\.rawValue) == [
                "gram", "kilogram", "ounce", "pound", "count", "bunch", "custom",
            ])
        #expect(
            HarvestQuality.allCases.map(\.rawValue) == [
                "excellent", "good", "fair", "poor",
            ])
    }

    @Test func absentOptionalsAreStoredAsNull() throws {
        let fixture = try HarvestFixture()
        let harvest = fixture.harvest()
        try fixture.harvests.insert(harvest)
        let stored = try #require(try fixture.harvestRow(harvest.id.rawValue))
        for column in ["custom_unit", "quality", "notes"] {
            #expect(stored[column] == DatabaseValue.null)
        }
    }

    @Test func updateReplacesStoredAttributes() throws {
        let fixture = try HarvestFixture()
        var harvest = fixture.harvest()
        harvest.notes = "light picking"
        try fixture.harvests.insert(harvest)
        harvest.notes = nil
        harvest.quantity = 9
        harvest.unit = .custom
        harvest.customUnit = "bushel"
        harvest.quality = .fair
        harvest.harvestedOn = laterHarvestedDate
        try fixture.harvests.update(harvest)
        #expect(try fixture.harvests.fetch(id: harvest.id) == harvest)
    }

    @Test func updatingAMissingHarvestThrows() throws {
        let fixture = try HarvestFixture()
        let ghost = fixture.harvest()
        #expect(throws: HarvestError.harvestNotFound(ghost.id.rawValue)) {
            try fixture.harvests.update(ghost)
        }
    }

    @Test func deleteRemovesTheRow() throws {
        let fixture = try HarvestFixture()
        let harvest = fixture.harvest()
        try fixture.harvests.insert(harvest)
        #expect(try fixture.harvests.delete(id: harvest.id))
        #expect(try fixture.harvests.fetch(id: harvest.id) == nil)
    }

    @Test func deletingAMissingHarvestReportsNoChange() throws {
        let fixture = try HarvestFixture()
        #expect(try fixture.harvests.delete(id: Harvest.ID(rawValue: "missing")) == false)
    }
}

struct HarvestConstraintTests {
    @Test func aHarvestWithoutItsPlantingIsRejected() throws {
        let fixture = try HarvestFixture()
        let orphan = Harvest(
            plantingID: Planting.ID(rawValue: "missing"),
            harvestedOn: harvestedDate,
            quantity: 1,
            unit: .gram
        )
        #expect(throws: DatabaseError.self) {
            try fixture.harvests.insert(orphan)
        }
        #expect(try fixture.harvests.fetchAll().isEmpty)
    }

    @Test func aPlantingWithHarvestsCannotBeDeleted() throws {
        let fixture = try HarvestFixture()
        try fixture.harvests.insert(fixture.harvest())
        #expect(throws: DatabaseError.self) {
            try fixture.plantings.delete(id: fixture.tomatoPlanting.id)
        }
        #expect(try fixture.plantings.fetch(id: fixture.tomatoPlanting.id) != nil)
    }

    @Test func aPlantingIsDeletableOnceItsHarvestsAreGone() throws {
        let fixture = try HarvestFixture()
        let harvest = fixture.harvest()
        try fixture.harvests.insert(harvest)
        try fixture.harvests.delete(id: harvest.id)
        #expect(try fixture.plantings.delete(id: fixture.tomatoPlanting.id))
        #expect(try fixture.plantings.fetch(id: fixture.tomatoPlanting.id) == nil)
    }

    @Test func aNonPositiveQuantityIsRejectedByTheDatabase() throws {
        let fixture = try HarvestFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.harvests.insert(fixture.harvest(quantity: 0))
        }
    }

    @Test func aCustomUnitWithoutALabelIsRejectedByTheDatabase() throws {
        let fixture = try HarvestFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.harvests.insert(fixture.harvest(unit: .custom))
        }
    }

    @Test func aNamedUnitWithACustomLabelIsRejectedByTheDatabase() throws {
        let fixture = try HarvestFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.harvests.insert(fixture.harvest(unit: .gram, customUnit: "crate"))
        }
    }

    @Test func aCorruptedCustomUnitPairingFailsToDecode() throws {
        let fixture = try HarvestFixture()
        try fixture.insertUnchecked(id: "h1", unit: "custom", customUnit: nil)
        #expect(throws: HarvestError.malformedUnit("h1")) {
            try fixture.harvests.fetch(id: Harvest.ID(rawValue: "h1"))
        }
    }

    @Test func aStrayCustomLabelFailsToDecode() throws {
        let fixture = try HarvestFixture()
        try fixture.insertUnchecked(id: "h2", unit: "gram", customUnit: "crate")
        #expect(throws: HarvestError.malformedUnit("h2")) {
            try fixture.harvests.fetch(id: Harvest.ID(rawValue: "h2"))
        }
    }

    @Test func anUnknownUnitFailsToDecode() throws {
        let fixture = try HarvestFixture()
        try fixture.insertUnchecked(id: "h3", unit: "stone", customUnit: nil)
        let expected = TaxonomyCodingError.unknownRawValue(
            table: "harvest", column: "unit", value: "stone")
        #expect(throws: expected) {
            try fixture.harvests.fetch(id: Harvest.ID(rawValue: "h3"))
        }
    }

    @Test func aCorruptedCustomUnitPairingFailsAggregation() throws {
        let fixture = try HarvestFixture()
        try fixture.insertUnchecked(id: "h4", unit: "custom", customUnit: nil)
        #expect(throws: HarvestError.malformedUnit("h4")) {
            try fixture.harvests.totals(forPlanting: fixture.tomatoPlanting.id)
        }
        #expect(throws: HarvestError.malformedUnit("h4")) {
            try fixture.harvests.totals(of: .cultivar(fixture.brandywine.id))
        }
    }
}

struct HarvestQueryTests {
    @Test func fetchAllPutsTheNewestHarvestFirst() throws {
        let fixture = try HarvestFixture()
        var older = fixture.harvest()
        older.notes = "older"
        var newer = fixture.harvest(on: laterHarvestedDate)
        newer.notes = "newer"
        try fixture.harvests.insert(older)
        try fixture.harvests.insert(newer)
        #expect(try fixture.harvests.fetchAll().map(\.notes) == ["newer", "older"])
    }

    @Test func harvestsAreListedPerPlanting() throws {
        let fixture = try HarvestFixture()
        let tomato = fixture.harvest()
        let basil = fixture.harvest(of: fixture.basilPlanting, unit: .bunch)
        try fixture.harvests.insert(tomato)
        try fixture.harvests.insert(basil)
        #expect(
            try fixture.harvests.harvests(forPlanting: fixture.tomatoPlanting.id).map(\.id)
                == [tomato.id])
        #expect(
            try fixture.harvests.harvests(forPlanting: fixture.basilPlanting.id).map(\.id)
                == [basil.id])
    }

    @Test func harvestsPerPlantingPutTheNewestFirst() throws {
        let fixture = try HarvestFixture()
        var older = fixture.harvest()
        older.notes = "older"
        var newer = fixture.harvest(on: latestHarvestedDate)
        newer.notes = "newer"
        try fixture.harvests.insert(older)
        try fixture.harvests.insert(newer)
        let listed = try fixture.harvests.harvests(forPlanting: fixture.tomatoPlanting.id)
        #expect(listed.map(\.notes) == ["newer", "older"])
    }

    @Test func anUnharvestedPlantingListsNothing() throws {
        let fixture = try HarvestFixture()
        try fixture.harvests.insert(fixture.harvest())
        #expect(try fixture.harvests.harvests(forPlanting: fixture.basilPlanting.id).isEmpty)
    }

    @Test func recentReturnsTheNewestHarvestsOnly() throws {
        let fixture = try HarvestFixture()
        var oldest = fixture.harvest()
        oldest.notes = "oldest"
        var middle = fixture.harvest(on: laterHarvestedDate)
        middle.notes = "middle"
        var newest = fixture.harvest(on: latestHarvestedDate)
        newest.notes = "newest"
        for harvest in [oldest, middle, newest] {
            try fixture.harvests.insert(harvest)
        }
        #expect(try fixture.harvests.recent(limit: 2).map(\.notes) == ["newest", "middle"])
    }
}
