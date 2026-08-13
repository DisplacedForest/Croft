import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

struct EdgeCardinalityMigrationTests {
    private let identifier = "v015-edge-cardinality"

    private static let singleCardinality: [(type: String, index: String)] = [
        ("INSTANCE_OF", "relationship_single_instance_of"),
        ("LOT_OF", "relationship_single_lot_of"),
        ("SOWN_FROM", "relationship_single_sown_from"),
    ]

    private func seededQueue() throws -> DatabaseQueue {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: identifier))
        try #require(index > 0)
        let queue = try MigrationHarness.database(through: identifiers[index - 1])
        try queue.write { db in
            let entities = [
                ("pl1", "planting"), ("pl2", "planting"), ("p1", "plant"), ("p2", "plant"),
                ("s1", "seed_lot"), ("x1", "starter_batch"), ("b1", "bed"), ("g1", "garden"),
            ]
            for (id, type) in entities {
                try db.execute(
                    sql: "INSERT INTO entity (id, entity_type) VALUES (?, ?)",
                    arguments: [id, type]
                )
            }
            let edges = [
                ("e1", "pl1", "INSTANCE_OF", "p1"),
                ("e2", "pl1", "INSTANCE_OF", "p2"),
                ("e3", "pl2", "INSTANCE_OF", "p1"),
                ("e4", "s1", "LOT_OF", "p1"),
                ("e5", "x1", "SOWN_FROM", "s1"),
                ("e6", "b1", "LOCATED_IN", "g1"),
                ("e7", "pl1", "LOCATED_IN", "b1"),
            ]
            for (id, from, type, target) in edges {
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id, source, source_type)
                        VALUES (?, ?, ?, ?, 'seed', 'reference')
                        """,
                    arguments: [id, from, type, target]
                )
            }
        }
        return queue
    }

    @Test func aPreexistingDuplicateIsCleanedKeepingTheLowestID() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let rows = try queue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT id, to_entity_id FROM relationship
                    WHERE from_entity_id = 'pl1' AND relationship_type = 'INSTANCE_OF'
                    """
            )
        }
        #expect(rows.count == 1)
        #expect(rows.first?["id"] == "e1")
        #expect(rows.first?["to_entity_id"] == "p1")
    }

    @Test func nonDuplicateEdgesSurviveTheMigration() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let survivors = try queue.read { db in
            try String.fetchAll(db, sql: "SELECT id FROM relationship ORDER BY id")
        }
        #expect(survivors == ["e1", "e3", "e4", "e5", "e6", "e7"])
        let provenance = try queue.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM relationship WHERE id = 'e4'")
        }
        #expect(provenance?["source"] == "seed")
        #expect(provenance?["source_type"] == "reference")
    }

    @Test(arguments: singleCardinality.map(\.type))
    func aSecondEdgeOfEachSingleCardinalityTypeIsRejected(type: String) throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let from =
            switch type {
            case "INSTANCE_OF": "pl2"
            case "LOT_OF": "s1"
            default: "x1"
            }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('dupe', ?, ?, 'p2')
                        """,
                    arguments: [from, type]
                )
            }
        }
    }

    @Test func allFourSingleCardinalityIndexesExistAtHead() throws {
        let database = try AppDatabase.inMemory()
        let names = try database.writer.read { db in
            try db.indexes(on: "relationship").map(\.name)
        }
        #expect(names.contains("relationship_single_located_in_parent"))
        for (_, index) in Self.singleCardinality {
            #expect(names.contains(index))
        }
    }

    @Test(arguments: [RelationshipType.instanceOf, .lotOf, .sownFrom])
    func duplicateEdgesAreRejectedAtHeadThroughTheGraphStore(type: RelationshipType) throws {
        let database = try AppDatabase.inMemory()
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                let source = EntityRef(id: "src", type: sourceType(for: type))
                let first = EntityRef(id: "t1", type: targetType(for: type))
                let second = EntityRef(id: "t2", type: targetType(for: type))
                for ref in [source, first, second] {
                    try GraphStore.register(ref, in: db)
                }
                try GraphStore.relate(from: source, type, to: first, in: db)
                try GraphStore.relate(from: source, type, to: second, in: db)
            }
        }
    }

    @Test(arguments: SchemaMigrations.identifiers)
    func theHeadMigratesCleanlyFromEveryPriorVersion(identifier: String) throws {
        let queue = try MigrationHarness.database(through: identifier)
        try MigrationHarness.migrateToHead(queue)
        let applied = try queue.read { db in
            try SchemaMigrations.migrator().appliedIdentifiers(db)
        }
        #expect(Set(SchemaMigrations.identifiers).isSubset(of: applied))
    }

    private func sourceType(for type: RelationshipType) -> EntityType {
        switch type {
        case .instanceOf: .planting
        case .lotOf: .seedLot
        default: .starterBatch
        }
    }

    private func targetType(for type: RelationshipType) -> EntityType {
        switch type {
        case .instanceOf: .plant
        case .lotOf: .plant
        default: .seedLot
        }
    }
}
