import Domain
import GRDB
import Graph
import Testing

@testable import Persistence

struct DiseaseRelationshipTests {
    @Test func diseaseAndPathogenEdgesCarryProvenance() throws {
        let fixture = try DiseaseFixture()
        try fixture.repository.insert(earlyBlight)
        let pathogen = Pathogen(name: "Alternaria solani")
        try fixture.pathogens.insert(pathogen)
        let diseaseRef = EntityRef(id: earlyBlight.id.rawValue, type: .disease)
        let pathogenRef = EntityRef(id: pathogen.id.rawValue, type: .pathogen)
        let provenance = Provenance(
            source: "county extension bulletin",
            sourceType: .reference,
            confidence: 0.85,
            notes: "observed on outdoor beds"
        )

        try fixture.relate(diseaseRef, .causedBy, pathogenRef, provenance: provenance)

        let outgoing = try fixture.database.writer.read { db in
            try GraphStore.outgoing(from: diseaseRef.id, via: .causedBy, in: db)
        }
        #expect(outgoing.map(\.target) == [pathogenRef])
        #expect(outgoing.allSatisfy { $0.provenance == provenance })

        let incoming = try fixture.database.writer.read { db in
            try GraphStore.incoming(to: pathogenRef.id, via: .causedBy, in: db)
        }
        #expect(incoming.map(\.source) == [diseaseRef])
    }

    @Test func thePlantDiseasePathogenTriangleTraversesFromEveryCorner() throws {
        let fixture = try DiseaseFixture()
        let tomato = EntityRef(id: "solanum-lycopersicum", type: .plant)
        try fixture.registerPlant(tomato.id)
        try fixture.repository.insert(earlyBlight)
        let pathogen = Pathogen(name: "Alternaria solani")
        try fixture.pathogens.insert(pathogen)
        let diseaseRef = EntityRef(id: earlyBlight.id.rawValue, type: .disease)
        let pathogenRef = EntityRef(id: pathogen.id.rawValue, type: .pathogen)
        try fixture.relate(tomato, .susceptibleTo, diseaseRef)
        try fixture.relate(diseaseRef, .causedBy, pathogenRef)

        let fromPlant = try fixture.database.writer.read { db in
            try GraphStore.outgoing(from: tomato.id, via: .susceptibleTo, in: db)
        }
        #expect(fromPlant.map(\.target) == [diseaseRef])

        let fromDisease = try fixture.database.writer.read { db in
            (
                hosts: try GraphStore.incoming(to: diseaseRef.id, via: .susceptibleTo, in: db),
                causes: try GraphStore.outgoing(from: diseaseRef.id, via: .causedBy, in: db)
            )
        }
        #expect(fromDisease.hosts.map(\.source) == [tomato])
        #expect(fromDisease.causes.map(\.target) == [pathogenRef])

        let fromPathogen = try fixture.database.writer.read { db in
            try GraphStore.incoming(to: pathogenRef.id, via: .causedBy, in: db)
        }
        #expect(fromPathogen.map(\.source) == [diseaseRef])
        let resolved = try fixture.database.writer.read { db in
            try GraphStore.resolve(fromPathogen.map(\.source), as: DiseaseRecord.self, in: db)
        }
        #expect(try resolved.map { try $0.model() } == [earlyBlight])
    }

    @Test func deletingTheDiseaseLeavesNoEdgesBehind() throws {
        let fixture = try DiseaseFixture()
        let tomato = EntityRef(id: "tomato", type: .plant)
        try fixture.registerPlant(tomato.id)
        try fixture.repository.insert(earlyBlight)
        let pathogen = Pathogen(name: "Alternaria solani")
        try fixture.pathogens.insert(pathogen)
        let diseaseRef = EntityRef(id: earlyBlight.id.rawValue, type: .disease)
        let pathogenRef = EntityRef(id: pathogen.id.rawValue, type: .pathogen)
        try fixture.relate(tomato, .susceptibleTo, diseaseRef)
        try fixture.relate(diseaseRef, .causedBy, pathogenRef)

        try fixture.repository.delete(id: earlyBlight.id)

        #expect(try fixture.edgeCount(referencing: diseaseRef.id) == 0)
        #expect(try fixture.pathogens.fetch(id: pathogen.id) != nil)
    }

    @Test func deletingThePathogenDropsOnlyItsCausedByEdges() throws {
        let fixture = try DiseaseFixture()
        try fixture.repository.insert(earlyBlight)
        let pathogen = Pathogen(name: "Alternaria solani")
        try fixture.pathogens.insert(pathogen)
        let condition = EnvironmentalCondition(name: "warm humid conditions")
        try fixture.environmentalConditions.insert(condition)
        let diseaseRef = EntityRef(id: earlyBlight.id.rawValue, type: .disease)
        let pathogenRef = EntityRef(id: pathogen.id.rawValue, type: .pathogen)
        let conditionRef = EntityRef(
            id: condition.id.rawValue,
            type: .environmentalCondition
        )
        try fixture.relate(diseaseRef, .causedBy, pathogenRef)
        try fixture.relate(diseaseRef, .favoredBy, conditionRef)

        try fixture.pathogens.delete(id: pathogen.id)

        #expect(try fixture.edgeCount(referencing: pathogenRef.id) == 0)
        #expect(try fixture.edgeCount(referencing: conditionRef.id) == 1)
        #expect(try fixture.repository.fetch(id: earlyBlight.id) != nil)
    }

    @Test func deletingTheConditionDropsItsFavoredByEdges() throws {
        let fixture = try DiseaseFixture()
        try fixture.repository.insert(earlyBlight)
        let condition = EnvironmentalCondition(name: "warm humid conditions")
        try fixture.environmentalConditions.insert(condition)
        let diseaseRef = EntityRef(id: earlyBlight.id.rawValue, type: .disease)
        let conditionRef = EntityRef(
            id: condition.id.rawValue,
            type: .environmentalCondition
        )
        try fixture.relate(diseaseRef, .favoredBy, conditionRef)

        try fixture.environmentalConditions.delete(id: condition.id)

        #expect(try fixture.edgeCount(referencing: conditionRef.id) == 0)
        #expect(try fixture.edgeCount(referencing: diseaseRef.id) == 0)
        #expect(try fixture.repository.fetch(id: earlyBlight.id) != nil)
    }

    @Test func deletingThePlantEntityLeavesNoEdgesBehind() throws {
        let fixture = try DiseaseFixture()
        let tomato = EntityRef(id: "tomato", type: .plant)
        try fixture.registerPlant(tomato.id)
        try fixture.repository.insert(earlyBlight)
        let diseaseRef = EntityRef(id: earlyBlight.id.rawValue, type: .disease)
        try fixture.relate(tomato, .susceptibleTo, diseaseRef)

        try fixture.database.writer.write { db in
            try GraphStore.deleteEntity(tomato.id, in: db)
        }

        #expect(try fixture.edgeCount(referencing: tomato.id) == 0)
        #expect(try fixture.edgeCount(referencing: diseaseRef.id) == 0)
        #expect(try fixture.repository.fetch(id: earlyBlight.id) != nil)
    }

    @Test func earlyBlightResolvesInBothDirectionsAcrossPathogenAndCondition() throws {
        let fixture = try DiseaseFixture()
        let tomato = EntityRef(id: "tomato", type: .plant)
        try fixture.registerPlant(tomato.id)
        try fixture.repository.insert(earlyBlight)
        let pathogen = Pathogen(name: "Alternaria solani")
        try fixture.pathogens.insert(pathogen)
        let condition = EnvironmentalCondition(name: "warm humid conditions")
        try fixture.environmentalConditions.insert(condition)
        let diseaseRef = EntityRef(id: earlyBlight.id.rawValue, type: .disease)
        let pathogenRef = EntityRef(id: pathogen.id.rawValue, type: .pathogen)
        let conditionRef = EntityRef(id: condition.id.rawValue, type: .environmentalCondition)
        let provenance = Provenance(
            source: "extension pathology notes",
            sourceType: .reference,
            confidence: 0.9,
            notes: "typical seasonal pattern"
        )

        try fixture.relate(diseaseRef, .causedBy, pathogenRef, provenance: provenance)
        try fixture.relate(tomato, .susceptibleTo, diseaseRef, provenance: provenance)
        try fixture.relate(diseaseRef, .favoredBy, conditionRef, provenance: provenance)

        let causes = try fixture.database.writer.read { db in
            try GraphStore.outgoing(from: diseaseRef.id, via: .causedBy, in: db)
        }
        #expect(causes.map(\.target) == [pathogenRef])

        let favors = try fixture.database.writer.read { db in
            try GraphStore.outgoing(from: diseaseRef.id, via: .favoredBy, in: db)
        }
        #expect(favors.map(\.target) == [conditionRef])

        let susceptibleHosts = try fixture.database.writer.read { db in
            try GraphStore.incoming(to: diseaseRef.id, via: .susceptibleTo, in: db)
        }
        #expect(susceptibleHosts.map(\.source) == [tomato])

        let causedDiseases = try fixture.database.writer.read { db in
            try GraphStore.incoming(to: pathogenRef.id, via: .causedBy, in: db)
        }
        #expect(causedDiseases.map(\.source) == [diseaseRef])

        let favoredDiseases = try fixture.database.writer.read { db in
            try GraphStore.incoming(to: conditionRef.id, via: .favoredBy, in: db)
        }
        #expect(favoredDiseases.map(\.source) == [diseaseRef])
    }
}

struct DiseaseMigrationTests {
    private func seededQueue() throws -> DatabaseQueue {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: diseaseIdentifier))
        try #require(index > 0)
        let queue = try MigrationHarness.database(through: identifiers[index - 1])
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('b1', 'bed')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('g1', 'garden')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('p1', 'plant')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('d1', 'disease')")
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
                        (id, from_entity_id, relationship_type, to_entity_id,
                         source, source_type, confidence, notes)
                    VALUES ('e2', 'p1', 'SUSCEPTIBLE_TO', 'd1',
                            'field notes', 'observation', 0.7, 'seen in July')
                    """
            )
        }
        return queue
    }

    @Test func provenanceRequiredEdgesSurviveTheRelationshipRebuild() throws {
        let queue = try seededQueue()
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('p2', 'plant')")
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id,
                         source, source_type, confidence, notes)
                    VALUES ('e3', 'p1', 'COMPANION_WITH', 'p2',
                            'trial notes', 'reference', 0.4, 'paired well')
                    """
            )
        }
        try MigrationHarness.migrateToHead(queue)
        let row = try queue.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM relationship WHERE id = 'e3'")
        }
        #expect(row?["relationship_type"] == "COMPANION_WITH")
        #expect(row?["source"] == "trial notes")
        #expect(row?["source_type"] == "reference")
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e4', 'p2', 'COMPANION_WITH', 'p1')
                        """
                )
            }
        }
    }

    @Test func edgesAndProvenanceSurviveTheRelationshipRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let rows = try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM relationship ORDER BY id")
        }
        #expect(rows.count == 2)
        #expect(rows.first?["from_entity_id"] == "b1")
        #expect(rows.first?["relationship_type"] == "LOCATED_IN")
        #expect(rows.first?["source"] == "site survey")
        #expect(rows.last?["from_entity_id"] == "p1")
        #expect(rows.last?["relationship_type"] == "SUSCEPTIBLE_TO")
        #expect(rows.last?["confidence"] == 0.7)
        #expect(rows.last?["notes"] == "seen in July")
    }

    @Test func theSingleParentIndexSurvivesTheRelationshipRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('g2', 'garden')")
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e3', 'b1', 'LOCATED_IN', 'g2')
                        """
                )
            }
        }
    }

    @Test func endpointIndexesSurviveTheRelationshipRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let names = try queue.read { db in
            try db.indexes(on: "relationship").map(\.name)
        }
        #expect(names.contains("relationship_from"))
        #expect(names.contains("relationship_to"))
        #expect(names.contains("relationship_single_located_in_parent"))
    }

    @Test func theLocatedInRestrictTriggerSurvivesTheEntityRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(sql: "DELETE FROM entity WHERE id = 'g1'")
            }
        }
    }

    @Test func theWidenedEntityCheckAcceptsTheNewTypesOnly() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        try queue.write { db in
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('x1', 'pathogen')")
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('x2', 'environmental_condition')"
            )
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: "INSERT INTO entity (id, entity_type) VALUES ('x3', 'spirit')")
            }
        }
    }

    @Test func theWidenedRelationshipCheckAcceptsTheNewTypesOnly() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        try queue.write { db in
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('x1', 'pathogen')")
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('x2', 'environmental_condition')"
            )
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e4', 'd1', 'CAUSED_BY', 'x1')
                    """
            )
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e5', 'd1', 'FAVORED_BY', 'x2')
                    """
            )
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e6', 'd1', 'ANNOYED_BY', 'p1')
                        """
                )
            }
        }
    }

    @Test func theDiseaseTablesExistAtHead() throws {
        let database = try AppDatabase.inMemory()
        let tables = ["disease", "pathogen", "environmental_condition"]
        let existing = try database.writer.read { db in
            try tables.filter { try db.tableExists($0) }
        }
        #expect(existing == tables)
    }
}
