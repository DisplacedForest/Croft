import Domain
import Foundation
import GRDB
import Graph

public enum HarvestError: Error, Hashable {
    case harvestNotFound(String)
    case malformedUnit(String)
}

public struct HarvestTotal: Equatable, Sendable {
    public let unit: HarvestUnit
    public let customUnit: String?
    public let total: Double
    public let count: Int

    public init(unit: HarvestUnit, customUnit: String?, total: Double, count: Int) {
        self.unit = unit
        self.customUnit = customUnit
        self.total = total
        self.count = count
    }
}

public struct HarvestRepository: Sendable {
    private let writer: any DatabaseWriter

    public init(_ database: AppDatabase) {
        writer = database.writer
    }

    public func insert(_ harvest: Harvest) throws {
        let record = HarvestRecord(harvest)
        try writer.write { db in
            try record.insert(db)
            try GraphStore.register(record.entityRef, in: db)
            try GraphStore.register(record.plantingRef, in: db)
            try GraphStore.relate(
                from: record.entityRef, .harvestedFrom, to: record.plantingRef, in: db)
        }
    }

    public func update(_ harvest: Harvest) throws {
        let record = HarvestRecord(harvest)
        try writer.write { db in
            guard try HarvestRecord.fetchOne(db, key: record.id) != nil else {
                throw HarvestError.harvestNotFound(record.id)
            }
            try record.update(db)
            try repoint(.harvestedFrom, of: record.entityRef, to: record.plantingRef, in: db)
        }
    }

    public func fetch(id: Harvest.ID) throws -> Harvest? {
        try writer.read { db in
            try HarvestRecord.fetchOne(db, key: id.rawValue)?.model()
        }
    }

    public func fetchAll() throws -> [Harvest] {
        try writer.read { db in
            try HarvestRecord
                .order(Column("harvested_on").desc, Column("id"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func harvests(forPlanting plantingID: Planting.ID) throws -> [Harvest] {
        try writer.read { db in
            try HarvestRecord
                .filter(Column("planting_id") == plantingID.rawValue)
                .order(Column("harvested_on").desc, Column("id"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func recent(limit: Int) throws -> [Harvest] {
        try writer.read { db in
            try HarvestRecord
                .order(Column("harvested_on").desc, Column("id"))
                .limit(limit)
                .fetchAll(db)
                .map { try $0.model() }
        }
    }

    public func totals(forPlanting plantingID: Planting.ID) throws -> [HarvestTotal] {
        try writer.read { db in
            try Self.totals(
                try Row.fetchAll(
                    db,
                    sql: """
                        SELECT unit, custom_unit, SUM(quantity) AS total,
                               COUNT(*) AS count, MIN(id) AS sample_id
                        FROM harvest
                        WHERE planting_id = :planting
                        GROUP BY unit, custom_unit
                        ORDER BY unit, custom_unit
                        """,
                    arguments: ["planting": plantingID.rawValue]
                )
            )
        }
    }

    public func totals(of identity: PlantIdentity) throws -> [HarvestTotal] {
        let column =
            switch identity {
            case .cultivar: "cultivar_id"
            case .species: "species_id"
            }
        let value =
            switch identity {
            case .cultivar(let id): id.rawValue
            case .species(let id): id.rawValue
            }
        return try writer.read { db in
            try Self.totals(
                try Row.fetchAll(
                    db,
                    sql: """
                        SELECT h.unit AS unit, h.custom_unit AS custom_unit,
                               SUM(h.quantity) AS total, COUNT(*) AS count,
                               MIN(h.id) AS sample_id
                        FROM harvest h
                        JOIN planting p ON p.id = h.planting_id
                        WHERE p.\(column) = :identity
                        GROUP BY h.unit, h.custom_unit
                        ORDER BY h.unit, h.custom_unit
                        """,
                    arguments: ["identity": value]
                )
            )
        }
    }

    @discardableResult
    public func delete(id: Harvest.ID) throws -> Bool {
        try writer.write { db in
            try GraphStore.deleteEntity(id.rawValue, in: db)
            return try HarvestRecord.deleteOne(db, key: id.rawValue)
        }
    }

    private static func totals(_ rows: [Row]) throws -> [HarvestTotal] {
        try rows.map { row in
            HarvestTotal(
                unit: try HarvestRecord.decodeUnit(
                    row["unit"],
                    pairedWith: row["custom_unit"],
                    rowID: row["sample_id"]
                ),
                customUnit: row["custom_unit"],
                total: row["total"],
                count: row["count"]
            )
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
