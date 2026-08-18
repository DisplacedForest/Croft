import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

struct HarvestGraphTests {
    @Test func insertRegistersTheHarvestAndItsPlanting() throws {
        let fixture = try HarvestFixture()
        let harvest = try fixture.harvest()
        try fixture.harvests.insert(harvest)
        #expect(try fixture.registered(harvest.id.rawValue)?.type == .harvest)
        #expect(try fixture.registered(fixture.tomatoPlanting.id.rawValue)?.type == .planting)
    }

    @Test func insertCreatesExactlyOneHarvestedFromEdge() throws {
        let fixture = try HarvestFixture()
        let harvest = try fixture.harvest()
        try fixture.harvests.insert(harvest)
        let edges = try fixture.outgoing(harvest.id.rawValue, .harvestedFrom)
        #expect(
            edges.map(\.target)
                == [EntityRef(id: fixture.tomatoPlanting.id.rawValue, type: .planting)])
        #expect(try fixture.edgeCount(referencing: harvest.id.rawValue) == 1)
    }

    @Test func harvestEdgesCarryNoProvenance() throws {
        let fixture = try HarvestFixture()
        let harvest = try fixture.harvest()
        try fixture.harvests.insert(harvest)
        let edges = try fixture.outgoing(harvest.id.rawValue, .harvestedFrom)
        #expect(edges.map(\.provenance) == [Provenance()])
    }

    @Test func repointingMovesTheHarvestedFromEdge() throws {
        let fixture = try HarvestFixture()
        var harvest = try fixture.harvest()
        try fixture.harvests.insert(harvest)
        harvest.plantingID = fixture.basilPlanting.id
        try fixture.harvests.update(harvest)
        let targets = try fixture.outgoing(harvest.id.rawValue, .harvestedFrom).map(\.target.id)
        #expect(targets == [fixture.basilPlanting.id.rawValue])
        #expect(try fixture.incoming(fixture.tomatoPlanting.id.rawValue, .harvestedFrom).isEmpty)
    }

    @Test func anUnchangedUpdateKeepsTheSameEdge() throws {
        let fixture = try HarvestFixture()
        var harvest = try fixture.harvest()
        try fixture.harvests.insert(harvest)
        let before = try fixture.outgoing(harvest.id.rawValue, .harvestedFrom).map(\.id)
        harvest.notes = "still fine"
        try fixture.harvests.update(harvest)
        let after = try fixture.outgoing(harvest.id.rawValue, .harvestedFrom).map(\.id)
        #expect(after == before)
    }

    @Test func aSecondHarvestedFromEdgeIsRejectedByTheDatabase() throws {
        let fixture = try HarvestFixture()
        let harvest = try fixture.harvest()
        try fixture.harvests.insert(harvest)
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e1', ?, 'HARVESTED_FROM', ?)
                        """,
                    arguments: [harvest.id.rawValue, fixture.basilPlanting.id.rawValue]
                )
            }
        }
    }

    @Test func aHarvestedPlantingCannotBeDeletedFromTheGraph() throws {
        let fixture = try HarvestFixture()
        try fixture.harvests.insert(try fixture.harvest())
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try GraphStore.deleteEntity(fixture.tomatoPlanting.id.rawValue, in: db)
            }
        }
    }

    @Test func deleteRemovesTheEntityAndItsEdge() throws {
        let fixture = try HarvestFixture()
        let harvest = try fixture.harvest()
        try fixture.harvests.insert(harvest)
        try fixture.harvests.delete(id: harvest.id)
        #expect(try fixture.registered(harvest.id.rawValue) == nil)
        #expect(try fixture.edgeCount(referencing: harvest.id.rawValue) == 0)
        #expect(try fixture.registered(fixture.tomatoPlanting.id.rawValue)?.type == .planting)
    }

    @Test func twoHarvestsOfTheSamePlantingBothPointAtIt() throws {
        let fixture = try HarvestFixture()
        let first = try fixture.harvest()
        let second = try fixture.harvest(on: laterHarvestedDate)
        try fixture.harvests.insert(first)
        try fixture.harvests.insert(second)
        let sources = try fixture.incoming(fixture.tomatoPlanting.id.rawValue, .harvestedFrom)
            .map(\.source.id)
            .sorted()
        #expect(sources == [first.id.rawValue, second.id.rawValue].sorted())
    }
}

struct HarvestMigrationTests {
    private static let relationshipIndexes = [
        "relationship_from",
        "relationship_to",
        "relationship_single_located_in_parent",
        "relationship_single_instance_of",
        "relationship_single_lot_of",
        "relationship_single_sown_from",
        "relationship_single_observed_on",
        "relationship_single_harvested_from",
    ]

    private func seededQueue() throws -> DatabaseQueue {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: harvestIdentifier))
        try #require(index > 0)
        #expect(identifiers[index - 1] == observationIdentifier)
        let queue = try MigrationHarness.database(through: identifiers[index - 1])
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('b1', 'bed')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('g1', 'garden')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('o1', 'observation')")
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
                    VALUES ('e2', 'o1', 'OBSERVED_ON', 'b1')
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
        #expect(entities.map { $0["id"] as String } == ["b1", "g1", "o1"])
        let edges = try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM relationship ORDER BY id")
        }
        #expect(edges.count == 2)
        #expect(edges.first?["relationship_type"] == "LOCATED_IN")
        #expect(edges.first?["source"] == "site survey")
        #expect(edges.first?["confidence"] == 0.95)
        #expect(edges.last?["relationship_type"] == "OBSERVED_ON")
    }

    @Test func everyRelationshipIndexExistsAtHead() throws {
        let database = try AppDatabase.inMemory()
        let names = try database.writer.read { db in
            try db.indexes(on: "relationship").map(\.name)
        }
        for index in Self.relationshipIndexes {
            #expect(names.contains(index))
        }
    }

    @Test func thePriorRestrictTriggersSurviveTheRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        for target in ["g1", "b1"] {
            #expect(throws: DatabaseError.self) {
                try queue.write { db in
                    try db.execute(sql: "DELETE FROM entity WHERE id = ?", arguments: [target])
                }
            }
        }
    }

    @Test func theWidenedChecksAcceptHarvests() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('h1', 'harvest')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('pl1', 'planting')")
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e3', 'h1', 'HARVESTED_FROM', 'pl1')
                    """
            )
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('x1', 'picking')")
            }
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(sql: "DELETE FROM entity WHERE id = 'pl1'")
            }
        }
    }

    @Test func theHarvestTableAndIndexExistAtHead() throws {
        let database = try AppDatabase.inMemory()
        let state = try database.writer.read { db in
            (
                table: try db.tableExists("harvest"),
                indexes: try db.indexes(on: "harvest").map(\.name)
            )
        }
        #expect(state.table)
        #expect(state.indexes.contains("harvest_on_planting_id"))
    }
}
