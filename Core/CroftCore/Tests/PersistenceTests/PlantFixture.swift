import GRDB
import Graph
import Testing

@testable import Persistence

let plantRelationshipIdentifier = "v006-plant-relationships"

struct PlantFixture {
    let database: AppDatabase

    init() throws {
        database = try AppDatabase.inMemory()
    }

    func plant(_ id: String) throws -> EntityRef {
        let ref = EntityRef(id: id, type: .plant)
        try database.writer.write { db in
            try GraphStore.register(ref, in: db)
        }
        return ref
    }

    @discardableResult
    func relate(
        _ source: EntityRef,
        _ type: RelationshipType,
        _ target: EntityRef,
        provenance: Provenance = Provenance()
    ) throws -> Edge {
        try database.writer.write { db in
            try GraphStore.relate(
                from: source, type, to: target, provenance: provenance, in: db)
        }
    }

    func outgoing(_ id: String, _ type: RelationshipType) throws -> [Edge] {
        try database.writer.read { db in
            try GraphStore.outgoing(from: id, via: type, in: db)
        }
    }

    func incoming(_ id: String, _ type: RelationshipType) throws -> [Edge] {
        try database.writer.read { db in
            try GraphStore.incoming(to: id, via: type, in: db)
        }
    }

    func edgeCount(referencing id: String) throws -> Int? {
        try database.writer.read { db in
            try Int.fetchOne(
                db,
                sql: """
                    SELECT COUNT(*) FROM relationship
                    WHERE from_entity_id = ? OR to_entity_id = ?
                    """,
                arguments: [id, id]
            )
        }
    }

    func insertRaw(
        _ id: String,
        _ from: EntityRef,
        _ type: RelationshipType,
        _ target: EntityRef,
        provenance: Provenance
    ) throws {
        try database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO relationship
                        (id, from_entity_id, relationship_type, to_entity_id,
                         source, source_type)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                arguments: [
                    id, from.id, type.rawValue, target.id,
                    provenance.source, provenance.sourceType?.rawValue,
                ]
            )
        }
    }
}
