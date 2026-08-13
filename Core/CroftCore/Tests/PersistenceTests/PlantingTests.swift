import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

struct PlantingStorageTests {
    @Test func everyAttributeRoundTrips() throws {
        let fixture = try PlantingFixture()
        let planting = Planting(
            identity: .cultivar(fixture.cultivar.id),
            bedID: fixture.bed.id,
            source: .seedLot(fixture.seedLot.id),
            plantedOn: plantingDate,
            transplantedOn: transplantDate,
            quantity: 6,
            spacingCentimeters: 45,
            status: .active,
            expectedMaturityOn: maturityDate,
            endedOn: endDate,
            notes: "staked with spirals"
        )
        try fixture.plantings.insert(planting)
        #expect(try fixture.plantings.fetch(id: planting.id) == planting)
    }

    @Test func aPlantingWithOnlyIdentityAndBedRoundTrips() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting()
        try fixture.plantings.insert(planting)
        let fetched = try #require(try fixture.plantings.fetch(id: planting.id))
        #expect(fetched == planting)
        #expect(fetched.status == .planned)
        #expect(fetched.source == nil)
    }

    @Test func aSpeciesIdentityRoundTrips() throws {
        let fixture = try PlantingFixture()
        let planting = Planting(identity: .species(fixture.plant.id), bedID: fixture.bed.id)
        try fixture.plantings.insert(planting)
        #expect(
            try fixture.plantings.fetch(id: planting.id)?.identity == .species(fixture.plant.id))
    }

    @Test func aStarterBatchSourceRoundTrips() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting(source: .starterBatch(fixture.starterBatch.id))
        try fixture.plantings.insert(planting)
        #expect(
            try fixture.plantings.fetch(id: planting.id)?.source
                == .starterBatch(fixture.starterBatch.id))
    }

    @Test func absentOptionalsAreStoredAsNull() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting()
        try fixture.plantings.insert(planting)
        let stored = try #require(try fixture.row("planting", planting.id.rawValue))
        let columns = [
            "species_id", "seed_lot_id", "starter_batch_id",
            "planted_on", "transplanted_on", "quantity", "spacing_cm",
            "expected_maturity_on", "ended_on", "notes",
        ]
        for column in columns {
            #expect(stored[column] == DatabaseValue.null)
        }
        #expect(stored["status"] == "planned")
    }

    @Test func statusRawValuesAreStableStrings() {
        #expect(
            PlantingStatus.allCases.map(\.rawValue)
                == ["planned", "active", "finished", "failed"])
    }

    @Test(arguments: PlantingStatus.allCases)
    func everyStatusRoundTripsThroughTheDatabase(status: PlantingStatus) throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting(status: status)
        try fixture.plantings.insert(planting)
        #expect(try fixture.plantings.fetch(id: planting.id)?.status == status)
    }

    @Test func anUnknownStatusIsRejectedByTheDatabase() throws {
        let fixture = try PlantingFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO planting (id, cultivar_id, bed_id, status)
                        VALUES ('p1', ?, ?, 'composted')
                        """,
                    arguments: [fixture.cultivar.id.rawValue, fixture.bed.id.rawValue]
                )
            }
        }
    }

    @Test func aPlantingWithBothIdentitiesIsRejectedByTheDatabase() throws {
        let fixture = try PlantingFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO planting (id, cultivar_id, species_id, bed_id, status)
                        VALUES ('p1', ?, ?, ?, 'planned')
                        """,
                    arguments: [
                        fixture.cultivar.id.rawValue,
                        fixture.plant.id.rawValue,
                        fixture.bed.id.rawValue,
                    ]
                )
            }
        }
    }

    @Test func aPlantingWithNoIdentityIsRejectedByTheDatabase() throws {
        let fixture = try PlantingFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO planting (id, bed_id, status)
                        VALUES ('p1', ?, 'planned')
                        """,
                    arguments: [fixture.bed.id.rawValue]
                )
            }
        }
    }

    @Test func aPlantingWithBothSourcesIsRejectedByTheDatabase() throws {
        let fixture = try PlantingFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO planting
                            (id, cultivar_id, bed_id, seed_lot_id, starter_batch_id, status)
                        VALUES ('p1', ?, ?, ?, ?, 'planned')
                        """,
                    arguments: [
                        fixture.cultivar.id.rawValue,
                        fixture.bed.id.rawValue,
                        fixture.seedLot.id.rawValue,
                        fixture.starterBatch.id.rawValue,
                    ]
                )
            }
        }
    }

    @Test func updateReplacesStoredAttributes() throws {
        let fixture = try PlantingFixture()
        var planting = fixture.planting(source: .seedLot(fixture.seedLot.id))
        planting.plantedOn = plantingDate
        planting.quantity = 6
        try fixture.plantings.insert(planting)
        planting.plantedOn = nil
        planting.quantity = nil
        planting.spacingCentimeters = 30
        planting.notes = "resown after slugs"
        try fixture.plantings.update(planting)
        #expect(try fixture.plantings.fetch(id: planting.id) == planting)
    }

}

struct PlantingQueryTests {
    @Test func fetchAllPutsTheNewestPlantingFirst() throws {
        let fixture = try PlantingFixture()
        var older = fixture.planting()
        older.plantedOn = plantingDate
        older.notes = "older"
        var newer = fixture.planting()
        newer.plantedOn = transplantDate
        newer.notes = "newer"
        try fixture.plantings.insert(older)
        try fixture.plantings.insert(newer)
        #expect(try fixture.plantings.fetchAll().map(\.notes) == ["newer", "older"])
    }

    @Test func plantingsAreListedPerCultivar() throws {
        let fixture = try PlantingFixture()
        let other = try fixture.addCultivar(named: "Cherokee Purple")
        let mine = fixture.planting()
        try fixture.plantings.insert(mine)
        try fixture.plantings.insert(Planting(identity: .cultivar(other.id), bedID: fixture.bed.id))
        #expect(
            try fixture.plantings.plantings(of: .cultivar(fixture.cultivar.id)).map(\.id)
                == [mine.id])
    }

    @Test func plantingsAreListedPerSpecies() throws {
        let fixture = try PlantingFixture()
        let bySpecies = Planting(identity: .species(fixture.plant.id), bedID: fixture.bed.id)
        try fixture.plantings.insert(bySpecies)
        try fixture.plantings.insert(fixture.planting())
        #expect(
            try fixture.plantings.plantings(of: .species(fixture.plant.id)).map(\.id)
                == [bySpecies.id])
    }

    @Test func activePlantingsAreListedPerBed() throws {
        let fixture = try PlantingFixture()
        let active = fixture.planting(status: .active)
        try fixture.plantings.insert(active)
        try fixture.plantings.insert(fixture.planting(status: .planned))
        try fixture.plantings.insert(
            Planting(
                identity: .cultivar(fixture.cultivar.id),
                bedID: fixture.tunnelBed.id,
                status: .active
            ))
        #expect(
            try fixture.plantings.activePlantings(inBed: fixture.bed.id).map(\.id) == [active.id])
    }

    @Test func plantingsInAGardenSpanDirectAndNestedBeds() throws {
        let fixture = try PlantingFixture()
        var direct = fixture.planting()
        direct.plantedOn = transplantDate
        var nested = Planting(identity: .cultivar(fixture.cultivar.id), bedID: fixture.tunnelBed.id)
        nested.plantedOn = plantingDate
        try fixture.plantings.insert(direct)
        try fixture.plantings.insert(nested)
        try fixture.plantings.insert(
            Planting(identity: .cultivar(fixture.cultivar.id), bedID: fixture.otherBed.id))
        #expect(
            try fixture.plantings.plantings(inGarden: fixture.garden.id).map(\.id)
                == [direct.id, nested.id])
    }

    @Test func aGardenWithoutPlantingsListsNone() throws {
        let fixture = try PlantingFixture()
        try fixture.plantings.insert(fixture.planting())
        #expect(try fixture.plantings.plantings(inGarden: fixture.otherGarden.id).isEmpty)
    }

}

struct PlantingConstraintTests {
    @Test func deleteRemovesTheRow() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting()
        try fixture.plantings.insert(planting)
        #expect(try fixture.plantings.delete(id: planting.id))
        #expect(try fixture.plantings.fetch(id: planting.id) == nil)
    }

    @Test func deletingAMissingPlantingReportsNoChange() throws {
        let fixture = try PlantingFixture()
        #expect(try fixture.plantings.delete(id: Planting.ID(rawValue: "missing")) == false)
    }

    @Test func aPlantingWithoutItsCultivarIsRejected() throws {
        let fixture = try PlantingFixture()
        let orphan = Planting(
            identity: .cultivar(Cultivar.ID(rawValue: "missing")),
            bedID: fixture.bed.id
        )
        #expect(throws: DatabaseError.self) {
            try fixture.plantings.insert(orphan)
        }
        #expect(try fixture.plantings.fetchAll().isEmpty)
    }

    @Test func aPlantingWithoutItsBedIsRejected() throws {
        let fixture = try PlantingFixture()
        let orphan = Planting(
            identity: .cultivar(fixture.cultivar.id),
            bedID: Bed.ID(rawValue: "missing")
        )
        #expect(throws: DatabaseError.self) {
            try fixture.plantings.insert(orphan)
        }
        #expect(try fixture.plantings.fetchAll().isEmpty)
    }

    @Test func aPlantingWithoutItsSeedLotIsRejected() throws {
        let fixture = try PlantingFixture()
        let orphan = fixture.planting(source: .seedLot(SeedLot.ID(rawValue: "missing")))
        #expect(throws: DatabaseError.self) {
            try fixture.plantings.insert(orphan)
        }
        #expect(try fixture.plantings.fetchAll().isEmpty)
    }

    @Test func aCultivarWithPlantingsCannotBeDeleted() throws {
        let fixture = try PlantingFixture()
        try fixture.plantings.insert(fixture.planting())
        #expect(throws: DatabaseError.self) {
            try fixture.cultivars.delete(id: fixture.cultivar.id)
        }
        #expect(try fixture.cultivars.fetch(id: fixture.cultivar.id) != nil)
    }

    @Test func aBedWithPlantingsCannotBeDeleted() throws {
        let fixture = try PlantingFixture()
        try fixture.plantings.insert(fixture.planting())
        #expect(throws: (any Error).self) {
            try fixture.structures.deleteBed(fixture.bed.id)
        }
        #expect(try fixture.registered(fixture.bed.id.rawValue)?.type == .bed)
    }

    @Test func aSeedLotWithPlantingsCannotBeDeleted() throws {
        let fixture = try PlantingFixture()
        try fixture.plantings.insert(fixture.planting(source: .seedLot(fixture.seedLot.id)))
        #expect(throws: DatabaseError.self) {
            try fixture.seedLots.delete(id: fixture.seedLot.id)
        }
        #expect(try fixture.seedLots.fetch(id: fixture.seedLot.id) != nil)
    }
}

struct PlantingLifecycleTests {
    private func inserted(_ status: PlantingStatus) throws -> (PlantingFixture, Planting) {
        let fixture = try PlantingFixture()
        let planting = fixture.planting(status: status)
        try fixture.plantings.insert(planting)
        return (fixture, planting)
    }

    @Test(arguments: [
        (PlantingStatus.planned, PlantingStatus.active),
        (.planned, .failed),
        (.active, .finished),
        (.active, .failed),
    ])
    func allowedTransitionsAreAccepted(from: PlantingStatus, next: PlantingStatus) throws {
        let (fixture, planting) = try inserted(from)
        var moved = planting
        moved.status = next
        try fixture.plantings.update(moved)
        #expect(try fixture.plantings.fetch(id: planting.id)?.status == next)
    }

    @Test(arguments: [
        (PlantingStatus.planned, PlantingStatus.finished),
        (.active, .planned),
        (.finished, .active),
        (.finished, .planned),
        (.finished, .failed),
        (.failed, .active),
        (.failed, .planned),
        (.failed, .finished),
    ])
    func invalidTransitionsAreRejected(from: PlantingStatus, next: PlantingStatus) throws {
        let (fixture, planting) = try inserted(from)
        var moved = planting
        moved.status = next
        #expect(throws: PlantingError.invalidStatusTransition(from: from, requested: next)) {
            try fixture.plantings.update(moved)
        }
        #expect(try fixture.plantings.fetch(id: planting.id)?.status == from)
    }

    @Test(arguments: PlantingStatus.allCases)
    func aSameStatusUpdateIsAccepted(status: PlantingStatus) throws {
        let (fixture, planting) = try inserted(status)
        var edited = planting
        edited.notes = "still going"
        try fixture.plantings.update(edited)
        #expect(try fixture.plantings.fetch(id: planting.id) == edited)
    }

    @Test func aRejectedTransitionLeavesTheRowUnchanged() throws {
        let (fixture, planting) = try inserted(.finished)
        var moved = planting
        moved.status = .active
        moved.notes = "should not land"
        #expect(throws: PlantingError.self) {
            try fixture.plantings.update(moved)
        }
        #expect(try fixture.plantings.fetch(id: planting.id) == planting)
    }

    @Test func updatingAMissingPlantingThrows() throws {
        let fixture = try PlantingFixture()
        let ghost = fixture.planting()
        #expect(throws: PlantingError.plantingNotFound(ghost.id.rawValue)) {
            try fixture.plantings.update(ghost)
        }
    }
}
