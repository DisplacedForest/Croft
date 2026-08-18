import Domain
import Foundation
import GRDB
import Testing

@testable import Persistence

struct PropertyLocationMigrationTests {
    private static let priorIdentifier: String = {
        let identifiers = SchemaMigrations.identifiers
        let index = identifiers.firstIndex(of: "v017-property-location")!
        return identifiers[index - 1]
    }()

    private func seededQueue() throws -> DatabaseQueue {
        let queue = try MigrationHarness.database(through: Self.priorIdentifier)
        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO property (id, name, notes, archived)
                    VALUES ('home', 'Home', 'the croft', 0)
                    """
            )
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('home', 'property')"
            )
        }
        return queue
    }

    @Test func propertyRowsAndGraphRegistrationSurviveTheRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let row = try queue.read {
            try Row.fetchOne($0, sql: "SELECT * FROM property WHERE id = 'home'")
        }
        #expect(row?["name"] == "Home")
        #expect(row?["notes"] == "the croft")
        #expect(row?["latitude"] == nil)
        #expect(row?["hardiness_zone"] == nil)
        #expect(row?["last_frost_month"] == nil)
        let entityType = try queue.read {
            try String.fetchOne(
                $0, sql: "SELECT entity_type FROM entity WHERE id = 'home'")
        }
        #expect(entityType == "property")
    }

    @Test func fullDetailsAreAccepted() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE property SET
                        latitude = 44.5, longitude = -72.8, hardiness_zone = 4,
                        last_frost_month = 5, last_frost_day = 15,
                        first_frost_month = 9, first_frost_day = 28
                    WHERE id = 'home'
                    """
            )
        }
        let zone = try queue.read {
            try Int.fetchOne($0, sql: "SELECT hardiness_zone FROM property WHERE id = 'home'")
        }
        #expect(zone == 4)
    }

    @Test func unpairedCoordinateIsRejected() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: "UPDATE property SET latitude = 44.5 WHERE id = 'home'")
            }
        }
    }

    @Test func outOfRangeCoordinateIsRejected() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: """
                        UPDATE property SET latitude = 91, longitude = 10
                        WHERE id = 'home'
                        """)
            }
        }
    }

    @Test func unpairedFrostDateIsRejected() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: "UPDATE property SET first_frost_month = 9 WHERE id = 'home'")
            }
        }
    }

    @Test func outOfRangeFrostMonthIsRejected() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: """
                        UPDATE property SET last_frost_month = 13, last_frost_day = 5
                        WHERE id = 'home'
                        """)
            }
        }
    }
}

struct PropertyDetailsRoundTripTests {
    @Test func detailsPersistAndReadBack() throws {
        let database = try AppDatabase.inMemory()
        let structures = GardenStructureRepository(database)
        let property = Property(name: "Home")
        try structures.create(property)

        let location = try #require(GeoCoordinate(latitude: 44.5, longitude: -72.8))
        let lastFrost = try #require(MonthDay(month: 5, day: 15))
        let firstFrost = try #require(MonthDay(month: 9, day: 28))
        try structures.updatePropertyDetails(
            property.id,
            location: location,
            hardinessZone: 4,
            lastFrost: lastFrost,
            firstFrost: firstFrost
        )

        let loaded = try #require(try structures.property(id: property.id))
        #expect(loaded.location == location)
        #expect(loaded.hardinessZone == 4)
        #expect(loaded.lastFrost == lastFrost)
        #expect(loaded.firstFrost == firstFrost)
        #expect(loaded.name == "Home")
    }

    @Test func detailsClearBackToNil() throws {
        let database = try AppDatabase.inMemory()
        let structures = GardenStructureRepository(database)
        let property = Property(name: "Home")
        try structures.create(property)
        try structures.updatePropertyDetails(
            property.id,
            location: GeoCoordinate(latitude: 1, longitude: 2),
            hardinessZone: 7,
            lastFrost: MonthDay(month: 4, day: 1),
            firstFrost: MonthDay(month: 10, day: 20)
        )
        try structures.updatePropertyDetails(
            property.id,
            location: nil,
            hardinessZone: nil,
            lastFrost: nil,
            firstFrost: nil
        )
        let loaded = try #require(try structures.property(id: property.id))
        #expect(loaded.location == nil)
        #expect(loaded.hardinessZone == nil)
        #expect(loaded.lastFrost == nil)
        #expect(loaded.firstFrost == nil)
    }

    @Test func updatingAMissingPropertyFails() throws {
        let database = try AppDatabase.inMemory()
        let structures = GardenStructureRepository(database)
        #expect(throws: GardenStructureError.self) {
            try structures.updatePropertyDetails(
                Property.ID.generate(),
                location: nil,
                hardinessZone: nil,
                lastFrost: nil,
                firstFrost: nil
            )
        }
    }

    @Test func southernHemisphereFrostOrderIsAllowed() throws {
        let database = try AppDatabase.inMemory()
        let structures = GardenStructureRepository(database)
        let property = Property(name: "Home")
        try structures.create(property)
        try structures.updatePropertyDetails(
            property.id,
            location: nil,
            hardinessZone: nil,
            lastFrost: MonthDay(month: 9, day: 20),
            firstFrost: MonthDay(month: 5, day: 10)
        )
        let loaded = try #require(try structures.property(id: property.id))
        #expect(loaded.lastFrost?.month == 9)
        #expect(loaded.firstFrost?.month == 5)
    }
}
