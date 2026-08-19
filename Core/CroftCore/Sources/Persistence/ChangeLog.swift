import Foundation
import GRDB

public enum ChangeKind: String, CaseIterable, Codable, Hashable, Sendable {
    case property
    case garden
    case growingArea = "growing_area"
    case bed
    case plantFamily = "plant_family"
    case genus
    case species
    case cultivar
    case pest
    case disease
    case pathogen
    case environmentalCondition = "environmental_condition"
    case seedLot = "seed_lot"
    case starterBatch = "starter_batch"
    case planting
    case observation
    case observationPhoto = "observation_photo"
    case harvest
    case task
    case dailyWeather = "daily_weather"
}

public enum ChangeOperation: String, CaseIterable, Codable, Hashable, Sendable {
    case create
    case update
    case delete
}

public struct ChangeRecord: Equatable, Sendable {
    public let sequence: Int64
    public let kind: ChangeKind
    public let entityID: String
    public let operation: ChangeOperation
    public let changedAt: Date

    public init(
        sequence: Int64,
        kind: ChangeKind,
        entityID: String,
        operation: ChangeOperation,
        changedAt: Date
    ) {
        self.sequence = sequence
        self.kind = kind
        self.entityID = entityID
        self.operation = operation
        self.changedAt = changedAt
    }
}

struct ChangeLogger: Sendable {
    let enabled: Bool

    init(_ database: AppDatabase) {
        enabled = database.recordsChanges
    }

    func record(
        _ kind: ChangeKind,
        _ entityID: String,
        _ operation: ChangeOperation,
        in db: Database,
        at date: Date = Date()
    ) throws {
        guard enabled else {
            return
        }
        try db.execute(
            sql: """
                INSERT INTO change_log (entity_kind, entity_id, operation, changed_at)
                VALUES (?, ?, ?, ?)
                """,
            arguments: [kind.rawValue, entityID, operation.rawValue, date]
        )
    }
}

public struct ChangeLogRepository: Sendable {
    private let writer: any DatabaseWriter

    public init(_ database: AppDatabase) {
        writer = database.writer
    }

    public func all() throws -> [ChangeRecord] {
        try writer.read { db in
            let rows = try Row.fetchAll(
                db, sql: "SELECT * FROM change_log ORDER BY sequence")
            let decoder = TaxonomyRowDecoder(table: "change_log")
            return try rows.map { row in
                ChangeRecord(
                    sequence: row["sequence"],
                    kind: try decoder.enumValue(
                        ChangeKind.self, from: row["entity_kind"] as String,
                        column: "entity_kind"),
                    entityID: row["entity_id"],
                    operation: try decoder.enumValue(
                        ChangeOperation.self, from: row["operation"] as String,
                        column: "operation"),
                    changedAt: row["changed_at"]
                )
            }
        }
    }

    public func count() throws -> Int {
        try writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM change_log") ?? 0
        }
    }

    public func changes(for kind: ChangeKind, entityID: String) throws -> [ChangeRecord] {
        try all().filter { $0.kind == kind && $0.entityID == entityID }
    }
}
