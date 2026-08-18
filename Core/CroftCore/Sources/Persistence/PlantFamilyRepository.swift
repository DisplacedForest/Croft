import Domain
import GRDB

public struct PlantFamilyRepository: Sendable {
    private let writer: any DatabaseWriter
    private let changes: ChangeLogger

    public init(_ database: AppDatabase) {
        writer = database.writer
        changes = ChangeLogger(database)
    }

    public func insert(_ family: PlantFamily) throws {
        let record = try PlantFamilyRecord(family)
        try writer.write { db in
            try record.insert(db)
            try changes.record(.plantFamily, record.id, .create, in: db)
        }
    }

    public func update(_ family: PlantFamily) throws {
        let record = try PlantFamilyRecord(family)
        try writer.write { db in
            try record.update(db)
            try changes.record(.plantFamily, record.id, .update, in: db)
        }
    }

    public func apply(_ family: PlantFamily) throws {
        if try fetch(id: family.id) != nil {
            try update(family)
        } else {
            try insert(family)
        }
    }

    public func fetch(id: PlantFamily.ID) throws -> PlantFamily? {
        try writer.read { db in
            try PlantFamilyRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [PlantFamily] {
        try writer.read { db in
            try PlantFamilyRecord
                .order(Column("name"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    @discardableResult
    public func delete(id: PlantFamily.ID) throws -> Bool {
        try writer.write { db in
            let removed = try PlantFamilyRecord.deleteOne(db, key: id.rawValue)
            if removed {
                try changes.record(.plantFamily, id.rawValue, .delete, in: db)
            }
            return removed
        }
    }
}
