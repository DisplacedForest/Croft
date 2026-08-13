import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

struct ObservationGraphTests {
    @Test func insertRegistersTheObservationAndItsTarget() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        #expect(try fixture.registered(observation.id.rawValue)?.type == .observation)
        #expect(try fixture.registered(fixture.bed.id.rawValue)?.type == .bed)
    }

    @Test func everyTargetKindGetsExactlyOneObservedOnEdge() throws {
        let fixture = try ObservationFixture()
        let expected: [(target: ObservationTarget, ref: EntityRef)] = [
            (
                .planting(fixture.planting.id),
                EntityRef(id: fixture.planting.id.rawValue, type: .planting)
            ),
            (
                .plant(.cultivar(fixture.cultivar.id)),
                EntityRef(id: fixture.cultivar.id.rawValue, type: .plant)
            ),
            (
                .plant(.species(fixture.species.id)),
                EntityRef(id: fixture.species.id.rawValue, type: .plant)
            ),
            (.bed(fixture.bed.id), EntityRef(id: fixture.bed.id.rawValue, type: .bed)),
            (.garden(fixture.garden.id), EntityRef(id: fixture.garden.id.rawValue, type: .garden)),
        ]
        for (target, ref) in expected {
            let observation = fixture.observation(on: target)
            try fixture.observations.insert(observation)
            let edges = try fixture.outgoing(observation.id.rawValue, .observedOn)
            #expect(edges.map(\.target) == [ref])
            #expect(try fixture.edgeCount(referencing: observation.id.rawValue) == 1)
        }
    }

    @Test func observationEdgesCarryNoProvenance() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        let edges = try fixture.outgoing(observation.id.rawValue, .observedOn)
        #expect(edges.map(\.provenance) == [Provenance()])
    }

    @Test func retargetingRepointsTheObservedOnEdge() throws {
        let fixture = try ObservationFixture()
        var observation = fixture.observation()
        try fixture.observations.insert(observation)
        observation.target = .planting(fixture.planting.id)
        try fixture.observations.update(observation)
        let targets = try fixture.outgoing(observation.id.rawValue, .observedOn).map(\.target.id)
        #expect(targets == [fixture.planting.id.rawValue])
        #expect(try fixture.incoming(fixture.bed.id.rawValue, .observedOn).isEmpty)
    }

    @Test func anUnchangedUpdateKeepsTheSameEdge() throws {
        let fixture = try ObservationFixture()
        var observation = fixture.observation()
        try fixture.observations.insert(observation)
        let before = try fixture.outgoing(observation.id.rawValue, .observedOn).map(\.id)
        observation.notes = "still fine"
        try fixture.observations.update(observation)
        let after = try fixture.outgoing(observation.id.rawValue, .observedOn).map(\.id)
        #expect(after == before)
    }

    @Test func aSecondObservedOnEdgeIsRejectedByTheDatabase() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e1', ?, 'OBSERVED_ON', ?)
                        """,
                    arguments: [observation.id.rawValue, fixture.garden.id.rawValue]
                )
            }
        }
    }

    @Test func anObservedEntityCannotBeDeletedFromTheGraph() throws {
        let fixture = try ObservationFixture()
        try fixture.observations.insert(fixture.observation(on: .garden(fixture.garden.id)))
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try GraphStore.deleteEntity(fixture.garden.id.rawValue, in: db)
            }
        }
    }

    @Test func deleteRemovesTheEntityAndItsEdge() throws {
        let fixture = try ObservationFixture()
        let observation = fixture.observation()
        try fixture.observations.insert(observation)
        try fixture.observations.delete(id: observation.id)
        #expect(try fixture.registered(observation.id.rawValue) == nil)
        #expect(try fixture.edgeCount(referencing: observation.id.rawValue) == 0)
        #expect(try fixture.registered(fixture.bed.id.rawValue)?.type == .bed)
    }

    @Test func twoObservationsOfTheSameBedBothPointAtIt() throws {
        let fixture = try ObservationFixture()
        let first = fixture.observation()
        let second = fixture.observation(at: laterObservedDate)
        try fixture.observations.insert(first)
        try fixture.observations.insert(second)
        let sources = try fixture.incoming(fixture.bed.id.rawValue, .observedOn)
            .map(\.source.id)
            .sorted()
        #expect(sources == [first.id.rawValue, second.id.rawValue].sorted())
    }
}

struct ObservationMigrationTests {
    private func seededQueue() throws -> DatabaseQueue {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: observationIdentifier))
        try #require(index > 0)
        #expect(identifiers[index - 1] == "v011-knowledge-types")
        let queue = try MigrationHarness.database(through: identifiers[index - 1])
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('b1', 'bed')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('g1', 'garden')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('p1', 'plant')")
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
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e2', 'p1', 'HOST_OF', 'b1')
                    """
            )
        }
        return queue
    }

    @Test func entitiesAndEdgesSurviveTheRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let entities = try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM entity ORDER BY id")
        }
        #expect(entities.map { $0["id"] as String } == ["b1", "g1", "p1"])
        let edges = try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM relationship ORDER BY id")
        }
        #expect(edges.count == 2)
        #expect(edges.first?["relationship_type"] == "LOCATED_IN")
        #expect(edges.first?["source"] == "site survey")
        #expect(edges.first?["confidence"] == 0.95)
        #expect(edges.last?["relationship_type"] == "HOST_OF")
    }

    @Test func theLocatedInIndexAndTriggerSurviveTheRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let names = try queue.read { db in
            try db.indexes(on: "relationship").map(\.name)
        }
        #expect(names.contains("relationship_from"))
        #expect(names.contains("relationship_to"))
        #expect(names.contains("relationship_single_located_in_parent"))
        #expect(names.contains("relationship_single_observed_on"))
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(sql: "DELETE FROM entity WHERE id = 'g1'")
            }
        }
    }

    @Test func theWidenedChecksAcceptObservations() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        try queue.write { db in
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('o1', 'observation')")
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e3', 'o1', 'OBSERVED_ON', 'b1')
                    """
            )
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: "INSERT INTO entity (id, entity_type) VALUES ('x1', 'sighting')")
            }
        }
    }

    @Test func theObservationTablesExistAtHead() throws {
        let database = try AppDatabase.inMemory()
        let exists = try database.writer.read { db in
            (
                observation: try db.tableExists("observation"),
                photo: try db.tableExists("observation_photo")
            )
        }
        #expect(exists.observation)
        #expect(exists.photo)
    }

    @Test func theForeignKeyIndexesExistAtHead() throws {
        let database = try AppDatabase.inMemory()
        let names = try database.writer.read { db in
            (
                observation: try db.indexes(on: "observation").map(\.name),
                photo: try db.indexes(on: "observation_photo").map(\.name)
            )
        }
        for column in ["planting_id", "cultivar_id", "species_id", "bed_id", "garden_id"] {
            #expect(names.observation.contains("observation_on_\(column)"))
        }
        #expect(names.photo.contains("observation_photo_on_observation_id"))
    }
}
