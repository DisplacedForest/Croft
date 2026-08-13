import Foundation
import GRDB
import Testing

@testable import Persistence

struct GardenTaskMigrationTests {
    private static let relationshipIndexes = [
        "relationship_from",
        "relationship_to",
        "relationship_single_located_in_parent",
        "relationship_single_instance_of",
        "relationship_single_lot_of",
        "relationship_single_sown_from",
        "relationship_single_observed_on",
        "relationship_single_harvested_from",
        "relationship_single_task_for",
    ]

    private static let restrictTriggers = [
        "entity_located_in_restrict",
        "entity_observed_on_restrict",
        "entity_harvested_from_restrict",
        "entity_task_for_restrict",
    ]

    private func seededQueue() throws -> DatabaseQueue {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: gardenTaskIdentifier))
        try #require(index > 0)
        #expect(identifiers[index - 1] == harvestIdentifier)
        let queue = try MigrationHarness.database(through: identifiers[index - 1])
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('b1', 'bed')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('g1', 'garden')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('pl1', 'planting')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('h1', 'harvest')")
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id,
                         source, source_type, confidence, notes)
                    VALUES ('e1', 'b1', 'LOCATED_IN', 'g1',
                            'site survey', 'observation', 0.95, 'north wall')
                    """
            )
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e2', 'h1', 'HARVESTED_FROM', 'pl1')
                    """
            )
        }
        return queue
    }

    @Test func entitiesAndEdgesSurviveTheRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let entities = try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM entity ORDER BY id")
        }
        #expect(entities.map { $0["id"] as String } == ["b1", "g1", "h1", "pl1"])
        let edges = try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM relationship ORDER BY id")
        }
        #expect(edges.count == 2)
        #expect(edges.first?["relationship_type"] == "LOCATED_IN")
        #expect(edges.first?["source"] == "site survey")
        #expect(edges.first?["confidence"] == 0.95)
        #expect(edges.last?["relationship_type"] == "HARVESTED_FROM")
    }

    @Test func everyRelationshipIndexExistsAtHead() throws {
        let database = try AppDatabase.inMemory()
        let names = try database.writer.read { db in
            try db.indexes(on: "relationship").map(\.name)
        }
        for index in Self.relationshipIndexes {
            #expect(names.contains(index))
        }
    }

    @Test func everyRestrictTriggerExistsAtHead() throws {
        let database = try AppDatabase.inMemory()
        let names = try database.writer.read { db in
            try String.fetchAll(
                db, sql: "SELECT name FROM sqlite_master WHERE type = 'trigger'")
        }
        for trigger in Self.restrictTriggers {
            #expect(names.contains(trigger))
        }
    }

    @Test func thePriorRestrictTriggersSurviveTheRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        for target in ["g1", "pl1"] {
            #expect(throws: DatabaseError.self) {
                try queue.write { db in
                    try db.execute(sql: "DELETE FROM entity WHERE id = ?", arguments: [target])
                }
            }
        }
    }

    @Test func theWidenedChecksAcceptTasks() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('t1', 'task')")
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e3', 't1', 'TASK_FOR', 'b1')
                    """
            )
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('x1', 'chore')")
            }
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(sql: "DELETE FROM entity WHERE id = 'b1'")
            }
        }
    }

    @Test func theTaskTableAndIndexesExistAtHead() throws {
        let database = try AppDatabase.inMemory()
        let state = try database.writer.read { db in
            (
                table: try db.tableExists("task"),
                indexes: try db.indexes(on: "task").map(\.name)
            )
        }
        #expect(state.table)
        for index in ["task_on_garden_id", "task_on_bed_id", "task_on_planting_id"] {
            #expect(state.indexes.contains(index))
        }
    }
}
