import Domain
import GRDB
import Graph

public struct StarterBatchRepository: Sendable {
    private let writer: any DatabaseWriter

    public init(_ database: AppDatabase) {
        writer = database.writer
    }

    public func insert(_ batch: StarterBatch) throws {
        let record = StarterBatchRecord(batch)
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            try GraphStore.relate(from: record.entityRef, .sownFrom, to: record.seedLotRef, in: db)
        }
    }

    public func update(_ batch: StarterBatch) throws {
        let record = StarterBatchRecord(batch)
        try writer.write { db in
            try record.update(db)
            let edges = try GraphStore.outgoing(from: record.id, via: .sownFrom, in: db)
            guard edges.map(\.target.id) != [record.seedLotID] else {
                return
            }
            for edge in edges {
                try GraphStore.unrelate(edgeID: edge.id, in: db)
            }
            try GraphStore.relate(from: record.entityRef, .sownFrom, to: record.seedLotRef, in: db)
        }
    }

    public func fetch(id: StarterBatch.ID) throws -> StarterBatch? {
        try writer.read { db in
            try StarterBatchRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [StarterBatch] {
        try writer.read { db in
            try StarterBatchRecord
                .order(Column("sown_on").desc, Column("id"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func batches(ofSeedLot seedLotID: SeedLot.ID) throws -> [StarterBatch] {
        try writer.read { db in
            try StarterBatchRecord
                .filter(Column("seed_lot_id") == seedLotID.rawValue)
                .order(Column("sown_on").desc, Column("id"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    @discardableResult
    public func delete(id: StarterBatch.ID) throws -> Bool {
        try writer.write { db in
            try GraphStore.deleteEntity(id.rawValue, in: db)
            return try StarterBatchRecord.deleteOne(db, key: id.rawValue)
        }
    }
}
