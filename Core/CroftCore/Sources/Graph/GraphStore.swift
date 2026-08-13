import Foundation
import GRDB

public enum GraphStore {
    public static func register(_ ref: EntityRef, in db: Database) throws {
        try db.execute(
            sql: "INSERT OR IGNORE INTO entity (id, entity_type) VALUES (?, ?)",
            arguments: [ref.id, ref.type.rawValue]
        )
        guard let stored = try registered(ref.id, in: db), stored.type != ref.type else {
            return
        }
        throw GraphError.entityTypeMismatch(
            id: ref.id, stored: stored.type, requested: ref.type)
    }

    public static func registered(_ id: String, in db: Database) throws -> EntityRef? {
        guard
            let raw = try String.fetchOne(
                db,
                sql: "SELECT entity_type FROM entity WHERE id = ?",
                arguments: [id]
            )
        else {
            return nil
        }
        guard let type = EntityType(rawValue: raw) else {
            throw GraphError.unknownEntityType(raw)
        }
        return EntityRef(id: id, type: type)
    }

    public static func deleteEntity(_ id: String, in db: Database) throws {
        try db.execute(sql: "DELETE FROM entity WHERE id = ?", arguments: [id])
    }

    @discardableResult
    public static func relate(
        from source: EntityRef,
        _ type: RelationshipType,
        to target: EntityRef,
        provenance: Provenance = Provenance(),
        edgeID: String? = nil,
        in db: Database
    ) throws -> Edge {
        let attributed = provenance.source != nil && provenance.sourceType != nil
        if type.requiresProvenance && !attributed {
            throw GraphError.missingProvenance(type)
        }
        var effective = provenance
        if effective.confidence == nil, let confidence = type.defaultConfidence {
            effective.confidence = confidence
        }
        let id = edgeID ?? UUID().uuidString
        try db.execute(
            sql: """
                INSERT INTO relationship
                    (id, from_entity_id, relationship_type, to_entity_id,
                     source, source_type, confidence, notes)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
            arguments: [
                id, source.id, type.rawValue, target.id,
                effective.source, effective.sourceType?.rawValue,
                effective.confidence, effective.notes,
            ]
        )
        return Edge(id: id, source: source, type: type, target: target, provenance: effective)
    }

    public static func unrelate(edgeID: String, in db: Database) throws {
        try db.execute(sql: "DELETE FROM relationship WHERE id = ?", arguments: [edgeID])
    }

    public static func outgoing(
        from id: String,
        via type: RelationshipType,
        in db: Database
    ) throws -> [Edge] {
        try edges(anchoredAt: .source, id: id, type: type, in: db)
    }

    public static func incoming(
        to id: String,
        via type: RelationshipType,
        in db: Database
    ) throws -> [Edge] {
        try edges(anchoredAt: .target, id: id, type: type, in: db)
    }

    public static func resolve<Model>(
        _ refs: [EntityRef],
        as model: Model.Type,
        in db: Database
    ) throws -> [Model] where Model: FetchableRecord & TableRecord & GraphEntity {
        let ids = refs.filter { $0.type == Model.entityType }.map(\.id)
        guard !ids.isEmpty else {
            return []
        }
        let fetched = try Model.fetchAll(db, keys: ids)
        let modelsByID = Dictionary(
            fetched.map { ($0.entityID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return try ids.map { id in
            guard let model = modelsByID[id] else {
                throw GraphError.unresolvedEntity(id)
            }
            return model
        }
    }

    private enum Endpoint {
        case source
        case target

        var column: String {
            switch self {
            case .source: "from_entity_id"
            case .target: "to_entity_id"
            }
        }
    }

    private static func edges(
        anchoredAt endpoint: Endpoint,
        id: String,
        type: RelationshipType,
        in db: Database
    ) throws -> [Edge] {
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT
                    r.id AS id,
                    r.from_entity_id AS from_id,
                    ef.entity_type AS from_type,
                    r.relationship_type AS relationship_type,
                    r.to_entity_id AS to_id,
                    et.entity_type AS to_type,
                    r.source AS source,
                    r.source_type AS source_type,
                    r.confidence AS confidence,
                    r.notes AS notes
                FROM relationship r
                JOIN entity ef ON ef.id = r.from_entity_id
                JOIN entity et ON et.id = r.to_entity_id
                WHERE r.\(endpoint.column) = ? AND r.relationship_type = ?
                ORDER BY r.id
                """,
            arguments: [id, type.rawValue]
        )
        return try rows.map(edge(from:))
    }

    private static func edge(from row: Row) throws -> Edge {
        guard let fromType = EntityType(rawValue: row["from_type"]) else {
            throw GraphError.unknownEntityType(row["from_type"])
        }
        guard let toType = EntityType(rawValue: row["to_type"]) else {
            throw GraphError.unknownEntityType(row["to_type"])
        }
        guard let relationshipType = RelationshipType(rawValue: row["relationship_type"]) else {
            throw GraphError.unknownRelationshipType(row["relationship_type"])
        }
        let sourceType = try (row["source_type"] as String?).map { raw in
            guard let sourceType = SourceType(rawValue: raw) else {
                throw GraphError.unknownSourceType(raw)
            }
            return sourceType
        }
        return Edge(
            id: row["id"],
            source: EntityRef(id: row["from_id"], type: fromType),
            type: relationshipType,
            target: EntityRef(id: row["to_id"], type: toType),
            provenance: Provenance(
                source: row["source"],
                sourceType: sourceType,
                confidence: row["confidence"],
                notes: row["notes"]
            )
        )
    }
}
