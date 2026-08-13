import Domain
import Foundation
import GRDB
import Graph

public enum GardenTaskError: Error, Hashable {
    case taskNotFound(String)
    case malformedType(String)
    case malformedCompletion(String)
    case malformedTarget(String)
}

public struct GardenTaskRepository: Sendable {
    private let writer: any DatabaseWriter

    public init(_ database: AppDatabase) {
        writer = database.writer
    }

    public func insert(_ task: GardenTask) throws {
        let record = GardenTaskRecord(task)
        let target = try record.targetRef()
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            guard let target else {
                return
            }
            try GraphStore.register(target, in: db)
            try GraphStore.relate(from: record.entityRef, .taskFor, to: target, in: db)
        }
    }

    public func update(_ task: GardenTask) throws {
        let record = GardenTaskRecord(task)
        let target = try record.targetRef()
        try writer.write { db in
            guard try GardenTaskRecord.fetchOne(db, key: record.id) != nil else {
                throw GardenTaskError.taskNotFound(record.id)
            }
            try record.update(db)
            try repoint(.taskFor, of: record.entityRef, to: target, in: db)
        }
    }

    public func complete(id: GardenTask.ID, on date: Date) throws {
        try setCompletion(id: id, completed: true, on: date)
    }

    public func reopen(id: GardenTask.ID) throws {
        try setCompletion(id: id, completed: false, on: nil)
    }

    public func fetch(id: GardenTask.ID) throws -> GardenTask? {
        try writer.read { db in
            try GardenTaskRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [GardenTask] {
        try writer.read { db in
            try Self.ordered(GardenTaskRecord.all()).fetchAll(db).map { try $0.model() }
        }
    }

    public func openTasks() throws -> [GardenTask] {
        try writer.read { db in
            try Self.ordered(GardenTaskRecord.filter(Column("completed") == false))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func overdueTasks(asOf date: Date) throws -> [GardenTask] {
        try writer.read { db in
            try Self.ordered(
                GardenTaskRecord
                    .filter(Column("completed") == false)
                    .filter(Column("due_on") != nil)
                    .filter(Column("due_on") < date)
            )
            .fetchAll(db)
            .map { try $0.model() }
        }
    }

    public func tasks(for target: GardenTaskTarget) throws -> [GardenTask] {
        try writer.read { db in
            try Self.ordered(
                GardenTaskRecord.filter(Self.column(for: target) == Self.identifier(of: target))
            )
            .fetchAll(db)
            .map { try $0.model() }
        }
    }

    @discardableResult
    public func delete(id: GardenTask.ID) throws -> Bool {
        try writer.write { db in
            try GraphStore.deleteEntity(id.rawValue, in: db)
            return try GardenTaskRecord.deleteOne(db, key: id.rawValue)
        }
    }

    private func setCompletion(id: GardenTask.ID, completed: Bool, on date: Date?) throws {
        try writer.write { db in
            guard var record = try GardenTaskRecord.fetchOne(db, key: id.rawValue) else {
                throw GardenTaskError.taskNotFound(id.rawValue)
            }
            record.completed = completed
            record.completedOn = date
            try record.update(db)
        }
    }

    private static func ordered(
        _ request: QueryInterfaceRequest<GardenTaskRecord>
    ) -> QueryInterfaceRequest<GardenTaskRecord> {
        request.order(Column("due_on") == nil, Column("due_on"), Column("id"))
    }

    private static func column(for target: GardenTaskTarget) -> Column {
        switch target {
        case .garden:
            Column("garden_id")
        case .bed:
            Column("bed_id")
        case .planting:
            Column("planting_id")
        }
    }

    private static func identifier(of target: GardenTaskTarget) -> String {
        switch target {
        case .garden(let garden):
            garden.rawValue
        case .bed(let bed):
            bed.rawValue
        case .planting(let planting):
            planting.rawValue
        }
    }

    private func repoint(
        _ type: RelationshipType,
        of entity: EntityRef,
        to target: EntityRef?,
        in db: Database
    ) throws {
        let edges = try GraphStore.outgoing(from: entity.id, via: type, in: db)
        guard edges.map(\.target.id) != target.map({ [$0.id] }) ?? [] else {
            return
        }
        for edge in edges {
            try GraphStore.unrelate(edgeID: edge.id, in: db)
        }
        guard let target else {
            return
        }
        try GraphStore.register(target, in: db)
        try GraphStore.relate(from: entity, type, to: target, in: db)
    }
}
