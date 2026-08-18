import Domain
import GRDB
import Graph

public struct SpeciesRepository: Sendable {
    private let writer: any DatabaseWriter
    private let changes: ChangeLogger

    public init(_ database: AppDatabase) {
        writer = database.writer
        changes = ChangeLogger(database)
    }

    public func insert(_ species: Species) throws {
        let record = try SpeciesRecord(species)
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            try changes.record(.species, record.id, .create, in: db)
        }
    }

    public func update(_ species: Species) throws {
        let record = try SpeciesRecord(species)
        try writer.write { db in
            try record.update(db)
            try changes.record(.species, record.id, .update, in: db)
        }
    }

    public func apply(_ species: Species) throws {
        if try fetch(id: species.id) != nil {
            try update(species)
        } else {
            try insert(species)
        }
    }

    public func fetch(id: Species.ID) throws -> Species? {
        try writer.read { db in
            try SpeciesRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [Species] {
        try writer.read { db in
            try SpeciesRecord
                .order(Column("scientific_name"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func species(inGenus genusID: Genus.ID) throws -> [Species] {
        try writer.read { db in
            try SpeciesRecord
                .filter(Column("genus_id") == genusID.rawValue)
                .order(Column("scientific_name"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    @discardableResult
    public func delete(id: Species.ID) throws -> Bool {
        try writer.write { db in
            try GraphStore.deleteEntity(id.rawValue, in: db)
            let removed = try SpeciesRecord.deleteOne(db, key: id.rawValue)
            if removed {
                try changes.record(.species, id.rawValue, .delete, in: db)
            }
            return removed
        }
    }
}
