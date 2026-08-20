import Foundation
import GRDB
import Testing

@testable import Persistence

struct HardinessZoneMigrationTests {
    private static let priorIdentifier: String = {
        let identifiers = SchemaMigrations.identifiers
        let index = identifiers.firstIndex(of: "v021-hardiness-zone-text")!
        return identifiers[index - 1]
    }()

    private func seededQueue(zone: Int?) throws -> DatabaseQueue {
        let queue = try MigrationHarness.database(through: Self.priorIdentifier)
        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO property
                        (id, name, notes, archived, latitude, longitude, hardiness_zone,
                         last_frost_month, last_frost_day, first_frost_month, first_frost_day)
                    VALUES ('home', 'Home', 'the croft', 0, 44.5, -72.8, :zone, 5, 15, 9, 28)
                    """,
                arguments: ["zone": zone]
            )
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('home', 'property')"
            )
        }
        return queue
    }

    @Test func anIntegerZoneBecomesTheSameZoneAsText() throws {
        let queue = try seededQueue(zone: 4)
        try MigrationHarness.migrateToHead(queue)
        let stored = try queue.read {
            try String.fetchOne(
                $0, sql: "SELECT hardiness_zone FROM property WHERE id = 'home'")
        }
        #expect(stored == "4")
    }

    @Test func aNullZoneStaysNull() throws {
        let queue = try seededQueue(zone: nil)
        try MigrationHarness.migrateToHead(queue)
        let row = try queue.read {
            try Row.fetchOne($0, sql: "SELECT * FROM property WHERE id = 'home'")
        }
        #expect(row?["hardiness_zone"] == nil)
        #expect(row?["name"] == "Home")
        #expect(row?["latitude"] == 44.5)
        #expect(row?["last_frost_month"] == 5)
        #expect(row?["first_frost_day"] == 28)
    }
}
