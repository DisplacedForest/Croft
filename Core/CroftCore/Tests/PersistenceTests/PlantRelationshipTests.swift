import GRDB
import Graph
import Testing

@testable import Persistence

private let curatedTypes: [RelationshipType] = [.companionWith, .antagonisticTo, .rotateAwayFrom]

private let curated = Provenance(
    source: "companion planting handbook",
    sourceType: .reference,
    confidence: 0.7,
    notes: "regional trial data"
)

struct PlantRelationshipEdgeTests {
    @Test func speciesLevelClaimsRoundTripThroughTheGraph() throws {
        let fixture = try PlantFixture()
        let basil = try fixture.plant("ocimum-basilicum")
        let tomato = try fixture.plant("solanum-lycopersicum")
        let fennel = try fixture.plant("foeniculum-vulgare")

        try fixture.relate(basil, .companionWith, tomato, provenance: curated)
        try fixture.relate(fennel, .antagonisticTo, tomato, provenance: curated)

        let companions = try fixture.outgoing(basil.id, .companionWith)
        #expect(companions.map(\.target) == [tomato])
        #expect(companions.first?.provenance == curated)

        let antagonists = try fixture.incoming(tomato.id, .antagonisticTo)
        #expect(antagonists.map(\.source) == [fennel])
        #expect(antagonists.first?.provenance == curated)
    }

    @Test func familyLevelRotationClaimsRoundTripThroughTheGraph() throws {
        let fixture = try PlantFixture()
        let solanaceae = try fixture.plant("family-solanaceae")
        let brassicaceae = try fixture.plant("family-brassicaceae")
        let provenance = Provenance(
            source: "rotation planner",
            sourceType: .imported,
            confidence: 0.5,
            notes: "four year cycle"
        )

        try fixture.relate(solanaceae, .rotateAwayFrom, brassicaceae, provenance: provenance)

        let outgoing = try fixture.outgoing(solanaceae.id, .rotateAwayFrom)
        #expect(outgoing.map(\.target) == [brassicaceae])
        #expect(outgoing.first?.provenance == provenance)

        let incoming = try fixture.incoming(brassicaceae.id, .rotateAwayFrom)
        #expect(incoming.map(\.source) == [solanaceae])
        #expect(incoming.first?.provenance == provenance)
    }
}

struct PlantRelationshipProvenanceTests {
    @Test(arguments: curatedTypes)
    func curatedClaimsRejectAMissingSource(type: RelationshipType) throws {
        let fixture = try PlantFixture()
        let first = try fixture.plant("plant-a")
        let second = try fixture.plant("plant-b")
        #expect(throws: GraphError.missingProvenance(type)) {
            try fixture.relate(
                first, type, second,
                provenance: Provenance(sourceType: .reference)
            )
        }
    }

    @Test(arguments: curatedTypes)
    func curatedClaimsRejectAMissingSourceType(type: RelationshipType) throws {
        let fixture = try PlantFixture()
        let first = try fixture.plant("plant-a")
        let second = try fixture.plant("plant-b")
        #expect(throws: GraphError.missingProvenance(type)) {
            try fixture.relate(
                first, type, second,
                provenance: Provenance(source: "folklore")
            )
        }
    }

    @Test(arguments: curatedTypes)
    func curatedClaimsRejectEmptyProvenance(type: RelationshipType) throws {
        let fixture = try PlantFixture()
        let first = try fixture.plant("plant-a")
        let second = try fixture.plant("plant-b")
        #expect(throws: GraphError.missingProvenance(type)) {
            try fixture.relate(first, type, second)
        }
    }

    @Test(arguments: curatedTypes)
    func theDatabaseRejectsCuratedRowsWithoutASource(type: RelationshipType) throws {
        let fixture = try PlantFixture()
        let first = try fixture.plant("plant-a")
        let second = try fixture.plant("plant-b")
        #expect(throws: DatabaseError.self) {
            try fixture.insertRaw(
                "raw-1", first, type, second,
                provenance: Provenance(sourceType: .reference))
        }
    }

    @Test(arguments: curatedTypes)
    func theDatabaseRejectsCuratedRowsWithoutASourceType(type: RelationshipType) throws {
        let fixture = try PlantFixture()
        let first = try fixture.plant("plant-a")
        let second = try fixture.plant("plant-b")
        #expect(throws: DatabaseError.self) {
            try fixture.insertRaw(
                "raw-2", first, type, second,
                provenance: Provenance(source: "folklore"))
        }
    }

    @Test func observationalClaimsStillNeedNoProvenance() throws {
        let fixture = try PlantFixture()
        let tomato = try fixture.plant("solanum-lycopersicum")
        let hornworm = try fixture.plant("manduca-quinquemaculata")

        try fixture.relate(tomato, .hostOf, hornworm)

        let edges = try fixture.outgoing(tomato.id, .hostOf)
        #expect(edges.map(\.target) == [hornworm])
        #expect(edges.first?.provenance == Provenance())
    }
}

struct PlantRelationshipConfidenceTests {
    @Test func companionshipWithoutAConfidenceGetsTheCautiousDefault() throws {
        let fixture = try PlantFixture()
        let basil = try fixture.plant("ocimum-basilicum")
        let tomato = try fixture.plant("solanum-lycopersicum")

        let edge = try fixture.relate(
            basil, .companionWith, tomato,
            provenance: Provenance(source: "folklore", sourceType: .inferred)
        )

        #expect(edge.provenance.confidence == 0.3)
        let stored = try fixture.outgoing(basil.id, .companionWith)
        #expect(stored.first?.provenance.confidence == 0.3)
    }

    @Test func anExplicitCompanionshipConfidenceIsPreserved() throws {
        let fixture = try PlantFixture()
        let basil = try fixture.plant("ocimum-basilicum")
        let tomato = try fixture.plant("solanum-lycopersicum")

        let edge = try fixture.relate(
            basil, .companionWith, tomato,
            provenance: Provenance(source: "field trial", sourceType: .observation, confidence: 0.9)
        )

        #expect(edge.provenance.confidence == 0.9)
        let stored = try fixture.outgoing(basil.id, .companionWith)
        #expect(stored.first?.provenance.confidence == 0.9)
    }

    @Test(arguments: [RelationshipType.antagonisticTo, .rotateAwayFrom])
    func otherCuratedClaimsKeepANilConfidence(type: RelationshipType) throws {
        let fixture = try PlantFixture()
        let first = try fixture.plant("plant-a")
        let second = try fixture.plant("plant-b")

        let edge = try fixture.relate(
            first, type, second,
            provenance: Provenance(source: "rotation planner", sourceType: .reference)
        )

        #expect(edge.provenance.confidence == nil)
        let stored = try fixture.outgoing(first.id, type)
        #expect(stored.first?.provenance.confidence == nil)
    }
}

struct PlantRelationshipSymmetryTests {
    @Test(arguments: [RelationshipType.companionWith, .antagonisticTo])
    func aClaimPointsOnlyOneWay(type: RelationshipType) throws {
        let fixture = try PlantFixture()
        let first = try fixture.plant("plant-a")
        let second = try fixture.plant("plant-b")

        try fixture.relate(first, type, second, provenance: curated)

        #expect(try fixture.outgoing(second.id, type).isEmpty)
        #expect(try fixture.incoming(first.id, type).isEmpty)
    }

    @Test(arguments: [RelationshipType.companionWith, .antagonisticTo])
    func aBidirectionalClaimIsTwoEdgesWithTheirOwnProvenance(type: RelationshipType) throws {
        let fixture = try PlantFixture()
        let first = try fixture.plant("plant-a")
        let second = try fixture.plant("plant-b")
        let forward = Provenance(
            source: "trial north", sourceType: .observation, confidence: 0.8, notes: "outbound")
        let backward = Provenance(
            source: "trial south", sourceType: .reference, confidence: 0.6, notes: "inbound")

        try fixture.relate(first, type, second, provenance: forward)
        try fixture.relate(second, type, first, provenance: backward)

        let outbound = try fixture.outgoing(first.id, type)
        #expect(outbound.map(\.target) == [second])
        #expect(outbound.first?.provenance == forward)
        let inbound = try fixture.outgoing(second.id, type)
        #expect(inbound.map(\.target) == [first])
        #expect(inbound.first?.provenance == backward)
    }
}

struct PlantRelationshipDeleteTests {
    @Test func deletingTheSourcePlantLeavesNoEdgesBehind() throws {
        let fixture = try PlantFixture()
        let basil = try fixture.plant("ocimum-basilicum")
        let tomato = try fixture.plant("solanum-lycopersicum")
        try fixture.relate(basil, .companionWith, tomato, provenance: curated)
        try fixture.relate(tomato, .antagonisticTo, basil, provenance: curated)

        try fixture.database.writer.write { db in
            try GraphStore.deleteEntity(basil.id, in: db)
        }

        #expect(try fixture.edgeCount(referencing: basil.id) == 0)
        #expect(try fixture.edgeCount(referencing: tomato.id) == 0)
    }

    @Test func deletingTheTargetPlantLeavesNoEdgesBehind() throws {
        let fixture = try PlantFixture()
        let solanaceae = try fixture.plant("family-solanaceae")
        let brassicaceae = try fixture.plant("family-brassicaceae")
        try fixture.relate(solanaceae, .rotateAwayFrom, brassicaceae, provenance: curated)

        try fixture.database.writer.write { db in
            try GraphStore.deleteEntity(brassicaceae.id, in: db)
        }

        #expect(try fixture.edgeCount(referencing: brassicaceae.id) == 0)
        #expect(try fixture.edgeCount(referencing: solanaceae.id) == 0)
    }
}

struct PlantRelationshipMigrationTests {
    private func seededQueue() throws -> DatabaseQueue {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: plantRelationshipIdentifier))
        try #require(index > 0)
        let queue = try MigrationHarness.database(through: identifiers[index - 1])
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('b1', 'bed')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('g1', 'garden')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('p1', 'plant')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('p2', 'plant')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('x1', 'pest')")
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
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e3', 'p1', 'HOST_OF', 'x1')
                    """
            )
        }
        return queue
    }

    @Test func existingEdgesSurviveTheRelationshipRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let rows = try queue.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM relationship ORDER BY id")
        }
        #expect(rows.count == 3)
        #expect(rows[0]["from_entity_id"] == "b1")
        #expect(rows[0]["relationship_type"] == "LOCATED_IN")
        #expect(rows[0]["to_entity_id"] == "g1")
        #expect(rows[0]["source"] == "site survey")
        #expect(rows[0]["source_type"] == "observation")
        #expect(rows[0]["confidence"] == 0.95)
        #expect(rows[0]["notes"] == "north wall")
        #expect(rows[1]["from_entity_id"] == "p1")
        #expect(rows[1]["relationship_type"] == "COMPANION_WITH")
        #expect(rows[1]["to_entity_id"] == "p2")
        #expect(rows[1]["source"] == "companion guide")
        #expect(rows[1]["source_type"] == "reference")
        #expect(rows[1]["confidence"] == 0.4)
        #expect(rows[1]["notes"] == "anecdotal")
        #expect(rows[2]["from_entity_id"] == "p1")
        #expect(rows[2]["relationship_type"] == "HOST_OF")
        #expect(rows[2]["to_entity_id"] == "x1")
        #expect((rows[2]["source"] as String?) == nil)
        #expect((rows[2]["source_type"] as String?) == nil)
        #expect((rows[2]["confidence"] as Double?) == nil)
        #expect((rows[2]["notes"] as String?) == nil)
    }

    @Test func theWidenedCheckAcceptsPlantRelationshipsOnly() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id,
                         source, source_type)
                    VALUES ('e4', 'p2', 'ANTAGONISTIC_TO', 'p1',
                            'companion guide', 'reference')
                    """
            )
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id,
                         source, source_type)
                    VALUES ('e5', 'p2', 'ROTATE_AWAY_FROM', 'p1',
                            'rotation planner', 'imported')
                    """
            )
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id,
                             source, source_type)
                        VALUES ('e6', 'p2', 'CROWDED_BY', 'p1',
                                'rotation planner', 'imported')
                        """
                )
            }
        }
    }

    @Test func theProvenanceCheckRejectsCuratedRowsAtHead() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e7', 'p2', 'COMPANION_WITH', 'p1')
                        """
                )
            }
        }
    }

    @Test func endpointIndexesSurviveThePlantRelationshipRebuild() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        let names = try queue.read { db in
            try db.indexes(on: "relationship").map(\.name)
        }
        #expect(names.contains("relationship_from"))
        #expect(names.contains("relationship_to"))
        #expect(names.contains("relationship_single_located_in_parent"))
    }
}
