import Domain
import GRDB

public struct GenusRepository: Sendable {
    private let writer: any DatabaseWriter
    private let changes: ChangeLogger

    public init(_ database: AppDatabase) {
        writer = database.writer
        changes = ChangeLogger(database)
    }

    public func insert(_ genus: Genus) throws {
        let record = GenusRecord(genus)
        try writer.write { db in
            try record.insert(db)
            try changes.record(.genus, record.id, .create, in: db)
        }
    }

    public func update(_ genus: Genus) throws {
        let record = GenusRecord(genus)
        try writer.write { db in
            try record.update(db)
            try changes.record(.genus, record.id, .update, in: db)
        }
    }

    public func apply(_ genus: Genus) throws {
        if try fetch(id: genus.id) != nil {
            try update(genus)
        } else {
            try insert(genus)
        }
    }

    public func fetch(id: Genus.ID) throws -> Genus? {
        try writer.read { db in
            try GenusRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [Genus] {
        try writer.read { db in
            try GenusRecord
                .order(Column("name"))
                .fetchAll(db)
                .map { $0.model() }
        }
    }

    public func genera(inFamily familyID: PlantFamily.ID) throws -> [Genus] {
        try writer.read { db in
            try GenusRecord
                .filter(Column("family_id") == familyID.rawValue)
                .order(Column("name"))
                .fetchAll(db)
                .map { $0.model() }
        }
    }

    @discardableResult
    public func delete(id: Genus.ID) throws -> Bool {
        try writer.write { db in
            let removed = try GenusRecord.deleteOne(db, key: id.rawValue)
            if removed {
                try changes.record(.genus, id.rawValue, .delete, in: db)
            }
            return removed
        }
    }
}
