import Domain
import Foundation
import GRDB
import Graph

public enum HarvestError: Error, Hashable {
    case harvestNotFound(String)
    case malformedUnit(String)
}

public struct HarvestTotal: Equatable, Sendable {
    public enum Kind: Equatable, Hashable, Sendable {
        case family(UnitFamily)
        case custom(String)
    }

    public let kind: Kind
    public let total: Double
    public let count: Int

    public init(kind: Kind, total: Double, count: Int) {
        self.kind = kind
        self.total = total
        self.count = count
    }
}

public struct HarvestRepository: Sendable {
    private let writer: any DatabaseWriter

    private static let totalsSelection = """
        SELECT h.yield_family AS family, h.custom_unit AS custom_unit,
               SUM(h.yield_amount) AS total, COUNT(*) AS count,
               MIN(h.id) AS sample_id
        FROM harvest h
        """

    private static let totalsGrouping = """
        GROUP BY h.yield_family, h.custom_unit
        ORDER BY h.yield_family IS NULL, h.yield_family, h.custom_unit
        """

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
        try totalsQuery(
            clauses: "WHERE h.planting_id = :scope",
            argument: plantingID.rawValue
        )
    }

    public func totals(forBed bedID: Bed.ID) throws -> [HarvestTotal] {
        try totalsQuery(
            clauses: """
                JOIN planting p ON p.id = h.planting_id
                WHERE p.bed_id = :scope
                """,
            argument: bedID.rawValue
        )
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
        return try totalsQuery(
            clauses: """
                JOIN planting p ON p.id = h.planting_id
                WHERE p.\(column) = :scope
                """,
            argument: value
        )
    }

    public func totals(inSeason year: Int) throws -> [HarvestTotal] {
        try totalsQuery(
            clauses: "WHERE CAST(strftime('%Y', h.harvested_on) AS INTEGER) = :scope",
            argument: year
        )
    }

    public func firstHarvestDate(forPlanting plantingID: Planting.ID) throws -> Date? {
        try writer.read { db in
            try Date.fetchOne(
                db,
                sql: "SELECT MIN(harvested_on) FROM harvest WHERE planting_id = :planting",
                arguments: ["planting": plantingID.rawValue]
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

    private func totalsQuery(
        clauses: String,
        argument: some DatabaseValueConvertible & Sendable
    ) throws -> [HarvestTotal] {
        try writer.read { db in
            try Self.totals(
                try Row.fetchAll(
                    db,
                    sql: [Self.totalsSelection, clauses, Self.totalsGrouping]
                        .joined(separator: "\n"),
                    arguments: ["scope": argument]
                )
            )
        }
    }

    private static func totals(_ rows: [Row]) throws -> [HarvestTotal] {
        try rows.map { row in
            let kind: HarvestTotal.Kind
            let family: String? = row["family"]
            let customUnit: String? = row["custom_unit"]
            switch (family, customUnit) {
            case (.some(let family), nil):
                guard let parsed = UnitFamily(rawValue: family) else {
                    throw HarvestError.malformedUnit(row["sample_id"])
                }
                kind = .family(parsed)
            case (nil, .some(let customUnit)):
                kind = .custom(customUnit)
            default:
                throw HarvestError.malformedUnit(row["sample_id"])
            }
            return HarvestTotal(kind: kind, total: row["total"], count: row["count"])
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
