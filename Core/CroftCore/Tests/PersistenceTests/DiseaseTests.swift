import Domain
import GRDB
import Graph
import Testing

@testable import Persistence

struct DiseaseStorageTests {
    @Test func everyAttributeRoundTrips() throws {
        let fixture = try DiseaseFixture()
        try fixture.repository.insert(earlyBlight)
        let fetched = try #require(try fixture.repository.fetch(id: earlyBlight.id))
        #expect(fetched == earlyBlight)
    }

    @Test func listsAreStoredAsJSONText() throws {
        let fixture = try DiseaseFixture()
        try fixture.repository.insert(earlyBlight)
        let row = try fixture.database.writer.read { db in
            try Row.fetchOne(
                db, sql: "SELECT * FROM disease WHERE id = ?", arguments: [earlyBlight.id.rawValue]
            )
        }
        let stored = try #require(row)
        #expect(stored["affected_plant_parts"] == "[\"leaf\",\"stem\",\"fruit\"]")
        #expect(stored["prevention"] == "[\"Crop rotation\",\"Mulching\"]")
        #expect(stored["management"] == "[\"Remove infected foliage\",\"Apply fungicide\"]")
        #expect(stored["pathogen_type"] == "fungal")
    }

    @Test func absentOptionalsAreStoredAsNull() throws {
        let fixture = try DiseaseFixture()
        let sparse = Disease(name: "Blossom End Rot", pathogenType: .physiological)
        try fixture.repository.insert(sparse)
        let row = try fixture.database.writer.read { db in
            try Row.fetchOne(
                db, sql: "SELECT * FROM disease WHERE id = ?", arguments: [sparse.id.rawValue])
        }
        let stored = try #require(row)
        for column in ["pathogen", "symptoms", "transmission"] {
            #expect(stored[column] == DatabaseValue.null)
        }
        #expect(try fixture.repository.fetch(id: sparse.id) == sparse)
    }

    @Test func updateReplacesStoredAttributes() throws {
        let fixture = try DiseaseFixture()
        try fixture.repository.insert(earlyBlight)
        var revised = earlyBlight
        revised.name = "Late Blight"
        revised.affectedPlantParts = [.leaf]
        revised.prevention = []
        revised.transmission = nil
        try fixture.repository.update(revised)
        #expect(try fixture.repository.fetch(id: earlyBlight.id) == revised)
    }

    @Test func fetchAllIsOrderedByName() throws {
        let fixture = try DiseaseFixture()
        try fixture.repository.insert(earlyBlight)
        try fixture.repository.insert(powderyMildew)
        try fixture.repository.insert(Disease(name: "Aster Yellows", pathogenType: .physiological))
        #expect(
            try fixture.repository.fetchAll().map(\.name)
                == ["Aster Yellows", "Early Blight", "Powdery Mildew"])
    }

    @Test func deleteRemovesTheRow() throws {
        let fixture = try DiseaseFixture()
        try fixture.repository.insert(earlyBlight)
        #expect(try fixture.repository.delete(id: earlyBlight.id))
        #expect(try fixture.repository.fetch(id: earlyBlight.id) == nil)
        #expect(try fixture.repository.fetchAll().isEmpty)
    }

    @Test func deletingAMissingDiseaseReportsNoChange() throws {
        let fixture = try DiseaseFixture()
        #expect(try fixture.repository.delete(id: Disease.ID(rawValue: "missing")) == false)
    }

    @Test func anUnknownPathogenTypeIsRejectedByTheDatabase() throws {
        let fixture = try DiseaseFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO disease (id, name, pathogen_type)
                        VALUES ('d1', 'Mystery', 'possessed')
                        """
                )
            }
        }
    }
}

struct DiseaseEntityRegistrationTests {
    @Test func insertRegistersTheEntity() throws {
        let fixture = try DiseaseFixture()
        try fixture.repository.insert(earlyBlight)
        let type = try fixture.database.writer.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT entity_type FROM entity WHERE id = ?",
                arguments: [earlyBlight.id.rawValue]
            )
        }
        #expect(type == "disease")
    }

    @Test func deleteRemovesTheEntity() throws {
        let fixture = try DiseaseFixture()
        try fixture.repository.insert(earlyBlight)
        try fixture.repository.delete(id: earlyBlight.id)
        let found = try fixture.database.writer.read { db in
            try GraphStore.registered(earlyBlight.id.rawValue, in: db)
        }
        #expect(found == nil)
    }

    @Test func insertingADiseaseOverAnExistingPlantIdentifierIsRejected() throws {
        let fixture = try DiseaseFixture()
        try fixture.registerPlant("shared-id")
        let clash = Disease(
            id: Disease.ID(rawValue: "shared-id"), name: "Clash", pathogenType: .fungal)
        #expect(
            throws: GraphError.entityTypeMismatch(
                id: "shared-id", stored: .plant, requested: .disease)
        ) {
            try fixture.repository.insert(clash)
        }
        let rows = try fixture.database.writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM disease")
        }
        #expect(rows == 0)
    }
}

struct PathogenStorageTests {
    @Test func everyAttributeRoundTrips() throws {
        let fixture = try DiseaseFixture()
        let pathogen = Pathogen(name: "Alternaria solani")
        try fixture.pathogens.insert(pathogen)
        #expect(try fixture.pathogens.fetch(id: pathogen.id) == pathogen)
    }

    @Test func updateReplacesStoredAttributes() throws {
        let fixture = try DiseaseFixture()
        let pathogen = Pathogen(name: "Alternaria solani")
        try fixture.pathogens.insert(pathogen)
        var revised = pathogen
        revised.name = "Alternaria alternata"
        try fixture.pathogens.update(revised)
        #expect(try fixture.pathogens.fetch(id: pathogen.id) == revised)
    }

    @Test func fetchAllIsOrderedByName() throws {
        let fixture = try DiseaseFixture()
        try fixture.pathogens.insert(Pathogen(name: "Erysiphe cichoracearum"))
        try fixture.pathogens.insert(Pathogen(name: "Alternaria solani"))
        #expect(
            try fixture.pathogens.fetchAll().map(\.name)
                == ["Alternaria solani", "Erysiphe cichoracearum"])
    }

    @Test func deleteRemovesTheRowAndEntity() throws {
        let fixture = try DiseaseFixture()
        let pathogen = Pathogen(name: "Alternaria solani")
        try fixture.pathogens.insert(pathogen)
        #expect(try fixture.pathogens.delete(id: pathogen.id))
        #expect(try fixture.pathogens.fetch(id: pathogen.id) == nil)
        let found = try fixture.database.writer.read { db in
            try GraphStore.registered(pathogen.id.rawValue, in: db)
        }
        #expect(found == nil)
    }
}

struct EnvironmentalConditionStorageTests {
    @Test func everyAttributeRoundTrips() throws {
        let fixture = try DiseaseFixture()
        let condition = EnvironmentalCondition(name: "warm humid conditions")
        try fixture.environmentalConditions.insert(condition)
        #expect(try fixture.environmentalConditions.fetch(id: condition.id) == condition)
    }

    @Test func updateReplacesStoredAttributes() throws {
        let fixture = try DiseaseFixture()
        let condition = EnvironmentalCondition(name: "warm humid conditions")
        try fixture.environmentalConditions.insert(condition)
        var revised = condition
        revised.name = "cool wet conditions"
        try fixture.environmentalConditions.update(revised)
        #expect(try fixture.environmentalConditions.fetch(id: condition.id) == revised)
    }

    @Test func fetchAllIsOrderedByName() throws {
        let fixture = try DiseaseFixture()
        try fixture.environmentalConditions.insert(EnvironmentalCondition(name: "warm humid"))
        try fixture.environmentalConditions.insert(EnvironmentalCondition(name: "cool wet"))
        #expect(
            try fixture.environmentalConditions.fetchAll().map(\.name)
                == ["cool wet", "warm humid"])
    }

    @Test func deleteRemovesTheRowAndEntity() throws {
        let fixture = try DiseaseFixture()
        let condition = EnvironmentalCondition(name: "warm humid conditions")
        try fixture.environmentalConditions.insert(condition)
        #expect(try fixture.environmentalConditions.delete(id: condition.id))
        #expect(try fixture.environmentalConditions.fetch(id: condition.id) == nil)
        let found = try fixture.database.writer.read { db in
            try GraphStore.registered(condition.id.rawValue, in: db)
        }
        #expect(found == nil)
    }
}
