import Domain
import GRDB
import Graph

public enum PlantingError: Error, Hashable {
    case plantingNotFound(String)
    case invalidStatusTransition(from: PlantingStatus, requested: PlantingStatus)
    case malformedIdentity(String)
    case malformedSource(String)
}

public struct PlantingRepository: Sendable {
    private static let allowedTransitions: [PlantingStatus: Set<PlantingStatus>] = [
        .planned: [.active, .failed],
        .active: [.finished, .failed],
        .finished: [],
        .failed: [],
    ]

    private let writer: any DatabaseWriter

    public init(_ database: AppDatabase) {
        writer = database.writer
    }

    public func insert(_ planting: Planting) throws {
        let record = PlantingRecord(planting)
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            try GraphStore.register(record.identityRef, in: db)
            try GraphStore.register(record.bedRef, in: db)
            try GraphStore.relate(
                from: record.entityRef, .instanceOf, to: record.identityRef, in: db)
            try GraphStore.relate(from: record.entityRef, .locatedIn, to: record.bedRef, in: db)
            if let sourceRef = record.sourceRef {
                try GraphStore.register(sourceRef, in: db)
                try GraphStore.relate(from: record.entityRef, .plantedFrom, to: sourceRef, in: db)
            }
        }
    }

    public func update(_ planting: Planting) throws {
        let record = PlantingRecord(planting)
        try writer.write { db in
            guard let stored = try PlantingRecord.fetchOne(db, key: record.id) else {
                throw PlantingError.plantingNotFound(record.id)
            }
            let current = try stored.model().status
            if current != planting.status {
                guard Self.allowedTransitions[current]?.contains(planting.status) == true else {
                    throw PlantingError.invalidStatusTransition(
                        from: current, requested: planting.status)
                }
            }
            try record.update(db)
            try repoint(.instanceOf, of: record.entityRef, to: record.identityRef, in: db)
            try repoint(.locatedIn, of: record.entityRef, to: record.bedRef, in: db)
            try repoint(.plantedFrom, of: record.entityRef, to: record.sourceRef, in: db)
        }
    }

    public func fetch(id: Planting.ID) throws -> Planting? {
        try writer.read { db in
            try PlantingRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [Planting] {
        try writer.read { db in
            try PlantingRecord
                .order(Column("planted_on").desc, Column("id"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func plantings(inBed bedID: Bed.ID) throws -> [Planting] {
        try writer.read { db in
            try PlantingRecord
                .filter(Column("bed_id") == bedID.rawValue)
                .order(Column("planted_on").desc, Column("id"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func activePlantings(inBed bedID: Bed.ID) throws -> [Planting] {
        try writer.read { db in
            try PlantingRecord
                .filter(Column("bed_id") == bedID.rawValue)
                .filter(Column("status") == PlantingStatus.active.rawValue)
                .order(Column("planted_on").desc, Column("id"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func plantings(of identity: PlantIdentity) throws -> [Planting] {
        try writer.read { db in
            let request =
                switch identity {
                case .cultivar(let id):
                    PlantingRecord.filter(Column("cultivar_id") == id.rawValue)
                case .species(let id):
                    PlantingRecord.filter(Column("species_id") == id.rawValue)
                }
            return
                try request
                .order(Column("planted_on").desc, Column("id"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func plantings(inGarden gardenID: Garden.ID) throws -> [Planting] {
        try writer.read { db in
            try PlantingRecord
                .fetchAll(
                    db,
                    sql: """
                        SELECT p.* FROM planting p
                        JOIN relationship bed_edge
                            ON bed_edge.from_entity_id = p.bed_id
                            AND bed_edge.relationship_type = 'LOCATED_IN'
                        WHERE bed_edge.to_entity_id = :garden
                            OR bed_edge.to_entity_id IN (
                                SELECT from_entity_id FROM relationship
                                WHERE relationship_type = 'LOCATED_IN'
                                AND to_entity_id = :garden
                            )
                        ORDER BY p.planted_on DESC, p.id
                        """,
                    arguments: ["garden": gardenID.rawValue]
                )
                .map { try $0.model() }
        }
    }

    @discardableResult
    public func delete(id: Planting.ID) throws -> Bool {
        try writer.write { db in
            try GraphStore.deleteEntity(id.rawValue, in: db)
            return try PlantingRecord.deleteOne(db, key: id.rawValue)
        }
    }

    private func repoint(
        _ type: RelationshipType,
        of entity: EntityRef,
        to target: EntityRef?,
        in db: Database
    ) throws {
        let edges = try GraphStore.outgoing(from: entity.id, via: type, in: db)
        guard edges.map(\.target.id) != target.map({ [$0.id] }) ?? [] else {
            return
        }
        for edge in edges {
            try GraphStore.unrelate(edgeID: edge.id, in: db)
        }
        guard let target else {
            return
        }
        try GraphStore.register(target, in: db)
        try GraphStore.relate(from: entity, type, to: target, in: db)
    }
}
