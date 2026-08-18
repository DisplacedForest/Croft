import Domain
import Foundation
import GRDB
import Persistence
import Testing

@testable import GardenModel

private func scratchDefaults() -> PropertySetupDefaults {
    PropertySetupDefaults(
        store: UserDefaults(suiteName: "property-source-tests-\(UUID().uuidString)")!)
}

private enum StoreFailure: Error {
    case readBroke
}

@MainActor
private final class ThrowingReloadStore: PropertyStoring {
    let home = Property(name: "Home")
    var updates = 0
    var reads = 0

    func firstProperty() throws -> Property? {
        reads += 1
        if reads > 1 {
            throw StoreFailure.readBroke
        }
        return home
    }

    func ensureHomeProperty() throws -> Property {
        home
    }

    func updateDetails(
        _ id: Property.ID,
        location: GeoCoordinate?,
        hardinessZone: Int?,
        lastFrost: MonthDay?,
        firstFrost: MonthDay?
    ) throws {
        updates += 1
    }
}

@MainActor
private func corruptedDatabase() throws -> (AppDatabase, row: Row) {
    let database = try AppDatabase.inMemory()
    try database.writer.write { db in
        try db.execute(
            sql: """
                INSERT INTO property
                    (id, name, notes, archived, latitude, longitude, hardiness_zone,
                     last_frost_month, last_frost_day, first_frost_month, first_frost_day)
                VALUES ('p1', 'Home', NULL, 0, 44.5, -72.8, 4, 2, 30, NULL, NULL)
                """
        )
    }
    let row = try database.writer.read { db in
        try Row.fetchOne(db, sql: "SELECT * FROM property WHERE id = 'p1'")
    }
    return (database, try #require(row))
}

@Test @MainActor func aCorruptedRowSurfacesAsUnreadableAndStaysUntouched() throws {
    let (database, before) = try corruptedDatabase()
    let form = PropertyDetailsForm(database: database, defaults: scratchDefaults())
    form.load()

    #expect(form.sourceState == .unreadable)
    #expect(form.property == nil)
    #expect(form.loadFailureMessage != nil)
    #expect(!form.shouldOfferSetup)

    form.latitudeText = "1"
    form.longitudeText = "1"
    #expect(!form.save())
    #expect(form.validationMessage != nil)

    let after = try database.writer.read { db in
        try Row.fetchOne(db, sql: "SELECT * FROM property WHERE id = 'p1'")
    }
    #expect(try #require(after) == before)
    let count = try database.writer.read { db in
        try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM property")
    }
    #expect(count == 1)
}

@Test @MainActor func aCommittedWriteReportsSuccessEvenIfARereadWouldFail() throws {
    let store = ThrowingReloadStore()
    let form = PropertyDetailsForm(store: store, defaults: scratchDefaults())
    form.load()
    #expect(form.sourceState == .loaded)
    form.zoneText = "4"
    form.lastFrostMonth = 5
    form.lastFrostDay = 15

    #expect(form.save())
    #expect(store.updates == 1)
    #expect(form.validationMessage == nil)
    #expect(form.sourceState == .loaded)
    #expect(form.property?.hardinessZone == 4)
    #expect(form.property?.lastFrost == MonthDay(month: 5, day: 15))
}

@Test @MainActor func aMissingPropertyStillOffersSetup() throws {
    let database = try AppDatabase.inMemory()
    let form = PropertyDetailsForm(database: database, defaults: scratchDefaults())
    form.load()
    #expect(form.sourceState == .missing)
    #expect(form.property == nil)
    #expect(form.loadFailureMessage == nil)
    #expect(form.shouldOfferSetup)
}
