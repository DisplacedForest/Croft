import Foundation
import GRDB
import Graph
import Testing

@testable import Persistence

struct KnowledgeRelationshipMigrationTests {
    private let identifier = "v011-knowledge-types"

    private func seededQueue() throws -> DatabaseQueue {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: identifier))
        try #require(index > 0)
        let queue = try MigrationHarness.database(through: identifiers[index - 1])
        try queue.write { db in
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('p1', 'plant')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('p2', 'plant')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('x1', 'pest')")
            try db.execute(sql: "INSERT INTO entity (id, entity_type) VALUES ('d1', 'disease')")
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id,
                         source, source_type, confidence, notes)
                    VALUES ('e1', 'p1', 'COMPANION_WITH', 'p2',
                            'trial notes', 'reference', 0.4, 'paired well')
                    """
            )
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e2', 'p1', 'HOST_OF', 'x1')
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
        #expect(rows.first?["relationship_type"] == "COMPANION_WITH")
        #expect(rows.first?["source"] == "trial notes")
        #expect(rows.first?["confidence"] == 0.4)
        #expect(rows.last?["relationship_type"] == "HOST_OF")
    }

    @Test func theWidenedCheckAcceptsTheKnowledgeTypesOnly() throws {
        let queue = try seededQueue()
        try MigrationHarness.migrateToHead(queue)
        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e3', 'x1', 'VECTOR_OF', 'd1')
                    """
            )
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id)
                    VALUES ('e4', 'p1', 'RESISTANT_TO', 'd1')
                    """
            )
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO relationship
                            (id, from_entity_id, relationship_type, to_entity_id)
                        VALUES ('e5', 'p1', 'IMMUNE_TO', 'd1')
                        """
                )
            }
        }
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
                        VALUES ('e6', 'p2', 'COMPANION_WITH', 'p1')
                        """
                )
            }
        }
    }

    @Test func diseaseRowsSurviveThePathogenTypeWidening() throws {
        let queue = try seededQueue()
        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO disease (id, name, pathogen_type, symptoms)
                    VALUES ('d2', 'Early blight', 'fungal', 'target-ring spots')
                    """
            )
        }
        try MigrationHarness.migrateToHead(queue)
        let row = try queue.read { db in
            try Row.fetchOne(db, sql: "SELECT * FROM disease WHERE id = 'd2'")
        }
        #expect(row?["name"] == "Early blight")
        #expect(row?["pathogen_type"] == "fungal")
        #expect(row?["symptoms"] == "target-ring spots")
        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO disease (id, name, pathogen_type)
                    VALUES ('d3', 'Aster yellows', 'phytoplasma')
                    """
            )
            try db.execute(
                sql: """
                    INSERT INTO disease (id, name, pathogen_type)
                    VALUES ('d4', 'Clubroot', 'protist')
                    """
            )
        }
        #expect(throws: DatabaseError.self) {
            try queue.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO disease (id, name, pathogen_type)
                        VALUES ('d5', 'Mystery', 'curse')
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
}
