import Domain
import GRDB

public struct PlantFamilyRepository: Sendable {
    private let writer: any DatabaseWriter

    public init(_ database: AppDatabase) {
        writer = database.writer
    }

    public func insert(_ family: PlantFamily) throws {
        let record = try PlantFamilyRecord(family)
        try writer.write { try record.insert($0) }
    }

    public func update(_ family: PlantFamily) throws {
        let record = try PlantFamilyRecord(family)
        try writer.write { try record.update($0) }
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
            try PlantFamilyRecord.deleteOne(db, key: id.rawValue)
        }
    }
}
