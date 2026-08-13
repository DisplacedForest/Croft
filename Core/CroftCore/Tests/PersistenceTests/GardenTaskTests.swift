import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

struct GardenTaskStorageTests {
    @Test func everyAttributeRoundTrips() throws {
        let fixture = try GardenTaskFixture()
        let task = GardenTask(
            type: .other,
            customType: "mulch",
            title: "Top up the mulch",
            notes: "two bags of straw",
            dueOn: dueDate,
            completed: true,
            completedOn: completionDate,
            target: .bed(fixture.bed.id)
        )
        try fixture.tasks.insert(task)
        #expect(try fixture.tasks.fetch(id: task.id) == task)
    }

    @Test func aMinimalTaskRoundTrips() throws {
        let fixture = try GardenTaskFixture()
        let task = GardenTask(type: .water, title: "Water")
        try fixture.tasks.insert(task)
        let fetched = try #require(try fixture.tasks.fetch(id: task.id))
        #expect(fetched == task)
        #expect(fetched.customType == nil)
        #expect(fetched.notes == nil)
        #expect(fetched.dueOn == nil)
        #expect(fetched.completed == false)
        #expect(fetched.completedOn == nil)
        #expect(fetched.target == nil)
    }

    @Test(arguments: GardenTaskType.allCases)
    func everyTypeRoundTrips(type: GardenTaskType) throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task(type: type, customType: type == .other ? "mulch" : nil)
        try fixture.tasks.insert(task)
        let fetched = try #require(try fixture.tasks.fetch(id: task.id))
        #expect(fetched.type == type)
        #expect(fetched.customType == task.customType)
    }

    @Test func typeRawValuesMatchTheDatabaseCheck() {
        #expect(
            GardenTaskType.allCases.map(\.rawValue) == [
                "water", "fertilize", "prune", "trellis", "thin",
                "transplant", "inspect", "harvest", "treat", "other",
            ])
    }

    @Test func everyTargetKindRoundTrips() throws {
        let fixture = try GardenTaskFixture()
        let targets: [GardenTaskTarget] = [
            .garden(fixture.garden.id),
            .bed(fixture.bed.id),
            .planting(fixture.planting.id),
        ]
        for target in targets {
            let task = fixture.task(target: target)
            try fixture.tasks.insert(task)
            #expect(try fixture.tasks.fetch(id: task.id)?.target == target)
        }
    }

    @Test func aTaskWithoutATargetRoundTrips() throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task()
        try fixture.tasks.insert(task)
        #expect(try fixture.tasks.fetch(id: task.id)?.target == nil)
    }

    @Test func absentOptionalsAreStoredAsNull() throws {
        let fixture = try GardenTaskFixture()
        let task = GardenTask(type: .prune, title: "Prune")
        try fixture.tasks.insert(task)
        let stored = try #require(try fixture.taskRow(task.id.rawValue))
        let columns = [
            "custom_type", "notes", "due_on", "completed_on",
            "garden_id", "bed_id", "planting_id",
        ]
        for column in columns {
            #expect(stored[column] == DatabaseValue.null)
        }
    }

    @Test func updateReplacesStoredAttributes() throws {
        let fixture = try GardenTaskFixture()
        var task = fixture.task()
        task.notes = "before"
        try fixture.tasks.insert(task)
        task.notes = nil
        task.type = .other
        task.customType = "mulch"
        task.title = "Mulch the bed"
        task.dueOn = laterDueDate
        task.target = .planting(fixture.planting.id)
        try fixture.tasks.update(task)
        #expect(try fixture.tasks.fetch(id: task.id) == task)
    }

    @Test func updatingAMissingTaskThrows() throws {
        let fixture = try GardenTaskFixture()
        let ghost = fixture.task()
        #expect(throws: GardenTaskError.taskNotFound(ghost.id.rawValue)) {
            try fixture.tasks.update(ghost)
        }
    }

    @Test func deleteRemovesTheRow() throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task()
        try fixture.tasks.insert(task)
        #expect(try fixture.tasks.delete(id: task.id))
        #expect(try fixture.tasks.fetch(id: task.id) == nil)
    }

    @Test func deletingAMissingTaskReportsNoChange() throws {
        let fixture = try GardenTaskFixture()
        #expect(try fixture.tasks.delete(id: GardenTask.ID(rawValue: "missing")) == false)
    }
}

struct GardenTaskConstraintTests {
    @Test func anOtherTypeWithoutALabelIsRejectedByTheDatabase() throws {
        let fixture = try GardenTaskFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.tasks.insert(fixture.task(type: .other))
        }
    }

    @Test func aNamedTypeWithACustomLabelIsRejectedByTheDatabase() throws {
        let fixture = try GardenTaskFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.tasks.insert(fixture.task(type: .water, customType: "mulch"))
        }
    }

    @Test func completionWithoutADateIsRejectedByTheDatabase() throws {
        let fixture = try GardenTaskFixture()
        var task = fixture.task()
        task.completed = true
        #expect(throws: DatabaseError.self) {
            try fixture.tasks.insert(task)
        }
    }

    @Test func aCompletionDateWithoutTheFlagIsRejectedByTheDatabase() throws {
        let fixture = try GardenTaskFixture()
        var task = fixture.task()
        task.completedOn = completionDate
        #expect(throws: DatabaseError.self) {
            try fixture.tasks.insert(task)
        }
    }

    @Test func twoTargetsAreRejectedByTheDatabase() throws {
        let fixture = try GardenTaskFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO task (id, type, title, garden_id, bed_id)
                        VALUES ('t1', 'water', 'Water', ?, ?)
                        """,
                    arguments: [fixture.garden.id.rawValue, fixture.bed.id.rawValue]
                )
            }
        }
    }

    @Test func aMissingTargetIsRejectedByTheDatabase() throws {
        let fixture = try GardenTaskFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.tasks.insert(
                fixture.task(target: .bed(Bed.ID(rawValue: "missing"))))
        }
        #expect(try fixture.tasks.fetchAll().isEmpty)
    }

    @Test func aTargetedBedCannotBeDeleted() throws {
        let fixture = try GardenTaskFixture()
        try fixture.tasks.insert(fixture.task(target: .bed(fixture.bed.id)))
        #expect(throws: DatabaseError.self) {
            try fixture.structures.deleteBed(fixture.bed.id)
        }
    }

    @Test func anUnknownTypeFailsToDecode() throws {
        let fixture = try GardenTaskFixture()
        try fixture.insertUnchecked(id: "t1", type: "mulching")
        let expected = TaxonomyCodingError.unknownRawValue(
            table: "task", column: "type", value: "mulching")
        #expect(throws: expected) {
            try fixture.tasks.fetch(id: GardenTask.ID(rawValue: "t1"))
        }
    }

    @Test func aCorruptedCustomTypePairingFailsToDecode() throws {
        let fixture = try GardenTaskFixture()
        try fixture.insertUnchecked(id: "t2", type: "other")
        #expect(throws: GardenTaskError.malformedType("t2")) {
            try fixture.tasks.fetch(id: GardenTask.ID(rawValue: "t2"))
        }
    }

    @Test func aStrayCustomLabelFailsToDecode() throws {
        let fixture = try GardenTaskFixture()
        try fixture.insertUnchecked(id: "t3", type: "water", customType: "mulch")
        #expect(throws: GardenTaskError.malformedType("t3")) {
            try fixture.tasks.fetch(id: GardenTask.ID(rawValue: "t3"))
        }
    }

    @Test func aCorruptedCompletionPairingFailsToDecode() throws {
        let fixture = try GardenTaskFixture()
        try fixture.insertUnchecked(id: "t4", completed: true)
        #expect(throws: GardenTaskError.malformedCompletion("t4")) {
            try fixture.tasks.fetch(id: GardenTask.ID(rawValue: "t4"))
        }
    }

    @Test func aStrayCompletionDateFailsToDecode() throws {
        let fixture = try GardenTaskFixture()
        try fixture.insertUnchecked(id: "t5", completedOn: completionDate)
        #expect(throws: GardenTaskError.malformedCompletion("t5")) {
            try fixture.tasks.fetch(id: GardenTask.ID(rawValue: "t5"))
        }
    }

    @Test func aTwoTargetRowFailsToDecode() throws {
        let fixture = try GardenTaskFixture()
        try fixture.insertUnchecked(
            id: "t6",
            gardenID: fixture.garden.id.rawValue,
            bedID: fixture.bed.id.rawValue
        )
        #expect(throws: GardenTaskError.malformedTarget("t6")) {
            try fixture.tasks.fetch(id: GardenTask.ID(rawValue: "t6"))
        }
    }
}

struct GardenTaskCompletionTests {
    @Test func completeRecordsTheFlagAndTheDate() throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task()
        try fixture.tasks.insert(task)
        try fixture.tasks.complete(id: task.id, on: completionDate)
        let completed = try #require(try fixture.tasks.fetch(id: task.id))
        #expect(completed.completed)
        #expect(completed.completedOn == completionDate)
    }

    @Test func completingTwiceMovesTheCompletionDate() throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task()
        try fixture.tasks.insert(task)
        try fixture.tasks.complete(id: task.id, on: completionDate)
        try fixture.tasks.complete(id: task.id, on: latestDueDate)
        let completed = try #require(try fixture.tasks.fetch(id: task.id))
        #expect(completed.completed)
        #expect(completed.completedOn == latestDueDate)
    }

    @Test func reopenClearsTheFlagAndTheDate() throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task()
        try fixture.tasks.insert(task)
        try fixture.tasks.complete(id: task.id, on: completionDate)
        try fixture.tasks.reopen(id: task.id)
        let reopened = try #require(try fixture.tasks.fetch(id: task.id))
        #expect(reopened.completed == false)
        #expect(reopened.completedOn == nil)
    }

    @Test func reopeningAnOpenTaskChangesNothing() throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task()
        try fixture.tasks.insert(task)
        try fixture.tasks.reopen(id: task.id)
        #expect(try fixture.tasks.fetch(id: task.id) == task)
    }

    @Test func completingAMissingTaskThrows() throws {
        let fixture = try GardenTaskFixture()
        #expect(throws: GardenTaskError.taskNotFound("missing")) {
            try fixture.tasks.complete(id: GardenTask.ID(rawValue: "missing"), on: completionDate)
        }
    }

    @Test func reopeningAMissingTaskThrows() throws {
        let fixture = try GardenTaskFixture()
        #expect(throws: GardenTaskError.taskNotFound("missing")) {
            try fixture.tasks.reopen(id: GardenTask.ID(rawValue: "missing"))
        }
    }
}
