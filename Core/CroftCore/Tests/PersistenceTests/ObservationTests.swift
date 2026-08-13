import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

struct ObservationStorageTests {
    @Test func everyAttributeRoundTrips() throws {
        let fixture = try ObservationFixture()
        let observation = Observation(
            target: .planting(fixture.planting.id),
            observedAt: observedDate,
            notes: "first truss setting",
            growthState: "flowering",
            symptoms: ["leaf curl", "yellow veins"],
            measurements: [
                ObservationMeasurement(label: "height", value: 82.5, unit: "cm"),
                ObservationMeasurement(label: "fruit count", value: 12, unit: "count"),
            ],
            tags: ["greenhouse", "weekly"]
        )
        try fixture.observations.insert(observation)
        #expect(try fixture.observations.fetch(id: observation.id) == observation)
    }

    @Test func aMinimalObservationRoundTrips() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        let fetched = try #require(try fixture.observations.fetch(id: observation.id))
        #expect(fetched == observation)
        #expect(fetched.notes == nil)
        #expect(fetched.growthState == nil)
        #expect(fetched.symptoms.isEmpty)
        #expect(fetched.measurements.isEmpty)
        #expect(fetched.tags.isEmpty)
        #expect(fetched.photos.isEmpty)
    }

    @Test func everyTargetKindRoundTrips() throws {
        let fixture = try ObservationFixture()
        for target in fixture.targets() {
            let observation = fixture.observation(on: target)
            try fixture.observations.insert(observation)
            #expect(try fixture.observations.fetch(id: observation.id)?.target == target)
        }
    }

    @Test func absentOptionalsAreStoredAsNull() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        let stored = try #require(try fixture.observationRow(observation.id.rawValue))
        let columns = ["planting_id", "cultivar_id", "species_id", "garden_id", "notes"]
        for column in columns {
            #expect(stored[column] == DatabaseValue.null)
        }
        #expect(stored["growth_state"] == DatabaseValue.null)
        #expect(stored["symptoms"] == "[]")
        #expect(stored["measurements"] == "[]")
        #expect(stored["tags"] == "[]")
    }

    @Test func updateReplacesStoredAttributes() throws {
        let fixture = try ObservationFixture()
        var observation = fixture.observation()
        observation.notes = "slug damage"
        try fixture.observations.insert(observation)
        observation.notes = nil
        observation.growthState = "fruiting"
        observation.symptoms = ["holes in leaves"]
        observation.tags = ["pest watch"]
        observation.observedAt = laterObservedDate
        try fixture.observations.update(observation)
        #expect(try fixture.observations.fetch(id: observation.id) == observation)
    }

    @Test func updatingAMissingObservationThrows() throws {
        let fixture = try ObservationFixture()
        let ghost = fixture.observation()
        #expect(throws: ObservationError.observationNotFound(ghost.id.rawValue)) {
            try fixture.observations.update(ghost)
        }
    }

    @Test func deleteRemovesTheRow() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        #expect(try fixture.observations.delete(id: observation.id))
        #expect(try fixture.observations.fetch(id: observation.id) == nil)
    }

    @Test func deletingAMissingObservationReportsNoChange() throws {
        let fixture = try ObservationFixture()
        #expect(try fixture.observations.delete(id: Observation.ID(rawValue: "missing")) == false)
    }
}

struct ObservationTargetConstraintTests {
    @Test func anObservationWithNoTargetIsRejectedByTheDatabase() throws {
        let fixture = try ObservationFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO observation (id, observed_at)
                        VALUES ('o1', '2024-07-03 12:00:00')
                        """
                )
            }
        }
    }

    @Test func anObservationWithTwoTargetsIsRejectedByTheDatabase() throws {
        let fixture = try ObservationFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO observation (id, bed_id, garden_id, observed_at)
                        VALUES ('o1', ?, ?, '2024-07-03 12:00:00')
                        """,
                    arguments: [fixture.bed.id.rawValue, fixture.garden.id.rawValue]
                )
            }
        }
    }

    @Test func aCorruptedTargetFailsToDecode() throws {
        let fixture = try ObservationFixture()
        try fixture.database.writer.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints = ON")
            try db.execute(
                sql: """
                    INSERT INTO observation (id, bed_id, garden_id, observed_at)
                    VALUES ('o1', ?, ?, '2024-07-03 12:00:00')
                    """,
                arguments: [fixture.bed.id.rawValue, fixture.garden.id.rawValue]
            )
            try db.execute(sql: "PRAGMA ignore_check_constraints = OFF")
        }
        #expect(throws: ObservationError.malformedTarget("o1")) {
            try fixture.observations.fetch(id: Observation.ID(rawValue: "o1"))
        }
    }

    @Test func anObservationWithoutItsBedIsRejected() throws {
        let fixture = try ObservationFixture()
        let orphan = fixture.observation(on: .bed(Bed.ID(rawValue: "missing")))
        #expect(throws: DatabaseError.self) {
            try fixture.observations.insert(orphan)
        }
        #expect(try fixture.observations.fetchAll().isEmpty)
    }

    @Test func aBedWithObservationsCannotBeDeleted() throws {
        let fixture = try ObservationFixture()
        try fixture.observations.insert(fixture.observation())
        #expect(throws: (any Error).self) {
            try fixture.structures.deleteBed(fixture.bed.id)
        }
        #expect(try fixture.registered(fixture.bed.id.rawValue)?.type == .bed)
    }

    @Test func aPlantingWithObservationsCannotBeDeleted() throws {
        let fixture = try ObservationFixture()
        try fixture.observations.insert(
            fixture.observation(on: .planting(fixture.planting.id)))
        #expect(throws: DatabaseError.self) {
            try fixture.plantings.delete(id: fixture.planting.id)
        }
        #expect(try fixture.plantings.fetch(id: fixture.planting.id) != nil)
    }

    @Test func aCultivarWithObservationsCannotBeDeleted() throws {
        let fixture = try ObservationFixture()
        try fixture.observations.insert(
            fixture.observation(on: .plant(.cultivar(fixture.cultivar.id))))
        #expect(throws: DatabaseError.self) {
            try fixture.cultivars.delete(id: fixture.cultivar.id)
        }
        #expect(try fixture.cultivars.fetch(id: fixture.cultivar.id) != nil)
    }
}

struct ObservationQueryTests {
    @Test func fetchAllPutsTheNewestObservationFirst() throws {
        let fixture = try ObservationFixture()
        var older = fixture.observation()
        older.notes = "older"
        var newer = fixture.observation(at: laterObservedDate)
        newer.notes = "newer"
        try fixture.observations.insert(older)
        try fixture.observations.insert(newer)
        #expect(try fixture.observations.fetchAll().map(\.notes) == ["newer", "older"])
    }

    @Test func observationsAreListedPerTarget() throws {
        let fixture = try ObservationFixture()
        for target in fixture.targets() {
            let observation = fixture.observation(on: target)
            try fixture.observations.insert(observation)
            #expect(try fixture.observations.observations(on: target).map(\.id) == [observation.id])
        }
    }

    @Test func anUnobservedTargetListsNothing() throws {
        let fixture = try ObservationFixture()
        try fixture.observations.insert(fixture.observation())
        #expect(try fixture.observations.observations(on: .bed(fixture.otherBed.id)).isEmpty)
    }

    @Test func recentReturnsTheNewestObservationsOnly() throws {
        let fixture = try ObservationFixture()
        var oldest = fixture.observation()
        oldest.notes = "oldest"
        var middle = fixture.observation(at: laterObservedDate)
        middle.notes = "middle"
        var newest = fixture.observation(at: latestObservedDate)
        newest.notes = "newest"
        for observation in [oldest, middle, newest] {
            try fixture.observations.insert(observation)
        }
        #expect(try fixture.observations.recent(limit: 2).map(\.notes) == ["newest", "middle"])
    }
}
