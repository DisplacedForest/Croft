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
            yield: .custom(amount: 3.25, label: "half flat"),
            harvestedPart: .fruit,
            quality: .excellent,
            notes: "first picking of the season"
        )
        try fixture.harvests.insert(harvest)
        #expect(try fixture.harvests.fetch(id: harvest.id) == harvest)
    }

    @Test func aMinimalHarvestRoundTrips() throws {
        let fixture = try HarvestFixture()
        let harvest = try fixture.harvest()
        try fixture.harvests.insert(harvest)
        let fetched = try #require(try fixture.harvests.fetch(id: harvest.id))
        #expect(fetched == harvest)
        #expect(fetched.harvestedPart == nil)
        #expect(fetched.quality == nil)
        #expect(fetched.notes == nil)
    }

    @Test(arguments: QuantityUnit.allCases)
    func everyMeasuredUnitRoundTrips(unit: QuantityUnit) throws {
        let fixture = try HarvestFixture()
        let harvest = try fixture.harvest(yield: measured(3, unit))
        try fixture.harvests.insert(harvest)
        let fetched = try #require(try fixture.harvests.fetch(id: harvest.id))
        #expect(fetched.yield == harvest.yield)
    }

    @Test func aMeasuredYieldStoresCanonicalAmountAndEnteredUnit() throws {
        let fixture = try HarvestFixture()
        let harvest = try fixture.harvest(yield: measured(2, .pound))
        try fixture.harvests.insert(harvest)
        let stored = try #require(try fixture.harvestRow(harvest.id.rawValue))
        #expect(stored["yield_amount"] == 907.184_74)
        #expect(stored["yield_unit"] == "pound")
        #expect(stored["yield_family"] == "mass")
        #expect(stored["custom_unit"] == DatabaseValue.null)
    }

    @Test(arguments: HarvestablePart.allCases)
    func everyHarvestedPartRoundTrips(part: HarvestablePart) throws {
        let fixture = try HarvestFixture()
        let harvest = try fixture.harvest(part: part)
        try fixture.harvests.insert(harvest)
        #expect(try fixture.harvests.fetch(id: harvest.id)?.harvestedPart == part)
    }

    @Test(arguments: HarvestQuality.allCases)
    func everyQualityRoundTrips(quality: HarvestQuality) throws {
        let fixture = try HarvestFixture()
        var harvest = try fixture.harvest()
        harvest.quality = quality
        try fixture.harvests.insert(harvest)
        #expect(try fixture.harvests.fetch(id: harvest.id)?.quality == quality)
    }

    @Test func absentOptionalsAreStoredAsNull() throws {
        let fixture = try HarvestFixture()
        let harvest = try fixture.harvest()
        try fixture.harvests.insert(harvest)
        let stored = try #require(try fixture.harvestRow(harvest.id.rawValue))
        for column in ["custom_unit", "harvested_part", "quality", "notes"] {
            #expect(stored[column] == DatabaseValue.null)
        }
    }

    @Test func updateReplacesStoredAttributes() throws {
        let fixture = try HarvestFixture()
        var harvest = try fixture.harvest()
        harvest.notes = "light picking"
        try fixture.harvests.insert(harvest)
        harvest.notes = nil
        harvest.yield = .custom(amount: 9, label: "bushel")
        harvest.harvestedPart = .fruit
        harvest.quality = .fair
        harvest.harvestedOn = laterHarvestedDate
        try fixture.harvests.update(harvest)
        #expect(try fixture.harvests.fetch(id: harvest.id) == harvest)
    }

    @Test func updatingAMissingHarvestThrows() throws {
        let fixture = try HarvestFixture()
        let ghost = try fixture.harvest()
        #expect(throws: HarvestError.harvestNotFound(ghost.id.rawValue)) {
            try fixture.harvests.update(ghost)
        }
    }

    @Test func deleteRemovesTheRow() throws {
        let fixture = try HarvestFixture()
        let harvest = try fixture.harvest()
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
            yield: try measured(1, .gram)
        )
        #expect(throws: DatabaseError.self) {
            try fixture.harvests.insert(orphan)
        }
        #expect(try fixture.harvests.fetchAll().isEmpty)
    }

    @Test func aPlantingWithHarvestsCannotBeDeleted() throws {
        let fixture = try HarvestFixture()
        try fixture.harvests.insert(try fixture.harvest())
        #expect(throws: DatabaseError.self) {
            try fixture.plantings.delete(id: fixture.tomatoPlanting.id)
        }
        #expect(try fixture.plantings.fetch(id: fixture.tomatoPlanting.id) != nil)
    }

    @Test func aPlantingIsDeletableOnceItsHarvestsAreGone() throws {
        let fixture = try HarvestFixture()
        let harvest = try fixture.harvest()
        try fixture.harvests.insert(harvest)
        try fixture.harvests.delete(id: harvest.id)
        #expect(try fixture.plantings.delete(id: fixture.tomatoPlanting.id))
        #expect(try fixture.plantings.fetch(id: fixture.tomatoPlanting.id) == nil)
    }

    @Test func aNonPositiveYieldIsRejectedByTheDatabase() throws {
        let fixture = try HarvestFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.harvests.insert(try fixture.harvest(yield: measured(0, .gram)))
        }
    }

    @Test func anUnknownStoredUnitIsRejectedByTheDatabase() throws {
        let fixture = try HarvestFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO harvest
                            (id, planting_id, harvested_on, yield_amount, yield_unit,
                             yield_family, custom_unit)
                        VALUES ('bad', ?, '2024-07-03 12:00:00', 2.0, 'stone', 'mass', NULL)
                        """,
                    arguments: [fixture.tomatoPlanting.id.rawValue]
                )
            }
        }
    }

    @Test func aCustomYieldWithoutItsLabelIsRejectedByTheDatabase() throws {
        let fixture = try HarvestFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO harvest
                            (id, planting_id, harvested_on, yield_amount, yield_unit,
                             yield_family, custom_unit)
                        VALUES ('bad', ?, '2024-07-03 12:00:00', 2.0, 'custom', NULL, NULL)
                        """,
                    arguments: [fixture.tomatoPlanting.id.rawValue]
                )
            }
        }
    }

    @Test func aMeasuredYieldWithACustomLabelIsRejectedByTheDatabase() throws {
        let fixture = try HarvestFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO harvest
                            (id, planting_id, harvested_on, yield_amount, yield_unit,
                             yield_family, custom_unit)
                        VALUES ('bad', ?, '2024-07-03 12:00:00', 2.0, 'gram', 'mass', 'crate')
                        """,
                    arguments: [fixture.tomatoPlanting.id.rawValue]
                )
            }
        }
    }

    @Test func aCustomRowMissingItsLabelFailsToDecode() throws {
        let fixture = try HarvestFixture()
        try fixture.insertUnchecked(id: "h1", unit: "custom", family: nil, customUnit: nil)
        #expect(throws: HarvestError.malformedUnit("h1")) {
            try fixture.harvests.fetch(id: Harvest.ID(rawValue: "h1"))
        }
    }

    @Test func aMeasuredRowWithAStrayLabelFailsToDecode() throws {
        let fixture = try HarvestFixture()
        try fixture.insertUnchecked(id: "h2", unit: "gram", family: "mass", customUnit: "crate")
        #expect(throws: HarvestError.malformedUnit("h2")) {
            try fixture.harvests.fetch(id: Harvest.ID(rawValue: "h2"))
        }
    }

    @Test func aMeasuredRowWithTheWrongFamilyFailsToDecode() throws {
        let fixture = try HarvestFixture()
        try fixture.insertUnchecked(id: "h3", unit: "gram", family: "volume", customUnit: nil)
        #expect(throws: HarvestError.malformedUnit("h3")) {
            try fixture.harvests.fetch(id: Harvest.ID(rawValue: "h3"))
        }
    }

    @Test func anUnknownUnitFailsToDecode() throws {
        let fixture = try HarvestFixture()
        try fixture.insertUnchecked(id: "h4", unit: "stone", family: "mass", customUnit: nil)
        #expect(throws: HarvestError.malformedUnit("h4")) {
            try fixture.harvests.fetch(id: Harvest.ID(rawValue: "h4"))
        }
    }

    @Test func aCorruptedFamilyFailsAggregation() throws {
        let fixture = try HarvestFixture()
        try fixture.insertUnchecked(id: "h5", unit: "gram", family: nil, customUnit: nil)
        #expect(throws: HarvestError.malformedUnit("h5")) {
            try fixture.harvests.totals(forPlanting: fixture.tomatoPlanting.id)
        }
        #expect(throws: HarvestError.malformedUnit("h5")) {
            try fixture.harvests.totals(of: .cultivar(fixture.brandywine.id))
        }
    }
}

struct HarvestQueryTests {
    @Test func fetchAllPutsTheNewestHarvestFirst() throws {
        let fixture = try HarvestFixture()
        var older = try fixture.harvest()
        older.notes = "older"
        var newer = try fixture.harvest(on: laterHarvestedDate)
        newer.notes = "newer"
        try fixture.harvests.insert(older)
        try fixture.harvests.insert(newer)
        #expect(try fixture.harvests.fetchAll().map(\.notes) == ["newer", "older"])
    }

    @Test func harvestsAreListedPerPlanting() throws {
        let fixture = try HarvestFixture()
        let tomato = try fixture.harvest()
        let basil = try fixture.harvest(of: fixture.basilPlanting, yield: measured(2, .count))
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
        var older = try fixture.harvest()
        older.notes = "older"
        var newer = try fixture.harvest(on: latestHarvestedDate)
        newer.notes = "newer"
        try fixture.harvests.insert(older)
        try fixture.harvests.insert(newer)
        let listed = try fixture.harvests.harvests(forPlanting: fixture.tomatoPlanting.id)
        #expect(listed.map(\.notes) == ["newer", "older"])
    }

    @Test func anUnharvestedPlantingListsNothing() throws {
        let fixture = try HarvestFixture()
        try fixture.harvests.insert(try fixture.harvest())
        #expect(try fixture.harvests.harvests(forPlanting: fixture.basilPlanting.id).isEmpty)
    }

    @Test func recentReturnsTheNewestHarvestsOnly() throws {
        let fixture = try HarvestFixture()
        var oldest = try fixture.harvest()
        oldest.notes = "oldest"
        var middle = try fixture.harvest(on: laterHarvestedDate)
        middle.notes = "middle"
        var newest = try fixture.harvest(on: latestHarvestedDate)
        newest.notes = "newest"
        for harvest in [oldest, middle, newest] {
            try fixture.harvests.insert(harvest)
        }
        #expect(try fixture.harvests.recent(limit: 2).map(\.notes) == ["newest", "middle"])
    }

    @Test func firstHarvestDateIsTheEarliestForThePlanting() throws {
        let fixture = try HarvestFixture()
        try fixture.harvests.insert(try fixture.harvest(on: latestHarvestedDate))
        try fixture.harvests.insert(try fixture.harvest(on: harvestedDate))
        try fixture.harvests.insert(
            try fixture.harvest(of: fixture.basilPlanting, on: laterHarvestedDate))
        #expect(
            try fixture.harvests.firstHarvestDate(forPlanting: fixture.tomatoPlanting.id)
                == harvestedDate)
        #expect(
            try fixture.harvests.firstHarvestDate(forPlanting: fixture.basilPlanting.id)
                == laterHarvestedDate)
    }

    @Test func anUnharvestedPlantingHasNoFirstHarvestDate() throws {
        let fixture = try HarvestFixture()
        #expect(
            try fixture.harvests.firstHarvestDate(forPlanting: fixture.tomatoPlanting.id) == nil)
    }
}
