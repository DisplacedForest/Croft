import Domain
import Foundation
import GRDB
import Graph

public enum ObservationError: Error, Hashable {
    case observationNotFound(String)
    case malformedTarget(String)
}

public struct ObservationRepository: Sendable {
    private let writer: any DatabaseWriter
    private let photoStore: PhotoStore

    public init(_ database: AppDatabase, photos: PhotoStore) {
        writer = database.writer
        photoStore = photos
    }

    public func insert(_ observation: Observation) throws {
        let record = try ObservationRecord(observation)
        let target = try record.targetRef()
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            try GraphStore.register(target, in: db)
            try GraphStore.relate(from: record.entityRef, .observedOn, to: target, in: db)
        }
    }

    public func update(_ observation: Observation) throws {
        let record = try ObservationRecord(observation)
        let target = try record.targetRef()
        try writer.write { db in
            guard try ObservationRecord.fetchOne(db, key: record.id) != nil else {
                throw ObservationError.observationNotFound(record.id)
            }
            try record.update(db)
            try repoint(.observedOn, of: record.entityRef, to: target, in: db)
        }
    }

    public func fetch(id: Observation.ID) throws -> Observation? {
        try writer.read { db in
            try ObservationRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [Observation] {
        try writer.read { db in
            try ObservationRecord
                .order(Column("observed_at").desc, Column("id"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func observations(on target: ObservationTarget) throws -> [Observation] {
        try writer.read { db in
            try ObservationRecord
                .filter(Self.column(for: target) == Self.identifier(of: target))
                .order(Column("observed_at").desc, Column("id"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func recent(limit: Int) throws -> [Observation] {
        try writer.read { db in
            try ObservationRecord
                .order(Column("observed_at").desc, Column("id"))
                .limit(limit)
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func addPhoto(_ data: Data, to id: Observation.ID) throws -> String {
        guard try exists(id) else {
            throw ObservationError.observationNotFound(id.rawValue)
        }
        let relativePath = try photoStore.add(data, forObservation: id)
        let record = ObservationPhotoRecord(
            id: UUID().uuidString,
            observationID: id.rawValue,
            relativePath: relativePath,
            createdAt: Date()
        )
        do {
            try writer.write { try record.insert($0) }
        } catch {
            try? FileManager.default.removeItem(
                at: photoStore.url(forRelativePath: relativePath))
            throw error
        }
        return relativePath
    }

    public func photos(for id: Observation.ID) throws -> [String] {
        try writer.read { db in
            try ObservationPhotoRecord
                .filter(Column("observation_id") == id.rawValue)
                .order(Column("created_at"), Column("id"))
                .fetchAll(db)
                .map(\.relativePath)
        }
    }

    @discardableResult
    public func delete(id: Observation.ID) throws -> Bool {
        let deleted = try writer.write { db in
            try GraphStore.deleteEntity(id.rawValue, in: db)
            return try ObservationRecord.deleteOne(db, key: id.rawValue)
        }
        if deleted {
            try photoStore.removePhotos(forObservation: id)
        }
        return deleted
    }

    public func sweepOrphanedPhotos() throws {
        let ids = try writer.read { db in
            try String.fetchAll(db, sql: "SELECT id FROM observation")
        }
        try photoStore.sweepOrphans(keeping: Set(ids))
    }

    private static func column(for target: ObservationTarget) -> Column {
        switch target {
        case .planting:
            Column("planting_id")
        case .plant(.cultivar):
            Column("cultivar_id")
        case .plant(.species):
            Column("species_id")
        case .bed:
            Column("bed_id")
        case .garden:
            Column("garden_id")
        }
    }

    private static func identifier(of target: ObservationTarget) -> String {
        switch target {
        case .planting(let planting):
            planting.rawValue
        case .plant(.cultivar(let cultivar)):
            cultivar.rawValue
        case .plant(.species(let species)):
            species.rawValue
        case .bed(let bed):
            bed.rawValue
        case .garden(let garden):
            garden.rawValue
        }
    }

    private func exists(_ id: Observation.ID) throws -> Bool {
        try writer.read { db in
            try ObservationRecord.fetchOne(db, key: id.rawValue) != nil
        }
    }

    private func repoint(
        _ type: RelationshipType,
        of entity: EntityRef,
        to target: EntityRef,
        in db: Database
    ) throws {
        let edges = try GraphStore.outgoing(from: entity.id, via: type, in: db)
        guard edges.map(\.target.id) != [target.id] else {
            return
        }
        for edge in edges {
            try GraphStore.unrelate(edgeID: edge.id, in: db)
        }
        try GraphStore.register(target, in: db)
        try GraphStore.relate(from: entity, type, to: target, in: db)
    }
}
