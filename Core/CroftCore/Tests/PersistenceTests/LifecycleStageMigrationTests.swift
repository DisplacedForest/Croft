import Foundation
import GRDB
import Testing

@testable import Persistence

let lifecycleStageIdentifier = "v016-lifecycle-stages"

struct LifecycleStageMigrationTests {
    private static let observationIndexes = [
        "observation_on_planting_id",
        "observation_on_cultivar_id",
        "observation_on_species_id",
        "observation_on_bed_id",
        "observation_on_garden_id",
    ]

    private func seededQueue() throws -> DatabaseQueue {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: lifecycleStageIdentifier))
        try #require(index > 0)
        #expect(identifiers[index - 1] == gardenTaskIdentifier)
        let queue = try MigrationHarness.database(through: identifiers[index - 1])
        try queue.write { db in
            try db.execute(sql: "INSERT INTO garden (id, name) VALUES ('g1', 'Kitchen Garden')")
            try db.execute(
                sql: """
                    INSERT INTO observation
                        (id, garden_id, observed_at, notes, growth_state,
                         symptoms, measurements, tags)
                    VALUES ('o1', 'g1', '2024-07-03 12:00:00', 'first truss setting',
                            'flowering', '["leaf curl"]', '[]', '["weekly"]')
                    """
            )
            try db.execute(
                sql: """
                    INSERT INTO observation_photo (id, observation_id, relative_path, created_at)
                    VALUES ('p1', 'o1', 'observations/o1/1.jpg', '2024-07-03 12:00:00')
                    """
            )
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('o1', 'observation')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('g1', 'garden')")
            try db.execute(
                sql: """
                    INSERT INTO relationship (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e1', 'o1', 'OBSERVED_ON', 'g1')
                    """
            )
        }
        return queue
    }

    @Test func rowsPhotosAndEdgesSurviveTheRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let row = try queue.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM observation WHERE id = 'o1'")
        }
        let preserved = try #require(row)
        #expect(preserved["garden_id"] == "g1")
        #expect(preserved["notes"] == "first truss setting")
        #expect(preserved["symptoms"] == #"["leaf curl"]"#)
        #expect(preserved["tags"] == #"["weekly"]"#)
        #expect(preserved["stage"] == DatabaseValue.null)
        let photo = try queue.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM observation_photo WHERE id = 'p1'")
        }
        #expect(try #require(photo)["observation_id"] == "o1")
        let edge = try queue.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM relationship WHERE id = 'e1'")
        }
        #expect(try #require(edge)["relationship_type"] == "OBSERVED_ON")
    }

    @Test func theGrowthStateColumnIsGone() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let columns = try queue.read { db in
            try db.columns(in: "observation").map(\.name)
        }
        #expect(!columns.contains("growth_state"))
        #expect(columns.contains("stage"))
    }

    @Test func theStageCheckRejectsUnknownValuesAfterTheRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO observation (id, garden_id, observed_at, stage)
                        VALUES ('o2', 'g1', '2024-07-04 12:00:00', 'flowering')
                        """
                )
            }
        }
        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO observation (id, garden_id, observed_at, stage)
                    VALUES ('o3', 'g1', '2024-07-04 12:00:00', 'germinated')
                    """
            )
        }
    }

    @Test func everyObservationIndexExistsAtHead() throws {
        let database = try AppDatabase.inMemory()
        let names = try database.writer.read { db in
            try db.indexes(on: "observation").map(\.name)
        }
        for index in Self.observationIndexes {
            #expect(names.contains(index))
        }
    }
}
