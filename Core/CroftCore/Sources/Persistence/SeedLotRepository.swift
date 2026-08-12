import Domain
import GRDB
import Graph

public struct SeedLotRepository: Sendable {
    private let writer: any DatabaseWriter

    public init(_ database: AppDatabase) {
        writer = database.writer
    }

    public func insert(_ lot: SeedLot) throws {
        let record = SeedLotRecord(lot)
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            try GraphStore.register(record.cultivarRef, in: db)
            try GraphStore.relate(from: record.entityRef, .lotOf, to: record.cultivarRef, in: db)
        }
    }

    public func update(_ lot: SeedLot) throws {
        let record = SeedLotRecord(lot)
        try writer.write { db in
            try record.update(db)
            let edges = try GraphStore.outgoing(from: record.id, via: .lotOf, in: db)
            guard edges.map(\.target.id) != [record.cultivarID] else {
                return
            }
            for edge in edges {
                try GraphStore.unrelate(edgeID: edge.id, in: db)
            }
            try GraphStore.register(record.cultivarRef, in: db)
            try GraphStore.relate(from: record.entityRef, .lotOf, to: record.cultivarRef, in: db)
        }
    }

    public func fetch(id: SeedLot.ID) throws -> SeedLot? {
        try writer.read { db in
            try SeedLotRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [SeedLot] {
        try writer.read { db in
            try SeedLotRecord
                .order(Column("acquired_on").desc, Column("id"))
                .fetchAll(db)
                .map { $0.model() }
        }
    }

    public func lots(ofCultivar cultivarID: Cultivar.ID) throws -> [SeedLot] {
        try writer.read { db in
            try SeedLotRecord
                .filter(Column("cultivar_id") == cultivarID.rawValue)
                .order(Column("acquired_on").desc, Column("id"))
                .fetchAll(db)
                .map { $0.model() }
        }
    }

    @discardableResult
    public func delete(id: SeedLot.ID) throws -> Bool {
        try writer.write { db in
            try GraphStore.deleteEntity(id.rawValue, in: db)
            return try SeedLotRecord.deleteOne(db, key: id.rawValue)
        }
    }
}
