import Foundation
import GRDB
import Testing

@testable import Persistence

struct ClimateProvenanceMigrationTests {
    private static let priorIdentifier: String = {
        let identifiers = SchemaMigrations.identifiers
        let index = identifiers.firstIndex(of: "v022-climate-provenance")!
        return identifiers[index - 1]
    }()

    private func seededQueue(
        zone: String?, lastFrostMonth: Int?, lastFrostDay: Int?
    ) throws -> DatabaseQueue {
        let queue = try MigrationHarness.database(through: Self.priorIdentifier)
        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO property
                        (id, name, archived, hardiness_zone, last_frost_month, last_frost_day)
                    VALUES ('home', 'Home', 0, :zone, :month, :day)
                    """,
                arguments: ["zone": zone, "month": lastFrostMonth, "day": lastFrostDay]
            )
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('home', 'property')"
            )
        }
        return queue
    }

    @Test func existingValuesMigrateAsUserSourced() throws {
        let queue = try seededQueue(zone: "8b", lastFrostMonth: 5, lastFrostDay: 15)
        try MigrationHarness.migrateToHead(queue)
        let row = try queue.read {
            try Row.fetchOne(
                $0,
                sql: "SELECT zone_source, frost_dates_source FROM property WHERE id = 'home'")
        }
        #expect(row?["zone_source"] == "user")
        #expect(row?["frost_dates_source"] == "user")
    }

    @Test func nullValuesMigrateAsDerived() throws {
        let queue = try seededQueue(zone: nil, lastFrostMonth: nil, lastFrostDay: nil)
        try MigrationHarness.migrateToHead(queue)
        let row = try queue.read {
            try Row.fetchOne(
                $0,
                sql: "SELECT zone_source, frost_dates_source FROM property WHERE id = 'home'")
        }
        #expect(row?["zone_source"] == "derived")
        #expect(row?["frost_dates_source"] == "derived")
    }

    @Test func mixedValuesMigrateEachGroupIndependently() throws {
        let queue = try seededQueue(zone: "4", lastFrostMonth: nil, lastFrostDay: nil)
        try MigrationHarness.migrateToHead(queue)
        let row = try queue.read {
            try Row.fetchOne(
                $0,
                sql: "SELECT zone_source, frost_dates_source FROM property WHERE id = 'home'")
        }
        #expect(row?["zone_source"] == "user")
        #expect(row?["frost_dates_source"] == "derived")
    }
}
