import Domain
import GRDB

public struct CultivarRepository: Sendable {
    private let writer: any DatabaseWriter

    public init(_ database: AppDatabase) {
        writer = database.writer
    }

    public func insert(_ cultivar: Cultivar) throws {
        let record = try CultivarRecord(cultivar)
        try writer.write { try record.insert($0) }
    }

    public func update(_ cultivar: Cultivar) throws {
        let record = try CultivarRecord(cultivar)
        try writer.write { try record.update($0) }
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
            try CultivarRecord.deleteOne(db, key: id.rawValue)
        }
    }
}
