import Domain
import GRDB
import Graph
import Testing

@testable import Persistence

struct PestRelationshipTests {
    @Test func plantAndPestEdgesCarryProvenance() throws {
        let fixture = try PestFixture()
        let species = EntityRef(id: "species-1", type: .plant)
        let cultivar = EntityRef(id: "cultivar-1", type: .plant)
        try fixture.registerPlant(species.id)
        try fixture.registerPlant(cultivar.id)
        try fixture.repository.insert(hornworm)
        try fixture.repository.insert(braconidWasp)
        let pestRef = EntityRef(id: hornworm.id.rawValue, type: .pest)
        let waspRef = EntityRef(id: braconidWasp.id.rawValue, type: .pest)
        let provenance = Provenance(
            source: "county extension bulletin",
            sourceType: .reference,
            confidence: 0.85,
            notes: "observed on outdoor beds"
        )

        try fixture.relate(species, .hostOf, pestRef, provenance: provenance)
        try fixture.relate(cultivar, .susceptibleTo, pestRef, provenance: provenance)
        try fixture.relate(pestRef, .parasitizedBy, waspRef, provenance: provenance)
        try fixture.relate(pestRef, .predatedBy, waspRef, provenance: provenance)

        let outgoing = try fixture.database.writer.read { db in
            try GraphStore.outgoing(from: pestRef.id, via: .parasitizedBy, in: db)
                + GraphStore.outgoing(from: pestRef.id, via: .predatedBy, in: db)
        }
        #expect(outgoing.map(\.target) == [waspRef, waspRef])
        #expect(outgoing.allSatisfy { $0.provenance == provenance })

        let incoming = try fixture.database.writer.read { db in
            try GraphStore.incoming(to: pestRef.id, via: .hostOf, in: db)
                + GraphStore.incoming(to: pestRef.id, via: .susceptibleTo, in: db)
        }
        #expect(incoming.map(\.source) == [species, cultivar])
        #expect(incoming.allSatisfy { $0.provenance == provenance })
    }

    @Test func theHostPestPredatorTriangleTraversesFromEveryCorner() throws {
        let fixture = try PestFixture()
        let tomato = EntityRef(id: "solanum-lycopersicum", type: .plant)
        try fixture.registerPlant(tomato.id)
        try fixture.repository.insert(hornworm)
        try fixture.repository.insert(braconidWasp)
        let pestRef = EntityRef(id: hornworm.id.rawValue, type: .pest)
        let waspRef = EntityRef(id: braconidWasp.id.rawValue, type: .pest)
        try fixture.relate(tomato, .hostOf, pestRef)
        try fixture.relate(pestRef, .parasitizedBy, waspRef)

        let fromPlant = try fixture.database.writer.read { db in
            try GraphStore.outgoing(from: tomato.id, via: .hostOf, in: db)
        }
        #expect(fromPlant.map(\.target) == [pestRef])

        let fromPest = try fixture.database.writer.read { db in
            (
                hosts: try GraphStore.incoming(to: pestRef.id, via: .hostOf, in: db),
                parasites: try GraphStore.outgoing(from: pestRef.id, via: .parasitizedBy, in: db)
            )
        }
        #expect(fromPest.hosts.map(\.source) == [tomato])
        #expect(fromPest.parasites.map(\.target) == [waspRef])

        let fromWasp = try fixture.database.writer.read { db in
            try GraphStore.incoming(to: waspRef.id, via: .parasitizedBy, in: db)
        }
        #expect(fromWasp.map(\.source) == [pestRef])
        let resolved = try fixture.database.writer.read { db in
            try GraphStore.resolve(fromWasp.map(\.source), as: PestRecord.self, in: db)
        }
        #expect(try resolved.map { try $0.model() } == [hornworm])
    }

    @Test func deletingThePestLeavesNoEdgesBehind() throws {
        let fixture = try PestFixture()
        let tomato = EntityRef(id: "tomato", type: .plant)
        try fixture.registerPlant(tomato.id)
        try fixture.repository.insert(hornworm)
        try fixture.repository.insert(braconidWasp)
        let pestRef = EntityRef(id: hornworm.id.rawValue, type: .pest)
        let waspRef = EntityRef(id: braconidWasp.id.rawValue, type: .pest)
        try fixture.relate(tomato, .hostOf, pestRef)
        try fixture.relate(pestRef, .parasitizedBy, waspRef)

        try fixture.repository.delete(id: hornworm.id)

        #expect(try fixture.edgeCount(referencing: pestRef.id) == 0)
        #expect(try fixture.repository.fetch(id: braconidWasp.id) != nil)
    }

    @Test func deletingThePlantEntityLeavesNoEdgesBehind() throws {
        let fixture = try PestFixture()
        let tomato = EntityRef(id: "tomato", type: .plant)
        try fixture.registerPlant(tomato.id)
        try fixture.repository.insert(hornworm)
        let pestRef = EntityRef(id: hornworm.id.rawValue, type: .pest)
        try fixture.relate(tomato, .hostOf, pestRef)

        try fixture.database.writer.write { db in
            try GraphStore.deleteEntity(tomato.id, in: db)
        }

        #expect(try fixture.edgeCount(referencing: tomato.id) == 0)
        #expect(try fixture.edgeCount(referencing: pestRef.id) == 0)
        #expect(try fixture.repository.fetch(id: hornworm.id) != nil)
    }
}

struct PestMigrationTests {
    private func seededQueue() throws -> DatabaseQueue {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: pestIdentifier))
        try #require(index > 0)
        let queue = try MigrationHarness.database(through: identifiers[index - 1])
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('b1', 'bed')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('g1', 'garden')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('p1', 'plant')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('p2', 'plant')")
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
                    VALUES ('e2', 'p1', 'COMPANION_WITH', 'p2',
                            'companion guide', 'reference', 0.4, 'anecdotal')
                    """
            )
        }
        return queue
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
        #expect(rows.first?["source_type"] == "observation")
        #expect(rows.first?["confidence"] == 0.95)
        #expect(rows.first?["notes"] == "north wall")
        #expect(rows.last?["from_entity_id"] == "p1")
        #expect(rows.last?["relationship_type"] == "COMPANION_WITH")
        #expect(rows.last?["source"] == "companion guide")
        #expect(rows.last?["source_type"] == "reference")
        #expect(rows.last?["confidence"] == 0.4)
        #expect(rows.last?["notes"] == "anecdotal")
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

    @Test func theWidenedCheckAcceptsTheNewTypesOnly() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('x1', 'pest')")
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e4', 'x1', 'PARASITIZED_BY', 'p1')
                    """
            )
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e5', 'x1', 'PREDATED_BY', 'p2')
                    """
            )
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e6', 'x1', 'ANNOYED_BY', 'p1')
                        """
                )
            }
        }
    }

    @Test func thePestTableExistsAtHead() throws {
        let database = try AppDatabase.inMemory()
        let exists = try database.writer.read { db in
            try db.tableExists("pest")
        }
        #expect(exists)
    }
}
