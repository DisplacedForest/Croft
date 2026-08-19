import Domain
import GRDB
import Graph

public struct DiseaseRepository: Sendable {
    private let writer: any DatabaseWriter
    private let changes: ChangeLogger

    public init(_ database: AppDatabase) {
        writer = database.writer
        changes = ChangeLogger(database)
    }

    public func insert(_ disease: Disease) throws {
        let record = try DiseaseRecord(disease)
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            try changes.record(.disease, record.id, .create, in: db)
        }
    }

    public func update(_ disease: Disease) throws {
        let record = try DiseaseRecord(disease)
        try writer.write { db in
            try record.update(db)
            try changes.record(.disease, record.id, .update, in: db)
        }
    }

    public func apply(_ disease: Disease) throws {
        if try fetch(id: disease.id) != nil {
            try update(disease)
        } else {
            try insert(disease)
        }
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
            let removed = try DiseaseRecord.deleteOne(db, key: id.rawValue)
            if removed {
                try changes.record(.disease, id.rawValue, .delete, in: db)
            }
            return removed
        }
    }
}

public struct PathogenRepository: Sendable {
    private let writer: any DatabaseWriter
    private let changes: ChangeLogger

    public init(_ database: AppDatabase) {
        writer = database.writer
        changes = ChangeLogger(database)
    }

    public func insert(_ pathogen: Pathogen) throws {
        let record = PathogenRecord(pathogen)
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            try changes.record(.pathogen, record.id, .create, in: db)
        }
    }

    public func update(_ pathogen: Pathogen) throws {
        let record = PathogenRecord(pathogen)
        try writer.write { db in
            try record.update(db)
            try changes.record(.pathogen, record.id, .update, in: db)
        }
    }

    public func apply(_ pathogen: Pathogen) throws {
        if try fetch(id: pathogen.id) != nil {
            try update(pathogen)
        } else {
            try insert(pathogen)
        }
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
            let removed = try PathogenRecord.deleteOne(db, key: id.rawValue)
            if removed {
                try changes.record(.pathogen, id.rawValue, .delete, in: db)
            }
            return removed
        }
    }
}

public struct EnvironmentalConditionRepository: Sendable {
    private let writer: any DatabaseWriter
    private let changes: ChangeLogger

    public init(_ database: AppDatabase) {
        writer = database.writer
        changes = ChangeLogger(database)
    }

    public func insert(_ condition: EnvironmentalCondition) throws {
        let record = EnvironmentalConditionRecord(condition)
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            try changes.record(.environmentalCondition, record.id, .create, in: db)
        }
    }

    public func update(_ condition: EnvironmentalCondition) throws {
        let record = EnvironmentalConditionRecord(condition)
        try writer.write { db in
            try record.update(db)
            try changes.record(.environmentalCondition, record.id, .update, in: db)
        }
    }

    public func apply(_ condition: EnvironmentalCondition) throws {
        if try fetch(id: condition.id) != nil {
            try update(condition)
        } else {
            try insert(condition)
        }
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
            let removed = try EnvironmentalConditionRecord.deleteOne(db, key: id.rawValue)
            if removed {
                try changes.record(.environmentalCondition, id.rawValue, .delete, in: db)
            }
            return removed
        }
    }
}
