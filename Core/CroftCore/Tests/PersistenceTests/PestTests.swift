import Domain
import GRDB
import Graph
import Testing

@testable import Persistence

struct PestStorageTests {
    @Test func everyAttributeRoundTrips() throws {
        let fixture = try PestFixture()
        try fixture.repository.insert(hornworm)
        let fetched = try #require(try fixture.repository.fetch(id: hornworm.id))
        #expect(fetched == hornworm)
    }

    @Test func listsAreStoredAsJSONText() throws {
        let fixture = try PestFixture()
        try fixture.repository.insert(hornworm)
        let row = try fixture.database.writer.read { db in
            try Row.fetchOne(
                db, sql: "SELECT * FROM pest WHERE id = ?", arguments: [hornworm.id.rawValue])
        }
        let stored = try #require(row)
        #expect(stored["affected_plant_parts"] == "[\"leaf\",\"stem\",\"fruit\"]")
        #expect(stored["active_seasons"] == "[\"summer\",\"fall\"]")
        #expect(stored["organism_type"] == "pest")
    }

    @Test func absentOptionalsAreStoredAsNull() throws {
        let fixture = try PestFixture()
        let sparse = Pest(commonName: "Aphid", organismType: .pest)
        try fixture.repository.insert(sparse)
        let row = try fixture.database.writer.read { db in
            try Row.fetchOne(
                db, sql: "SELECT * FROM pest WHERE id = ?", arguments: [sparse.id.rawValue])
        }
        let stored = try #require(row)
        for column in [
            "scientific_name", "description", "life_cycle", "typical_damage", "geographic_range",
        ] {
            #expect(stored[column] == DatabaseValue.null)
        }
        #expect(try fixture.repository.fetch(id: sparse.id) == sparse)
    }

    @Test func aBeneficialOrganismRoundTrips() throws {
        let fixture = try PestFixture()
        try fixture.repository.insert(braconidWasp)
        let fetched = try #require(try fixture.repository.fetch(id: braconidWasp.id))
        #expect(fetched.organismType == .beneficial)
        #expect(fetched == braconidWasp)
    }

    @Test func updateReplacesStoredAttributes() throws {
        let fixture = try PestFixture()
        try fixture.repository.insert(hornworm)
        var revised = hornworm
        revised.commonName = "Tobacco Hornworm"
        revised.affectedPlantParts = [.leaf]
        revised.activeSeasons = []
        revised.geographicRange = nil
        try fixture.repository.update(revised)
        #expect(try fixture.repository.fetch(id: hornworm.id) == revised)
    }

    @Test func fetchAllIsOrderedByCommonName() throws {
        let fixture = try PestFixture()
        try fixture.repository.insert(hornworm)
        try fixture.repository.insert(braconidWasp)
        try fixture.repository.insert(Pest(commonName: "Aphid", organismType: .pest))
        #expect(
            try fixture.repository.fetchAll().map(\.commonName)
                == ["Aphid", "Braconid Wasp", "Tomato Hornworm"])
    }

    @Test func deleteRemovesTheRow() throws {
        let fixture = try PestFixture()
        try fixture.repository.insert(hornworm)
        #expect(try fixture.repository.delete(id: hornworm.id))
        #expect(try fixture.repository.fetch(id: hornworm.id) == nil)
        #expect(try fixture.repository.fetchAll().isEmpty)
    }

    @Test func deletingAMissingPestReportsNoChange() throws {
        let fixture = try PestFixture()
        #expect(try fixture.repository.delete(id: Pest.ID(rawValue: "missing")) == false)
    }

    @Test func anUnknownOrganismTypeIsRejectedByTheDatabase() throws {
        let fixture = try PestFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO pest (id, common_name, organism_type)
                        VALUES ('p1', 'Mystery', 'symbiont')
                        """
                )
            }
        }
    }
}

struct PestEntityRegistrationTests {
    @Test func insertRegistersTheEntity() throws {
        let fixture = try PestFixture()
        try fixture.repository.insert(hornworm)
        let type = try fixture.database.writer.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT entity_type FROM entity WHERE id = ?",
                arguments: [hornworm.id.rawValue]
            )
        }
        #expect(type == "pest")
    }

    @Test func deleteRemovesTheEntity() throws {
        let fixture = try PestFixture()
        try fixture.repository.insert(hornworm)
        try fixture.repository.delete(id: hornworm.id)
        let found = try fixture.database.writer.read { db in
            try GraphStore.registered(hornworm.id.rawValue, in: db)
        }
        #expect(found == nil)
    }

    @Test func insertingAPestOverAnExistingPlantIdentifierIsRejected() throws {
        let fixture = try PestFixture()
        try fixture.registerPlant("shared-id")
        let clash = Pest(
            id: Pest.ID(rawValue: "shared-id"), commonName: "Clash", organismType: .pest)
        #expect(
            throws: GraphError.entityTypeMismatch(
                id: "shared-id", stored: .plant, requested: .pest)
        ) {
            try fixture.repository.insert(clash)
        }
        let rows = try fixture.database.writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM pest")
        }
        #expect(rows == 0)
    }
}
