import Domain
import GRDB
import Graph

public struct CultivarRepository: Sendable {
    private let writer: any DatabaseWriter
    private let changes: ChangeLogger

    public init(_ database: AppDatabase) {
        writer = database.writer
        changes = ChangeLogger(database)
    }

    public func insert(_ cultivar: Cultivar) throws {
        let record = try CultivarRecord(cultivar)
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            try changes.record(.cultivar, record.id, .create, in: db)
        }
    }

    public func update(_ cultivar: Cultivar) throws {
        let record = try CultivarRecord(cultivar)
        try writer.write { db in
            try record.update(db)
            try changes.record(.cultivar, record.id, .update, in: db)
        }
    }

    public func apply(_ cultivar: Cultivar) throws {
        if try fetch(id: cultivar.id) != nil {
            try update(cultivar)
        } else {
            try insert(cultivar)
        }
    }

    public func fetch(id: Cultivar.ID) throws -> Cultivar? {
        try writer.read { db in
            try CultivarRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [Cultivar] {
        try writer.read { db in
            try CultivarRecord
                .order(Column("name"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func cultivars(ofSpecies speciesID: Species.ID) throws -> [Cultivar] {
        try writer.read { db in
            try CultivarRecord
                .filter(Column("species_id") == speciesID.rawValue)
                .order(Column("name"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    @discardableResult
    public func delete(id: Cultivar.ID) throws -> Bool {
        try writer.write { db in
            try GraphStore.deleteEntity(id.rawValue, in: db)
            let removed = try CultivarRecord.deleteOne(db, key: id.rawValue)
            if removed {
                try changes.record(.cultivar, id.rawValue, .delete, in: db)
            }
            return removed
        }
    }
}
