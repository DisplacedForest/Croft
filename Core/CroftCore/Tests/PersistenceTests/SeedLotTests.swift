import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

struct SeedLotStorageTests {
    @Test func everyAttributeRoundTrips() throws {
        let fixture = try SeedLotFixture()
        let lot = SeedLot(
            cultivarID: fixture.cultivar.id,
            source: "Baker Creek",
            acquiredOn: acquisitionDate,
            quantity: "1 g",
            seedCount: 40,
            notes: "kept in the door of the fridge"
        )
        try fixture.seedLots.insert(lot)
        #expect(try fixture.seedLots.fetch(id: lot.id) == lot)
    }

    @Test func aLotWithOnlyItsCultivarRoundTrips() throws {
        let fixture = try SeedLotFixture()
        let lot = SeedLot(cultivarID: fixture.cultivar.id)
        try fixture.seedLots.insert(lot)
        #expect(try fixture.seedLots.fetch(id: lot.id) == lot)
    }

    @Test func absentOptionalsAreStoredAsNull() throws {
        let fixture = try SeedLotFixture()
        let lot = SeedLot(cultivarID: fixture.cultivar.id)
        try fixture.seedLots.insert(lot)
        let stored = try #require(try fixture.row("seed_lot", lot.id.rawValue))
        for column in ["source", "acquired_on", "quantity", "seed_count", "notes"] {
            #expect(stored[column] == DatabaseValue.null)
        }
    }

    @Test func updateReplacesStoredAttributes() throws {
        let fixture = try SeedLotFixture()
        var lot = SeedLot(
            cultivarID: fixture.cultivar.id,
            source: "Baker Creek",
            acquiredOn: acquisitionDate,
            seedCount: 40
        )
        try fixture.seedLots.insert(lot)
        lot.source = "seed swap"
        lot.acquiredOn = nil
        lot.seedCount = nil
        lot.notes = "traded at the spring swap"
        try fixture.seedLots.update(lot)
        #expect(try fixture.seedLots.fetch(id: lot.id) == lot)
    }

    @Test func fetchAllPutsTheNewestAcquisitionFirst() throws {
        let fixture = try SeedLotFixture()
        let older = SeedLot(
            cultivarID: fixture.cultivar.id,
            source: "older",
            acquiredOn: acquisitionDate
        )
        let newer = SeedLot(
            cultivarID: fixture.cultivar.id,
            source: "newer",
            acquiredOn: sowingDate
        )
        try fixture.seedLots.insert(older)
        try fixture.seedLots.insert(newer)
        #expect(try fixture.seedLots.fetchAll().map(\.source) == ["newer", "older"])
    }

    @Test func lotsAreListedPerCultivar() throws {
        let fixture = try SeedLotFixture()
        let other = try fixture.addCultivar(named: "Cherokee Purple")
        let mine = SeedLot(cultivarID: fixture.cultivar.id, source: "mine")
        try fixture.seedLots.insert(mine)
        try fixture.seedLots.insert(SeedLot(cultivarID: other.id, source: "theirs"))
        #expect(try fixture.seedLots.lots(ofCultivar: fixture.cultivar.id).map(\.id) == [mine.id])
    }

    @Test func deleteRemovesTheRow() throws {
        let fixture = try SeedLotFixture()
        let lot = SeedLot(cultivarID: fixture.cultivar.id)
        try fixture.seedLots.insert(lot)
        #expect(try fixture.seedLots.delete(id: lot.id))
        #expect(try fixture.seedLots.fetch(id: lot.id) == nil)
    }

    @Test func deletingAMissingLotReportsNoChange() throws {
        let fixture = try SeedLotFixture()
        #expect(try fixture.seedLots.delete(id: SeedLot.ID(rawValue: "missing")) == false)
    }

    @Test func aLotWithoutItsCultivarIsRejected() throws {
        let fixture = try SeedLotFixture()
        let orphan = SeedLot(cultivarID: Cultivar.ID(rawValue: "missing"))
        #expect(throws: DatabaseError.self) {
            try fixture.seedLots.insert(orphan)
        }
        #expect(try fixture.seedLots.fetchAll().isEmpty)
    }

    @Test func aCultivarWithSeedLotsCannotBeDeleted() throws {
        let fixture = try SeedLotFixture()
        try fixture.seedLots.insert(SeedLot(cultivarID: fixture.cultivar.id))
        #expect(throws: DatabaseError.self) {
            try fixture.cultivars.delete(id: fixture.cultivar.id)
        }
        #expect(try fixture.cultivars.fetch(id: fixture.cultivar.id) != nil)
    }
}

struct StarterBatchStorageTests {
    private func fixtureWithLot() throws -> (SeedLotFixture, SeedLot) {
        let fixture = try SeedLotFixture()
        let lot = SeedLot(cultivarID: fixture.cultivar.id, source: "Baker Creek")
        try fixture.seedLots.insert(lot)
        return (fixture, lot)
    }

    @Test func everyAttributeRoundTrips() throws {
        let (fixture, lot) = try fixtureWithLot()
        let batch = StarterBatch(
            seedLotID: lot.id,
            sownOn: sowingDate,
            quantity: 24,
            status: .growing
        )
        try fixture.starterBatches.insert(batch)
        #expect(try fixture.starterBatches.fetch(id: batch.id) == batch)
    }

    @Test func aBatchWithOnlyItsSeedLotRoundTrips() throws {
        let (fixture, lot) = try fixtureWithLot()
        let batch = StarterBatch(seedLotID: lot.id)
        try fixture.starterBatches.insert(batch)
        let fetched = try #require(try fixture.starterBatches.fetch(id: batch.id))
        #expect(fetched == batch)
        #expect(fetched.status == .sown)
    }

    @Test func absentOptionalsAreStoredAsNull() throws {
        let (fixture, lot) = try fixtureWithLot()
        let batch = StarterBatch(seedLotID: lot.id)
        try fixture.starterBatches.insert(batch)
        let stored = try #require(try fixture.row("starter_batch", batch.id.rawValue))
        #expect(stored["sown_on"] == DatabaseValue.null)
        #expect(stored["quantity"] == DatabaseValue.null)
        #expect(stored["status"] == "sown")
    }

    @Test(arguments: StarterBatchStatus.allCases)
    func everyStatusRoundTripsThroughTheDatabase(status: StarterBatchStatus) throws {
        let (fixture, lot) = try fixtureWithLot()
        let batch = StarterBatch(seedLotID: lot.id, status: status)
        try fixture.starterBatches.insert(batch)
        #expect(try fixture.starterBatches.fetch(id: batch.id)?.status == status)
    }

    @Test func statusRawValuesAreStableStrings() {
        #expect(
            StarterBatchStatus.allCases.map(\.rawValue)
                == ["sown", "growing", "transplanted", "failed"])
    }

    @Test func anUnknownStatusIsRejectedByTheDatabase() throws {
        let (fixture, lot) = try fixtureWithLot()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO starter_batch (id, seed_lot_id, status)
                        VALUES ('b1', ?, 'composted')
                        """,
                    arguments: [lot.id.rawValue]
                )
            }
        }
    }

    @Test func updateReplacesStoredAttributes() throws {
        let (fixture, lot) = try fixtureWithLot()
        var batch = StarterBatch(seedLotID: lot.id, sownOn: sowingDate, quantity: 24)
        try fixture.starterBatches.insert(batch)
        batch.status = .transplanted
        batch.quantity = 20
        batch.sownOn = nil
        try fixture.starterBatches.update(batch)
        #expect(try fixture.starterBatches.fetch(id: batch.id) == batch)
    }

    @Test func batchesAreListedPerSeedLot() throws {
        let (fixture, lot) = try fixtureWithLot()
        let other = SeedLot(cultivarID: fixture.cultivar.id, source: "seed swap")
        try fixture.seedLots.insert(other)
        let mine = StarterBatch(seedLotID: lot.id)
        try fixture.starterBatches.insert(mine)
        try fixture.starterBatches.insert(StarterBatch(seedLotID: other.id))
        #expect(try fixture.starterBatches.batches(ofSeedLot: lot.id).map(\.id) == [mine.id])
    }

    @Test func fetchAllPutsTheNewestSowingFirst() throws {
        let (fixture, lot) = try fixtureWithLot()
        let older = StarterBatch(seedLotID: lot.id, sownOn: acquisitionDate, quantity: 1)
        let newer = StarterBatch(seedLotID: lot.id, sownOn: sowingDate, quantity: 2)
        try fixture.starterBatches.insert(older)
        try fixture.starterBatches.insert(newer)
        #expect(try fixture.starterBatches.fetchAll().map(\.quantity) == [2, 1])
    }

    @Test func aBatchWithoutItsSeedLotIsRejected() throws {
        let fixture = try SeedLotFixture()
        let orphan = StarterBatch(seedLotID: SeedLot.ID(rawValue: "missing"))
        #expect(throws: DatabaseError.self) {
            try fixture.starterBatches.insert(orphan)
        }
        #expect(try fixture.starterBatches.fetchAll().isEmpty)
    }

    @Test func aSeedLotWithStarterBatchesCannotBeDeleted() throws {
        let (fixture, lot) = try fixtureWithLot()
        try fixture.starterBatches.insert(StarterBatch(seedLotID: lot.id))
        #expect(throws: DatabaseError.self) {
            try fixture.seedLots.delete(id: lot.id)
        }
        #expect(try fixture.seedLots.fetch(id: lot.id) != nil)
        #expect(try fixture.registered(lot.id.rawValue) != nil)
    }

    @Test func deleteRemovesTheRow() throws {
        let (fixture, lot) = try fixtureWithLot()
        let batch = StarterBatch(seedLotID: lot.id)
        try fixture.starterBatches.insert(batch)
        #expect(try fixture.starterBatches.delete(id: batch.id))
        #expect(try fixture.starterBatches.fetch(id: batch.id) == nil)
    }

    @Test func deletingAMissingBatchReportsNoChange() throws {
        let fixture = try SeedLotFixture()
        #expect(
            try fixture.starterBatches.delete(id: StarterBatch.ID(rawValue: "missing")) == false)
    }
}
