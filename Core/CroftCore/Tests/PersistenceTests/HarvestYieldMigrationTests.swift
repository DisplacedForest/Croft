import Domain
import Foundation
import GRDB
import Testing

@testable import Persistence

let harvestYieldIdentifier = "v018-harvest-yield"

private struct LegacyHarvestRow {
    let id: String
    let quantity: Double
    let unit: String
    var customUnit: String?
}

struct HarvestYieldMigrationTests {
    private static let legacyRows = [
        LegacyHarvestRow(id: "h-gram", quantity: 500, unit: "gram"),
        LegacyHarvestRow(id: "h-kilogram", quantity: 1.5, unit: "kilogram"),
        LegacyHarvestRow(id: "h-ounce", quantity: 8, unit: "ounce"),
        LegacyHarvestRow(id: "h-pound", quantity: 2, unit: "pound"),
        LegacyHarvestRow(id: "h-count", quantity: 3, unit: "count"),
        LegacyHarvestRow(id: "h-bunch", quantity: 4, unit: "bunch"),
        LegacyHarvestRow(id: "h-bunch-fractional", quantity: 2.5, unit: "bunch"),
        LegacyHarvestRow(id: "h-custom", quantity: 3.25, unit: "custom", customUnit: "half flat"),
    ]

    private func seededQueue() throws -> DatabaseQueue {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: harvestYieldIdentifier))
        try #require(index > 0)
        #expect(identifiers[index - 1] == lifecycleStageIdentifier)
        let queue = try MigrationHarness.database(through: identifiers[index - 1])
        try queue.write { db in
            try seedStructure(db)
            for row in Self.legacyRows {
                try db.execute(
                    sql: """
                        INSERT INTO harvest
                            (id, planting_id, harvested_on, quantity, unit,
                             custom_unit, quality, notes)
                        VALUES (?, 'pl1', '2024-07-03 12:00:00', ?, ?, ?, 'good', 'note')
                        """,
                    arguments: [row.id, row.quantity, row.unit, row.customUnit]
                )
                try db.execute(
                    sql: "INSERT INTO entity (id, entity_type) VALUES (?, 'harvest')",
                    arguments: [row.id]
                )
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES (?, ?, 'HARVESTED_FROM', 'pl1')
                        """,
                    arguments: ["edge-\(row.id)", row.id]
                )
            }
        }
        return queue
    }

    private func seedStructure(_ db: Database) throws {
        try db.execute(
            sql: """
                INSERT INTO plant_family (id, name) VALUES ('family:f', 'Solanaceae')
                """)
        try db.execute(
            sql: """
                INSERT INTO genus (id, family_id, name) VALUES ('genus:g', 'family:f', 'Solanum')
                """)
        try db.execute(
            sql: """
                INSERT INTO species (id, genus_id, scientific_name)
                VALUES ('species:s', 'genus:g', 'Solanum lycopersicum')
                """)
        try db.execute(
            sql: """
                INSERT INTO bed (id, name, kind) VALUES ('bed1', 'Long Bed', 'raised')
                """)
        try db.execute(
            sql: """
                INSERT INTO planting (id, species_id, bed_id, status)
                VALUES ('pl1', 'species:s', 'bed1', 'active')
                """)
        try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('pl1', 'planting')")
    }

    private func migratedRows() throws -> (queue: DatabaseQueue, rows: [String: Row]) {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let rows = try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM harvest ORDER BY id")
        }
        var byID: [String: Row] = [:]
        for row in rows {
            byID[row["id"]] = row
        }
        return (queue, byID)
    }

    @Test func massUnitsConvertToCanonicalGrams() throws {
        let (_, rows) = try migratedRows()
        let expectations: [String: Double] = [
            "h-gram": 500,
            "h-kilogram": 1500,
            "h-ounce": 226.796_185,
            "h-pound": 907.184_74,
        ]
        for (id, amount) in expectations {
            let row = try #require(rows[id])
            #expect(row["yield_amount"] == amount)
            #expect(row["yield_unit"] == String(id.dropFirst(2)))
            #expect(row["yield_family"] == "mass")
            #expect(row["custom_unit"] == DatabaseValue.null)
        }
    }

    @Test func wholeCountAndBunchRowsBecomeTheCountFamily() throws {
        let (_, rows) = try migratedRows()
        for (id, amount) in [("h-count", 3.0), ("h-bunch", 4.0)] {
            let row = try #require(rows[id])
            #expect(row["yield_amount"] == amount)
            #expect(row["yield_unit"] == "count")
            #expect(row["yield_family"] == "count")
            #expect(row["custom_unit"] == DatabaseValue.null)
        }
    }

    @Test func aFractionalBunchFallsBackToACustomLabel() throws {
        let (_, rows) = try migratedRows()
        let row = try #require(rows["h-bunch-fractional"])
        #expect(row["yield_amount"] == 2.5)
        #expect(row["yield_unit"] == "custom")
        #expect(row["yield_family"] == DatabaseValue.null)
        #expect(row["custom_unit"] == "bunch")
    }

    @Test func customRowsStayCustomAndUnconverted() throws {
        let (_, rows) = try migratedRows()
        let row = try #require(rows["h-custom"])
        #expect(row["yield_amount"] == 3.25)
        #expect(row["yield_unit"] == "custom")
        #expect(row["yield_family"] == DatabaseValue.null)
        #expect(row["custom_unit"] == "half flat")
    }

    @Test func noRowEdgeOrAttributeIsLost() throws {
        let (queue, rows) = try migratedRows()
        #expect(rows.count == 8)
        for row in rows.values {
            #expect(row["planting_id"] == "pl1")
            #expect(row["harvested_on"] == "2024-07-03 12:00:00")
            #expect(row["harvested_part"] == DatabaseValue.null)
            #expect(row["quality"] == "good")
            #expect(row["notes"] == "note")
        }
        let edges = try queue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT from_entity_id FROM relationship
                    WHERE relationship_type = 'HARVESTED_FROM' ORDER BY from_entity_id
                    """)
        }
        #expect(edges.map { $0["from_entity_id"] as String } == rows.keys.sorted())
    }

    @Test func theRestrictEdgeStillProtectsThePlanting() throws {
        let (queue, _) = try migratedRows()
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(sql: "DELETE FROM entity WHERE id = 'pl1'")
            }
        }
    }

    @Test func thePlantingIndexSurvivesTheRebuild() throws {
        let (queue, _) = try migratedRows()
        let indexes = try queue.read { db in
            try db.indexes(on: "harvest").map(\.name)
        }
        #expect(indexes.contains("harvest_on_planting_id"))
    }

    @Test func migratedRowsDecodeThroughTheRepository() throws {
        let (queue, _) = try migratedRows()
        let records = try queue.read { db in
            try HarvestRecord.fetchAll(db, sql: "SELECT * FROM harvest ORDER BY id")
        }
        let models = try records.map { try $0.model() }
        #expect(models.count == 8)
        let byID = Dictionary(uniqueKeysWithValues: models.map { ($0.id.rawValue, $0) })
        #expect(try byID["h-pound"]?.yield == measured(2, .pound))
        #expect(try byID["h-bunch"]?.yield == measured(4, .count))
        #expect(byID["h-bunch-fractional"]?.yield == .custom(amount: 2.5, label: "bunch"))
        #expect(byID["h-custom"]?.yield == .custom(amount: 3.25, label: "half flat"))
    }
}
