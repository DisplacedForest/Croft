import Domain
import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

struct PlantingGraphTests {
    @Test func insertRegistersThePlantingItsIdentityAndItsBed() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting()
        try fixture.plantings.insert(planting)
        #expect(try fixture.registered(planting.id.rawValue)?.type == .planting)
        #expect(try fixture.registered(fixture.cultivar.id.rawValue)?.type == .plant)
        #expect(try fixture.registered(fixture.bed.id.rawValue)?.type == .bed)
    }

    @Test func theInstanceOfEdgePointsAtTheCultivar() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting()
        try fixture.plantings.insert(planting)
        let targets = try fixture.outgoing(planting.id.rawValue, .instanceOf).map(\.target)
        #expect(targets == [EntityRef(id: fixture.cultivar.id.rawValue, type: .plant)])
    }

    @Test func theInstanceOfEdgeFallsBackToTheSpecies() throws {
        let fixture = try PlantingFixture()
        let planting = Planting(identity: .species(fixture.plant.id), bedID: fixture.bed.id)
        try fixture.plantings.insert(planting)
        let targets = try fixture.outgoing(planting.id.rawValue, .instanceOf).map(\.target)
        #expect(targets == [EntityRef(id: fixture.plant.id.rawValue, type: .plant)])
    }

    @Test func theLocatedInEdgePointsAtTheBed() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting()
        try fixture.plantings.insert(planting)
        let targets = try fixture.outgoing(planting.id.rawValue, .locatedIn).map(\.target)
        #expect(targets == [EntityRef(id: fixture.bed.id.rawValue, type: .bed)])
    }

    @Test func aSeedLotSourceGetsAPlantedFromEdge() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting(source: .seedLot(fixture.seedLot.id))
        try fixture.plantings.insert(planting)
        let targets = try fixture.outgoing(planting.id.rawValue, .plantedFrom).map(\.target)
        #expect(targets == [EntityRef(id: fixture.seedLot.id.rawValue, type: .seedLot)])
    }

    @Test func aStarterBatchSourceGetsAPlantedFromEdge() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting(source: .starterBatch(fixture.starterBatch.id))
        try fixture.plantings.insert(planting)
        let targets = try fixture.outgoing(planting.id.rawValue, .plantedFrom).map(\.target)
        #expect(targets == [EntityRef(id: fixture.starterBatch.id.rawValue, type: .starterBatch)])
    }

    @Test func aSourcelessPlantingGetsNoPlantedFromEdge() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting()
        try fixture.plantings.insert(planting)
        #expect(try fixture.outgoing(planting.id.rawValue, .plantedFrom).isEmpty)
    }

    @Test func everyPlantingCarriesExactlyOneIdentityAndOneLocationEdge() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting(source: .seedLot(fixture.seedLot.id))
        try fixture.plantings.insert(planting)
        #expect(try fixture.outgoing(planting.id.rawValue, .instanceOf).count == 1)
        #expect(try fixture.outgoing(planting.id.rawValue, .locatedIn).count == 1)
        #expect(try fixture.edgeCount(referencing: planting.id.rawValue) == 3)
    }

    @Test func aSecondLocatedInEdgeIsRejectedByTheDatabase() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting()
        try fixture.plantings.insert(planting)
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e1', ?, 'LOCATED_IN', ?)
                        """,
                    arguments: [planting.id.rawValue, fixture.tunnelBed.id.rawValue]
                )
            }
        }
    }

    @Test func plantingEdgesCarryNoProvenance() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting(source: .seedLot(fixture.seedLot.id))
        try fixture.plantings.insert(planting)
        for type in [RelationshipType.instanceOf, .locatedIn, .plantedFrom] {
            let edges = try fixture.outgoing(planting.id.rawValue, type)
            #expect(edges.map(\.provenance) == [Provenance()])
        }
    }

    @Test func edgeRefsResolveBackToRecords() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting(source: .starterBatch(fixture.starterBatch.id))
        try fixture.plantings.insert(planting)
        let identityRefs = try fixture.outgoing(planting.id.rawValue, .instanceOf).map(\.target)
        let bedRefs = try fixture.outgoing(planting.id.rawValue, .locatedIn).map(\.target)
        let sourceRefs = try fixture.outgoing(planting.id.rawValue, .plantedFrom).map(\.target)
        let resolved = try fixture.database.writer.read { db in
            (
                cultivars: try GraphStore.resolve(identityRefs, as: CultivarRecord.self, in: db),
                beds: try GraphStore.resolve(bedRefs, as: BedRecord.self, in: db),
                batches: try GraphStore.resolve(sourceRefs, as: StarterBatchRecord.self, in: db)
            )
        }
        #expect(try resolved.cultivars.map { try $0.model() } == [fixture.cultivar])
        #expect(try resolved.beds.map { try $0.model() } == [fixture.bed])
        #expect(try resolved.batches.map { try $0.model() } == [fixture.starterBatch])
    }

    @Test func reassigningTheIdentityRepointsTheInstanceOfEdge() throws {
        let fixture = try PlantingFixture()
        var planting = fixture.planting()
        try fixture.plantings.insert(planting)
        planting.identity = .species(fixture.plant.id)
        try fixture.plantings.update(planting)
        let targets = try fixture.outgoing(planting.id.rawValue, .instanceOf).map(\.target.id)
        #expect(targets == [fixture.plant.id.rawValue])
        #expect(try fixture.incoming(fixture.cultivar.id.rawValue, .instanceOf).isEmpty)
    }

    @Test func aTransplantRepointsTheLocatedInEdgeInPlace() throws {
        let fixture = try PlantingFixture()
        var planting = fixture.planting()
        try fixture.plantings.insert(planting)
        planting.bedID = fixture.tunnelBed.id
        planting.transplantedOn = transplantDate
        try fixture.plantings.update(planting)
        let edges = try fixture.outgoing(planting.id.rawValue, .locatedIn)
        #expect(edges.map(\.target.id) == [fixture.tunnelBed.id.rawValue])
        #expect(try fixture.incoming(fixture.bed.id.rawValue, .locatedIn).isEmpty)
    }

    @Test func changingTheSourceRepointsThePlantedFromEdge() throws {
        let fixture = try PlantingFixture()
        var planting = fixture.planting(source: .seedLot(fixture.seedLot.id))
        try fixture.plantings.insert(planting)
        planting.source = .starterBatch(fixture.starterBatch.id)
        try fixture.plantings.update(planting)
        let targets = try fixture.outgoing(planting.id.rawValue, .plantedFrom).map(\.target)
        #expect(targets == [EntityRef(id: fixture.starterBatch.id.rawValue, type: .starterBatch)])
        #expect(try fixture.incoming(fixture.seedLot.id.rawValue, .plantedFrom).isEmpty)
    }

    @Test func clearingTheSourceRemovesThePlantedFromEdge() throws {
        let fixture = try PlantingFixture()
        var planting = fixture.planting(source: .seedLot(fixture.seedLot.id))
        try fixture.plantings.insert(planting)
        planting.source = nil
        try fixture.plantings.update(planting)
        #expect(try fixture.outgoing(planting.id.rawValue, .plantedFrom).isEmpty)
    }

    @Test func addingASourceCreatesThePlantedFromEdge() throws {
        let fixture = try PlantingFixture()
        var planting = fixture.planting()
        try fixture.plantings.insert(planting)
        planting.source = .seedLot(fixture.seedLot.id)
        try fixture.plantings.update(planting)
        let targets = try fixture.outgoing(planting.id.rawValue, .plantedFrom).map(\.target.id)
        #expect(targets == [fixture.seedLot.id.rawValue])
    }

    @Test func anUnchangedUpdateKeepsTheSameEdges() throws {
        let fixture = try PlantingFixture()
        var planting = fixture.planting(source: .seedLot(fixture.seedLot.id))
        try fixture.plantings.insert(planting)
        let before = try [RelationshipType.instanceOf, .locatedIn, .plantedFrom].flatMap {
            try fixture.outgoing(planting.id.rawValue, $0).map(\.id)
        }
        planting.notes = "mulched"
        try fixture.plantings.update(planting)
        let after = try [RelationshipType.instanceOf, .locatedIn, .plantedFrom].flatMap {
            try fixture.outgoing(planting.id.rawValue, $0).map(\.id)
        }
        #expect(after == before)
    }

    @Test func deleteRemovesTheEntityAndItsEdges() throws {
        let fixture = try PlantingFixture()
        let planting = fixture.planting(source: .seedLot(fixture.seedLot.id))
        try fixture.plantings.insert(planting)
        try fixture.plantings.delete(id: planting.id)
        #expect(try fixture.registered(planting.id.rawValue) == nil)
        #expect(try fixture.edgeCount(referencing: planting.id.rawValue) == 0)
        #expect(try fixture.registered(fixture.bed.id.rawValue)?.type == .bed)
        #expect(try fixture.seedLots.fetch(id: fixture.seedLot.id) != nil)
    }

    @Test func twoPlantingsOfTheSameCultivarBothPointAtIt() throws {
        let fixture = try PlantingFixture()
        let first = fixture.planting()
        let second = fixture.planting()
        try fixture.plantings.insert(first)
        try fixture.plantings.insert(second)
        let sources = try fixture.incoming(fixture.cultivar.id.rawValue, .instanceOf)
            .map(\.source.id)
            .sorted()
        #expect(sources == [first.id.rawValue, second.id.rawValue].sorted())
    }
}

struct PlantingMigrationTests {
    private func seededQueue() throws -> DatabaseQueue {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: plantingIdentifier))
        try #require(index > 0)
        let queue = try MigrationHarness.database(through: identifiers[index - 1])
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('b1', 'bed')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('g1', 'garden')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('p1', 'plant')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('p2', 'plant')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('s1', 'seed_lot')")
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
                            'trial notes', 'reference', 0.4, 'paired well')
                    """
            )
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e3', 's1', 'LOT_OF', 'p1')
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
        #expect(rows.count == 3)
        #expect(rows.first?["from_entity_id"] == "b1")
        #expect(rows.first?["relationship_type"] == "LOCATED_IN")
        #expect(rows.first?["source"] == "site survey")
        #expect(rows.first?["confidence"] == 0.95)
        #expect(rows[1]["relationship_type"] == "COMPANION_WITH")
        #expect(rows[1]["source_type"] == "reference")
        #expect(rows[1]["notes"] == "paired well")
        #expect(rows.last?["relationship_type"] == "LOT_OF")
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

    @Test func theWidenedRelationshipCheckAcceptsThePlantingTypesOnly() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        try queue.write { db in
            try db.execute(
                sql: "INSERT INTO entity (id, entity_type) VALUES ('x1', 'planting')")
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e4', 'x1', 'INSTANCE_OF', 'p1')
                    """
            )
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e5', 'x1', 'PLANTED_FROM', 's1')
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

    @Test func theLocatedInRestrictTriggerStillHolds() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(sql: "DELETE FROM entity WHERE id = 'g1'")
            }
        }
    }

    @Test func thePlantingTableExistsAtHead() throws {
        let database = try AppDatabase.inMemory()
        let exists = try database.writer.read { db in
            try db.tableExists("planting")
        }
        #expect(exists)
    }

    @Test func theForeignKeyIndexesExistAtHead() throws {
        let database = try AppDatabase.inMemory()
        let names = try database.writer.read { db in
            try db.indexes(on: "planting").map(\.name)
        }
        for column in ["cultivar_id", "species_id", "bed_id", "seed_lot_id", "starter_batch_id"] {
            #expect(names.contains("planting_on_\(column)"))
        }
    }
}
