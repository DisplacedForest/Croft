import Foundation
import GRDB
import Testing

@testable import Persistence

let changeLogIdentifier = "v020-change-log"

struct ChangeLogMigrationTests {
    @Test func theMigrationAppendsAfterDailyWeather() throws {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: changeLogIdentifier))
        try #require(index > 0)
        #expect(identifiers[index - 1] == dailyWeatherIdentifier)
    }

    @Test func theTableAndIndexExistAtHead() throws {
        let database = try AppDatabase.inMemory()
        let state = try database.writer.read { db in
            (
                table: try db.tableExists("change_log"),
                indexes: try db.indexes(on: "change_log").map(\.name)
            )
        }
        #expect(state.table)
        #expect(state.indexes.contains("change_log_on_entity"))
    }

    @Test func unknownKindsAndOperationsAreRejected() throws {
        let database = try AppDatabase.inMemory()
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO change_log (entity_kind, entity_id, operation, changed_at)
                        VALUES ('spaceship', 'x', 'create', '2026-08-18 12:00:00')
                        """
                )
            }
        }
        #expect(throws: DatabaseError.self) {
            try database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO change_log (entity_kind, entity_id, operation, changed_at)
                        VALUES ('planting', 'x', 'teleport', '2026-08-18 12:00:00')
                        """
                )
            }
        }
    }

    @Test func sequencesGrowMonotonically() throws {
        let database = try AppDatabase.inMemory()
        try database.writer.write { db in
            for index in 0..<3 {
                try db.execute(
                    sql: """
                        INSERT INTO change_log (entity_kind, entity_id, operation, changed_at)
                        VALUES ('planting', ?, 'create', '2026-08-18 12:00:00')
                        """,
                    arguments: ["p\(index)"]
                )
            }
        }
        let sequences = try ChangeLogRepository(database).all().map(\.sequence)
        #expect(sequences == sequences.sorted())
        #expect(Set(sequences).count == 3)
    }

    @Test func everyChangeKindMatchesTheCheckConstraint() throws {
        let database = try AppDatabase.inMemory()
        try database.writer.write { db in
            for kind in ChangeKind.allCases {
                try db.execute(
                    sql: """
                        INSERT INTO change_log (entity_kind, entity_id, operation, changed_at)
                        VALUES (?, 'x', 'create', '2026-08-18 12:00:00')
                        """,
                    arguments: [kind.rawValue]
                )
            }
        }
        #expect(try ChangeLogRepository(database).count() == ChangeKind.allCases.count)
    }
}
