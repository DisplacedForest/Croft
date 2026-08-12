import Domain
import GRDB
import Graph

public struct DiseaseRepository: Sendable {
    private let writer: any DatabaseWriter

    public init(_ database: AppDatabase) {
        writer = database.writer
    }

    public func insert(_ disease: Disease) throws {
        let record = try DiseaseRecord(disease)
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
        }
    }

    public func update(_ disease: Disease) throws {
        let record = try DiseaseRecord(disease)
        try writer.write { try record.update($0) }
    }

    public func fetch(id: Disease.ID) throws -> Disease? {
        try writer.read { db in
            try DiseaseRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [Disease] {
        try writer.read { db in
            try DiseaseRecord
                .order(Column("name"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    @discardableResult
    public func delete(id: Disease.ID) throws -> Bool {
        try writer.write { db in
            try GraphStore.deleteEntity(id.rawValue, in: db)
            return try DiseaseRecord.deleteOne(db, key: id.rawValue)
        }
    }
}

public struct PathogenRepository: Sendable {
    private let writer: any DatabaseWriter

    public init(_ database: AppDatabase) {
        writer = database.writer
    }

    public func insert(_ pathogen: Pathogen) throws {
        let record = PathogenRecord(pathogen)
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
        }
    }

    public func update(_ pathogen: Pathogen) throws {
        let record = PathogenRecord(pathogen)
        try writer.write { try record.update($0) }
    }

    public func fetch(id: Pathogen.ID) throws -> Pathogen? {
        try writer.read { db in
            try PathogenRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [Pathogen] {
        try writer.read { db in
            try PathogenRecord
                .order(Column("name"))
                .fetchAll(db)
                .map { $0.model() }
        }
    }

    @discardableResult
    public func delete(id: Pathogen.ID) throws -> Bool {
        try writer.write { db in
            try GraphStore.deleteEntity(id.rawValue, in: db)
            return try PathogenRecord.deleteOne(db, key: id.rawValue)
        }
    }
}

public struct EnvironmentalConditionRepository: Sendable {
    private let writer: any DatabaseWriter

    public init(_ database: AppDatabase) {
        writer = database.writer
    }

    public func insert(_ condition: EnvironmentalCondition) throws {
        let record = EnvironmentalConditionRecord(condition)
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
        }
    }

    public func update(_ condition: EnvironmentalCondition) throws {
        let record = EnvironmentalConditionRecord(condition)
        try writer.write { try record.update($0) }
    }

    public func fetch(id: EnvironmentalCondition.ID) throws -> EnvironmentalCondition? {
        try writer.read { db in
            try EnvironmentalConditionRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [EnvironmentalCondition] {
        try writer.read { db in
            try EnvironmentalConditionRecord
                .order(Column("name"))
                .fetchAll(db)
                .map { $0.model() }
        }
    }

    @discardableResult
    public func delete(id: EnvironmentalCondition.ID) throws -> Bool {
        try writer.write { db in
            try GraphStore.deleteEntity(id.rawValue, in: db)
            return try EnvironmentalConditionRecord.deleteOne(db, key: id.rawValue)
        }
    }
}
