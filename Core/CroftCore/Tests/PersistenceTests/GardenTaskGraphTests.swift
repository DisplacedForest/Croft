import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

struct GardenTaskGraphTests {
    @Test func insertRegistersTheTaskAndItsTarget() throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task(target: .bed(fixture.bed.id))
        try fixture.tasks.insert(task)
        #expect(try fixture.registered(task.id.rawValue)?.type == .task)
        #expect(try fixture.registered(fixture.bed.id.rawValue)?.type == .bed)
    }

    @Test func insertCreatesExactlyOneTaskForEdge() throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task(target: .planting(fixture.planting.id))
        try fixture.tasks.insert(task)
        let edges = try fixture.outgoing(task.id.rawValue, .taskFor)
        #expect(
            edges.map(\.target)
                == [EntityRef(id: fixture.planting.id.rawValue, type: .planting)])
        #expect(try fixture.edgeCount(referencing: task.id.rawValue) == 1)
    }

    @Test func taskEdgesCarryNoProvenance() throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task(target: .garden(fixture.garden.id))
        try fixture.tasks.insert(task)
        #expect(
            try fixture.outgoing(task.id.rawValue, .taskFor).map(\.provenance) == [Provenance()])
    }

    @Test func anUntargetedTaskIsRegisteredWithoutAnEdge() throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task()
        try fixture.tasks.insert(task)
        #expect(try fixture.registered(task.id.rawValue)?.type == .task)
        #expect(try fixture.edgeCount(referencing: task.id.rawValue) == 0)
    }

    @Test func repointingMovesTheTaskForEdge() throws {
        let fixture = try GardenTaskFixture()
        var task = fixture.task(target: .bed(fixture.bed.id))
        try fixture.tasks.insert(task)
        task.target = .bed(fixture.otherBed.id)
        try fixture.tasks.update(task)
        let targets = try fixture.outgoing(task.id.rawValue, .taskFor).map(\.target.id)
        #expect(targets == [fixture.otherBed.id.rawValue])
        #expect(try fixture.incoming(fixture.bed.id.rawValue, .taskFor).isEmpty)
    }

    @Test func repointingAcrossTargetKindsMovesTheEdge() throws {
        let fixture = try GardenTaskFixture()
        var task = fixture.task(target: .bed(fixture.bed.id))
        try fixture.tasks.insert(task)
        task.target = .garden(fixture.garden.id)
        try fixture.tasks.update(task)
        let edges = try fixture.outgoing(task.id.rawValue, .taskFor)
        #expect(
            edges.map(\.target)
                == [EntityRef(id: fixture.garden.id.rawValue, type: .garden)])
    }

    @Test func addingATargetCreatesTheEdge() throws {
        let fixture = try GardenTaskFixture()
        var task = fixture.task()
        try fixture.tasks.insert(task)
        task.target = .bed(fixture.bed.id)
        try fixture.tasks.update(task)
        let targets = try fixture.outgoing(task.id.rawValue, .taskFor).map(\.target.id)
        #expect(targets == [fixture.bed.id.rawValue])
    }

    @Test func clearingTheTargetRemovesTheEdge() throws {
        let fixture = try GardenTaskFixture()
        var task = fixture.task(target: .bed(fixture.bed.id))
        try fixture.tasks.insert(task)
        task.target = nil
        try fixture.tasks.update(task)
        #expect(try fixture.outgoing(task.id.rawValue, .taskFor).isEmpty)
        #expect(try fixture.edgeCount(referencing: task.id.rawValue) == 0)
        #expect(try fixture.registered(task.id.rawValue)?.type == .task)
    }

    @Test func anUnchangedUpdateKeepsTheSameEdge() throws {
        let fixture = try GardenTaskFixture()
        var task = fixture.task(target: .bed(fixture.bed.id))
        try fixture.tasks.insert(task)
        let before = try fixture.outgoing(task.id.rawValue, .taskFor).map(\.id)
        task.notes = "still fine"
        try fixture.tasks.update(task)
        #expect(try fixture.outgoing(task.id.rawValue, .taskFor).map(\.id) == before)
    }

    @Test func aSecondTaskForEdgeIsRejectedByTheDatabase() throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task(target: .bed(fixture.bed.id))
        try fixture.tasks.insert(task)
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e1', ?, 'TASK_FOR', ?)
                        """,
                    arguments: [task.id.rawValue, fixture.otherBed.id.rawValue]
                )
            }
        }
    }

    @Test func aTargetedEntityCannotBeDeletedFromTheGraph() throws {
        let fixture = try GardenTaskFixture()
        try fixture.tasks.insert(fixture.task(target: .garden(fixture.garden.id)))
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try GraphStore.deleteEntity(fixture.garden.id.rawValue, in: db)
            }
        }
    }

    @Test func deleteRemovesTheEntityAndItsEdge() throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task(target: .bed(fixture.bed.id))
        try fixture.tasks.insert(task)
        try fixture.tasks.delete(id: task.id)
        #expect(try fixture.registered(task.id.rawValue) == nil)
        #expect(try fixture.edgeCount(referencing: task.id.rawValue) == 0)
        #expect(try fixture.registered(fixture.bed.id.rawValue)?.type == .bed)
    }

    @Test func deletingAFreeFloatingTaskWorks() throws {
        let fixture = try GardenTaskFixture()
        let task = fixture.task()
        try fixture.tasks.insert(task)
        #expect(try fixture.tasks.delete(id: task.id))
        #expect(try fixture.registered(task.id.rawValue) == nil)
    }

    @Test func twoTasksForTheSameTargetBothPointAtIt() throws {
        let fixture = try GardenTaskFixture()
        let first = fixture.task(target: .bed(fixture.bed.id))
        let second = fixture.task(title: "Weed", target: .bed(fixture.bed.id))
        try fixture.tasks.insert(first)
        try fixture.tasks.insert(second)
        let sources = try fixture.incoming(fixture.bed.id.rawValue, .taskFor)
            .map(\.source.id)
            .sorted()
        #expect(sources == [first.id.rawValue, second.id.rawValue].sorted())
    }
}

struct GardenTaskQueryTests {
    @Test func fetchAllOrdersDueDatesAscendingWithNullsLast() throws {
        let fixture = try GardenTaskFixture()
        let undated = fixture.task(title: "undated", dueOn: nil)
        let later = fixture.task(title: "later", dueOn: laterDueDate)
        let sooner = fixture.task(title: "sooner", dueOn: dueDate)
        for task in [undated, later, sooner] {
            try fixture.tasks.insert(task)
        }
        #expect(try fixture.tasks.fetchAll().map(\.title) == ["sooner", "later", "undated"])
    }

    @Test func openTasksExcludeCompletedOnes() throws {
        let fixture = try GardenTaskFixture()
        let open = fixture.task(title: "open")
        let done = fixture.task(title: "done", dueOn: laterDueDate)
        try fixture.tasks.insert(open)
        try fixture.tasks.insert(done)
        try fixture.tasks.complete(id: done.id, on: completionDate)
        #expect(try fixture.tasks.openTasks().map(\.title) == ["open"])
    }

    @Test func openTasksOrderDueDatesWithNullsLast() throws {
        let fixture = try GardenTaskFixture()
        let undated = fixture.task(title: "undated", dueOn: nil)
        let latest = fixture.task(title: "latest", dueOn: latestDueDate)
        let sooner = fixture.task(title: "sooner", dueOn: dueDate)
        for task in [undated, latest, sooner] {
            try fixture.tasks.insert(task)
        }
        #expect(try fixture.tasks.openTasks().map(\.title) == ["sooner", "latest", "undated"])
    }

    @Test func overdueTasksStopAtTheBoundary() throws {
        let fixture = try GardenTaskFixture()
        let due = fixture.task(title: "due now", dueOn: dueDate)
        let overdue = fixture.task(title: "overdue", dueOn: dueDate.addingTimeInterval(-1))
        try fixture.tasks.insert(due)
        try fixture.tasks.insert(overdue)
        #expect(try fixture.tasks.overdueTasks(asOf: dueDate).map(\.title) == ["overdue"])
    }

    @Test func overdueTasksIgnoreUndatedAndCompletedTasks() throws {
        let fixture = try GardenTaskFixture()
        let undated = fixture.task(title: "undated", dueOn: nil)
        let done = fixture.task(title: "done", dueOn: dueDate)
        let open = fixture.task(title: "open", dueOn: dueDate)
        for task in [undated, done, open] {
            try fixture.tasks.insert(task)
        }
        try fixture.tasks.complete(id: done.id, on: completionDate)
        #expect(try fixture.tasks.overdueTasks(asOf: laterDueDate).map(\.title) == ["open"])
    }

    @Test func tasksAreListedPerTarget() throws {
        let fixture = try GardenTaskFixture()
        let gardenTask = fixture.task(title: "garden", target: .garden(fixture.garden.id))
        let bedTask = fixture.task(title: "bed", target: .bed(fixture.bed.id))
        let plantingTask = fixture.task(
            title: "planting", target: .planting(fixture.planting.id))
        for task in [gardenTask, bedTask, plantingTask] {
            try fixture.tasks.insert(task)
        }
        #expect(
            try fixture.tasks.tasks(for: .garden(fixture.garden.id)).map(\.title) == ["garden"])
        #expect(try fixture.tasks.tasks(for: .bed(fixture.bed.id)).map(\.title) == ["bed"])
        #expect(
            try fixture.tasks.tasks(for: .planting(fixture.planting.id)).map(\.title)
                == ["planting"])
        #expect(try fixture.tasks.tasks(for: .bed(fixture.otherBed.id)).isEmpty)
    }
}
