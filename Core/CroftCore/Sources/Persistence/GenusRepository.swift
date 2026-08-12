import Domain
import GRDB

public struct GenusRepository: Sendable {
    private let writer: any DatabaseWriter

    public init(_ database: AppDatabase) {
        writer = database.writer
    }

    public func insert(_ genus: Genus) throws {
        let record = GenusRecord(genus)
        try writer.write { try record.insert($0) }
    }

    public func update(_ genus: Genus) throws {
        let record = GenusRecord(genus)
        try writer.write { try record.update($0) }
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
            try GenusRecord.deleteOne(db, key: id.rawValue)
        }
    }
}
