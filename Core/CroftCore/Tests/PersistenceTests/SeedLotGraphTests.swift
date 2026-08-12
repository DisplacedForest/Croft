import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

struct SeedLotLineageTests {
    @Test func insertRegistersTheLotAndItsCultivar() throws {
        let fixture = try SeedLotFixture()
        let lot = SeedLot(cultivarID: fixture.cultivar.id)
        try fixture.seedLots.insert(lot)
        #expect(try fixture.registered(lot.id.rawValue)?.type == .seedLot)
        #expect(try fixture.registered(fixture.cultivar.id.rawValue)?.type == .plant)
    }

    @Test func insertRegistersTheBatch() throws {
        let fixture = try SeedLotFixture()
        let lot = SeedLot(cultivarID: fixture.cultivar.id)
        try fixture.seedLots.insert(lot)
        let batch = StarterBatch(seedLotID: lot.id)
        try fixture.starterBatches.insert(batch)
        #expect(try fixture.registered(batch.id.rawValue)?.type == .starterBatch)
    }

    @Test func theChainTraversesDownFromTheCultivarToTheBatch() throws {
        let fixture = try SeedLotFixture()
        let lot = SeedLot(cultivarID: fixture.cultivar.id)
        try fixture.seedLots.insert(lot)
        let batch = StarterBatch(seedLotID: lot.id)
        try fixture.starterBatches.insert(batch)

        let lots = try fixture.incoming(fixture.cultivar.id.rawValue, .lotOf)
        #expect(lots.map(\.source.id) == [lot.id.rawValue])
        let batches = try fixture.incoming(lot.id.rawValue, .sownFrom)
        #expect(batches.map(\.source.id) == [batch.id.rawValue])
        #expect(batches.map(\.source.type) == [.starterBatch])
    }

    @Test func theChainTraversesUpFromTheBatchToTheCultivar() throws {
        let fixture = try SeedLotFixture()
        let lot = SeedLot(cultivarID: fixture.cultivar.id)
        try fixture.seedLots.insert(lot)
        let batch = StarterBatch(seedLotID: lot.id)
        try fixture.starterBatches.insert(batch)

        let sownFrom = try fixture.outgoing(batch.id.rawValue, .sownFrom)
        #expect(sownFrom.map(\.target) == [EntityRef(id: lot.id.rawValue, type: .seedLot)])
        let lotOf = try fixture.outgoing(lot.id.rawValue, .lotOf)
        #expect(
            lotOf.map(\.target) == [EntityRef(id: fixture.cultivar.id.rawValue, type: .plant)])
    }

    @Test func lineageRefsResolveBackToRecords() throws {
        let fixture = try SeedLotFixture()
        let lot = SeedLot(cultivarID: fixture.cultivar.id, source: "Baker Creek")
        try fixture.seedLots.insert(lot)
        let batch = StarterBatch(seedLotID: lot.id, status: .growing)
        try fixture.starterBatches.insert(batch)

        let cultivarRefs = try fixture.outgoing(lot.id.rawValue, .lotOf).map(\.target)
        let lotRefs = try fixture.outgoing(batch.id.rawValue, .sownFrom).map(\.target)
        let batchRefs = try fixture.incoming(lot.id.rawValue, .sownFrom).map(\.source)
        let resolved = try fixture.database.writer.read { db in
            (
                cultivars: try GraphStore.resolve(cultivarRefs, as: CultivarRecord.self, in: db),
                lots: try GraphStore.resolve(lotRefs, as: SeedLotRecord.self, in: db),
                batches: try GraphStore.resolve(batchRefs, as: StarterBatchRecord.self, in: db)
            )
        }
        #expect(try resolved.cultivars.map { try $0.model() } == [fixture.cultivar])
        #expect(resolved.lots.map { $0.model() } == [lot])
        #expect(try resolved.batches.map { try $0.model() } == [batch])
    }

    @Test func lineageEdgesCarryNoProvenance() throws {
        let fixture = try SeedLotFixture()
        let lot = SeedLot(cultivarID: fixture.cultivar.id)
        try fixture.seedLots.insert(lot)
        let edges = try fixture.outgoing(lot.id.rawValue, .lotOf)
        #expect(edges.map(\.provenance) == [Provenance()])
    }

    @Test func deletingABatchRemovesItsEntityAndEdges() throws {
        let fixture = try SeedLotFixture()
        let lot = SeedLot(cultivarID: fixture.cultivar.id)
        try fixture.seedLots.insert(lot)
        let batch = StarterBatch(seedLotID: lot.id)
        try fixture.starterBatches.insert(batch)

        try fixture.starterBatches.delete(id: batch.id)

        #expect(try fixture.registered(batch.id.rawValue) == nil)
        #expect(try fixture.edgeCount(referencing: batch.id.rawValue) == 0)
        #expect(try fixture.edgeCount(referencing: lot.id.rawValue) == 1)
        #expect(try fixture.seedLots.fetch(id: lot.id) != nil)
    }

    @Test func deletingAChildlessLotRemovesItsEntityAndEdges() throws {
        let fixture = try SeedLotFixture()
        let lot = SeedLot(cultivarID: fixture.cultivar.id)
        try fixture.seedLots.insert(lot)

        try fixture.seedLots.delete(id: lot.id)

        #expect(try fixture.registered(lot.id.rawValue) == nil)
        #expect(try fixture.edgeCount(referencing: lot.id.rawValue) == 0)
        #expect(try fixture.edgeCount(referencing: fixture.cultivar.id.rawValue) == 0)
        #expect(try fixture.registered(fixture.cultivar.id.rawValue)?.type == .plant)
    }

    @Test func reassigningALotToAnotherCultivarRepointsItsLineageEdge() throws {
        let fixture = try SeedLotFixture()
        var lot = SeedLot(cultivarID: fixture.cultivar.id)
        try fixture.seedLots.insert(lot)
        let adopted = try fixture.addCultivar(named: "Cherokee Purple")

        lot.cultivarID = adopted.id
        try fixture.seedLots.update(lot)

        let targets = try fixture.outgoing(lot.id.rawValue, .lotOf).map(\.target.id)
        #expect(targets == [adopted.id.rawValue])
        #expect(try fixture.incoming(fixture.cultivar.id.rawValue, .lotOf).isEmpty)
    }

    @Test func reassigningABatchToAnotherLotRepointsItsLineageEdge() throws {
        let fixture = try SeedLotFixture()
        let first = SeedLot(cultivarID: fixture.cultivar.id, source: "Baker Creek")
        let second = SeedLot(cultivarID: fixture.cultivar.id, source: "seed swap")
        try fixture.seedLots.insert(first)
        try fixture.seedLots.insert(second)
        var batch = StarterBatch(seedLotID: first.id, status: .sown)
        try fixture.starterBatches.insert(batch)

        batch.seedLotID = second.id
        try fixture.starterBatches.update(batch)

        let targets = try fixture.outgoing(batch.id.rawValue, .sownFrom).map(\.target.id)
        #expect(targets == [second.id.rawValue])
        #expect(try fixture.incoming(first.id.rawValue, .sownFrom).isEmpty)
    }

    @Test func anUnchangedUpdateKeepsTheSameLineageEdge() throws {
        let fixture = try SeedLotFixture()
        var lot = SeedLot(cultivarID: fixture.cultivar.id)
        try fixture.seedLots.insert(lot)
        let before = try fixture.outgoing(lot.id.rawValue, .lotOf).map(\.id)

        lot.notes = "keeps well"
        try fixture.seedLots.update(lot)

        #expect(try fixture.outgoing(lot.id.rawValue, .lotOf).map(\.id) == before)
    }

    @Test func twoLotsOfTheSameCultivarBothPointAtIt() throws {
        let fixture = try SeedLotFixture()
        let first = SeedLot(cultivarID: fixture.cultivar.id, source: "Baker Creek")
        let second = SeedLot(cultivarID: fixture.cultivar.id, source: "seed swap")
        try fixture.seedLots.insert(first)
        try fixture.seedLots.insert(second)
        let sources = try fixture.incoming(fixture.cultivar.id.rawValue, .lotOf)
            .map(\.source.id)
            .sorted()
        #expect(sources == [first.id.rawValue, second.id.rawValue].sorted())
    }
}

struct SeedLotMigrationTests {
    private func seededQueue() throws -> DatabaseQueue {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: seedLotIdentifier))
        try #require(index > 0)
        let queue = try MigrationHarness.database(through: identifiers[index - 1])
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('b1', 'bed')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('g1', 'garden')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('p1', 'plant')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('p2', 'plant')")
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
        return queue
    }

    @Test func entityRowsSurviveTheEntityRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let rows = try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM entity ORDER BY id")
        }
        #expect(rows.map { $0["id"] as String } == ["b1", "d1", "g1", "p1", "p2"])
        #expect(
            rows.map { $0["entity_type"] as String } == [
                "bed", "disease", "garden", "plant", "plant",
            ])
    }

    @Test func edgesAndProvenanceSurviveTheRelationshipRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let rows = try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM relationship ORDER BY id")
        }
        #expect(rows.count == 3)
        #expect(rows.first?["from_entity_id"] == "b1")
        #expect(rows.first?["relationship_type"] == "LOCATED_IN")
        #expect(rows.first?["source"] == "site survey")
        #expect(rows.last?["relationship_type"] == "COMPANION_WITH")
        #expect(rows.last?["source_type"] == "reference")
        #expect(rows.last?["confidence"] == 0.4)
        #expect(rows.last?["notes"] == "paired well")
    }

    @Test func theProvenanceCheckStillRejectsUnattributedCompanionship() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
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

    @Test func theWidenedEntityCheckAcceptsStarterBatchOnly() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        try queue.write { db in
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('x1', 'starter_batch')")
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: "INSERT INTO entity (id, entity_type) VALUES ('x2', 'compost')")
            }
        }
    }

    @Test func theWidenedRelationshipCheckAcceptsTheLineageTypesOnly() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        try queue.write { db in
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('s1', 'seed_lot')")
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('x1', 'starter_batch')")
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e4', 's1', 'LOT_OF', 'p1')
                    """
            )
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e5', 'x1', 'SOWN_FROM', 's1')
                    """
            )
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e6', 'x1', 'GROWN_BESIDE', 'p1')
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
        let triggers = try queue.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type = 'trigger'"
            )
        }
        #expect(triggers.contains("entity_located_in_restrict"))
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(sql: "DELETE FROM entity WHERE id = 'g1'")
            }
        }
    }

    @Test func theSeedLotTablesExistAtHead() throws {
        let database = try AppDatabase.inMemory()
        let tables = ["seed_lot", "starter_batch"]
        let existing = try database.writer.read { db in
            try tables.filter { try db.tableExists($0) }
        }
        #expect(existing == tables)
    }

    @Test func theForeignKeyIndexesExistAtHead() throws {
        let database = try AppDatabase.inMemory()
        let names = try database.writer.read { db in
            (
                lots: try db.indexes(on: "seed_lot").map(\.name),
                batches: try db.indexes(on: "starter_batch").map(\.name)
            )
        }
        #expect(names.lots.contains("seed_lot_on_cultivar_id"))
        #expect(names.batches.contains("starter_batch_on_seed_lot_id"))
    }
}
