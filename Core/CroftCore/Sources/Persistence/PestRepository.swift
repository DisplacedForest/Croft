import Domain
import GRDB
import Graph

public enum PestError: Error, Hashable {
    case unknownOrganismType(String)
}

public struct PestRepository: Sendable {
    private let writer: any DatabaseWriter
    private let changes: ChangeLogger

    public init(_ database: AppDatabase) {
        writer = database.writer
        changes = ChangeLogger(database)
    }

    public func insert(_ pest: Pest) throws {
        let record = try PestRecord(pest)
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            try changes.record(.pest, record.id, .create, in: db)
        }
    }

    public func update(_ pest: Pest) throws {
        let record = try PestRecord(pest)
        try writer.write { db in
            try record.update(db)
            try changes.record(.pest, record.id, .update, in: db)
        }
    }

    public func apply(_ pest: Pest) throws {
        if try fetch(id: pest.id) != nil {
            try update(pest)
        } else {
            try insert(pest)
        }
    }

    public func fetch(id: Pest.ID) throws -> Pest? {
        try writer.read { db in
            try PestRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [Pest] {
        try writer.read { db in
            try PestRecord
                .order(Column("common_name"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    @discardableResult
    public func delete(id: Pest.ID) throws -> Bool {
        try writer.write { db in
            try GraphStore.deleteEntity(id.rawValue, in: db)
            let removed = try PestRecord.deleteOne(db, key: id.rawValue)
            if removed {
                try changes.record(.pest, id.rawValue, .delete, in: db)
            }
            return removed
        }
    }
}
