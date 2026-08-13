import GRDB

extension SchemaMigrations {
    static let applyEdgeCardinality: @Sendable (Database) throws -> Void = { db in
        let singleCardinalityTypes = [
            ("INSTANCE_OF", "relationship_single_instance_of"),
            ("LOT_OF", "relationship_single_lot_of"),
            ("SOWN_FROM", "relationship_single_sown_from"),
        ]
        for (type, index) in singleCardinalityTypes {
            try db.execute(
                sql: """
                    DELETE FROM relationship
                    WHERE relationship_type = :type
                    AND id NOT IN (
                        SELECT MIN(id) FROM relationship
                        WHERE relationship_type = :type
                        GROUP BY from_entity_id
                    )
                    """,
                arguments: ["type": type]
            )
            try db.execute(
                sql: """
                    CREATE UNIQUE INDEX \(index)
                    ON relationship(from_entity_id)
                    WHERE relationship_type = '\(type)'
                    """
            )
        }
    }
}
