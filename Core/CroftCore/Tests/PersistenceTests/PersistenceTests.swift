import Foundation
import GRDB
import Testing

@testable import Persistence

enum MigrationHarness {
    static func database(through identifier: String) throws -> DatabaseQueue {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let queue = try DatabaseQueue(configuration: configuration)
        try SchemaMigrations.migrator(through: identifier).migrate(queue)
        return queue
    }

    static func migrateToHead(_ queue: DatabaseQueue) throws {
        try SchemaMigrations.migrator().migrate(queue)
    }
}

struct AppDatabaseTests {
    @Test func freshDatabaseAppliesAllMigrationsInOrder() throws {
        let database = try AppDatabase.inMemory()
        let applied = try database.writer.read {
            try SchemaMigrations.migrator().appliedIdentifiers($0)
        }
        #expect(applied == Set(SchemaMigrations.identifiers))
    }

    @Test func reopeningAMigratedDatabaseSucceeds() throws {
        let database = try AppDatabase.inMemory()
        _ = try AppDatabase(database.writer)
    }

    @Test func foreignKeysAreEnforced() throws {
        let database = try AppDatabase.inMemory()
        try database.writer.write { db in
            try db.execute(sql: "CREATE TABLE parent (id TEXT PRIMARY KEY NOT NULL)")
            try db.execute(
                sql: """
                    CREATE TABLE child (
                        id TEXT PRIMARY KEY NOT NULL,
                        parent_id TEXT NOT NULL REFERENCES parent(id)
                    )
                    """
            )
        }
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try db.execute(sql: "INSERT INTO child (id, parent_id) VALUES ('c1', 'missing')")
            }
        }
    }

    @Test func baselineStampsApplicationID() throws {
        let database = try AppDatabase.inMemory()
        let stamped = try database.writer.read {
            try Int.fetchOne($0, sql: "PRAGMA application_id")
        }
        #expect(stamped == SchemaMigrations.databaseApplicationID)
    }

    @Test func openCreatesTheDatabaseFileAndParentDirectories() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url =
            directory
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent("croft.sqlite", isDirectory: false)
        _ = try AppDatabase.open(at: url)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test func databaseWithUnknownAppliedMigrationFailsLoudly() throws {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        let queue = try DatabaseQueue(configuration: configuration)
        var migrator = SchemaMigrations.migrator()
        migrator.registerMigration("v999-future") { _ in }
        try migrator.migrate(queue)
        #expect(throws: MigrationError.unknownApplied(["v999-future"])) {
            _ = try AppDatabase(queue)
        }
    }
}

struct MigrationHistoryTests {
    @Test func emptyHistoryIsValid() throws {
        try MigrationHistory.validate(applied: [], registered: ["a", "b"])
    }

    @Test func completeHistoryIsValid() throws {
        try MigrationHistory.validate(applied: ["a", "b"], registered: ["a", "b"])
    }

    @Test func prefixHistoryIsValid() throws {
        try MigrationHistory.validate(applied: ["a"], registered: ["a", "b"])
    }

    @Test func gapInHistoryFails() {
        #expect(throws: MigrationError.appliedOutOfOrder(expected: ["a"], applied: ["b"])) {
            try MigrationHistory.validate(applied: ["b"], registered: ["a", "b"])
        }
    }

    @Test func unknownIdentifierFails() {
        #expect(throws: MigrationError.unknownApplied(["mystery"])) {
            try MigrationHistory.validate(applied: ["a", "mystery"], registered: ["a", "b"])
        }
    }
}

struct MigrationPreservationTests {
    @Test func harnessProvesSeededDataSurvivesLaterMigrations() throws {
        var head = DatabaseMigrator()
        head.registerMigration("v1") { db in
            try db.execute(
                sql: "CREATE TABLE note (id TEXT PRIMARY KEY NOT NULL, body TEXT NOT NULL)")
        }
        let queue = try DatabaseQueue()
        try head.migrate(queue)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO note (id, body) VALUES ('n1', 'hello')")
        }
        head.registerMigration("v2") { db in
            try db.execute(sql: "ALTER TABLE note ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0")
        }
        try head.migrate(queue)
        let body = try queue.read {
            try String.fetchOne($0, sql: "SELECT body FROM note WHERE id = 'n1'")
        }
        #expect(body == "hello")
    }

    @Test func userDataSurvivesMigrationFromBaselineToHead() throws {
        let queue = try MigrationHarness.database(through: "v001-baseline")
        try queue.write { db in
            try db.execute(sql: "CREATE TABLE scratch (id TEXT PRIMARY KEY NOT NULL)")
            try db.execute(sql: "INSERT INTO scratch (id) VALUES ('keep-me')")
        }
        try MigrationHarness.migrateToHead(queue)
        let kept = try queue.read {
            try String.fetchOne($0, sql: "SELECT id FROM scratch")
        }
        #expect(kept == "keep-me")
    }

    @Test func registeredIdentifiersStayInOrder() {
        #expect(
            SchemaMigrations.identifiers == [
                "v001-baseline", "v002-graph", "v003-taxonomy", "v004-garden-structure",
                "v005-pests", "v006-plant-relationships", "v007-diseases",
            ])
    }

    @Test func graphRowsSurviveMigrationToHead() throws {
        let queue = try MigrationHarness.database(through: "v002-graph")
        try queue.write { db in
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('p1', 'plant')")
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('d1', 'disease')")
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id,
                         source, source_type, confidence, notes)
                    VALUES ('e1', 'p1', 'SUSCEPTIBLE_TO', 'd1',
                            'field notes', 'observation', 0.9, 'seen in June')
                    """
            )
        }
        try MigrationHarness.migrateToHead(queue)
        let edge = try queue.read {
            try Row.fetchOne($0, sql: "SELECT * FROM relationship WHERE id = 'e1'")
        }
        #expect(edge?["from_entity_id"] == "p1")
        #expect(edge?["confidence"] == 0.9)
        #expect(edge?["notes"] == "seen in June")
    }
}
