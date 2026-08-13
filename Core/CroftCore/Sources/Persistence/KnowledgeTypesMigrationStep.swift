import GRDB

extension SchemaMigrations {
    static let applyKnowledgeTypes: @Sendable (Database) throws -> Void = { db in
        try db.execute(
            sql: """
                CREATE TABLE relationship_new (
                    id TEXT PRIMARY KEY NOT NULL,
                    from_entity_id TEXT NOT NULL
                        REFERENCES entity(id) ON DELETE CASCADE,
                    relationship_type TEXT NOT NULL CHECK (
                        relationship_type IN (
                            'SUSCEPTIBLE_TO', 'HOST_OF',
                            'COMPANION_WITH', 'LOCATED_IN',
                            'PARASITIZED_BY', 'PREDATED_BY',
                            'ANTAGONISTIC_TO', 'ROTATE_AWAY_FROM',
                            'CAUSED_BY', 'FAVORED_BY',
                            'LOT_OF', 'SOWN_FROM',
                            'INSTANCE_OF', 'PLANTED_FROM',
                            'VECTOR_OF', 'RESISTANT_TO'
                        )
                    ),
                    to_entity_id TEXT NOT NULL
                        REFERENCES entity(id) ON DELETE CASCADE,
                    source TEXT,
                    source_type TEXT CHECK (
                        source_type IN (
                            'observation', 'reference', 'imported', 'inferred'
                        )
                    ),
                    confidence REAL CHECK (confidence BETWEEN 0.0 AND 1.0),
                    notes TEXT,
                    UNIQUE (from_entity_id, relationship_type, to_entity_id),
                    CHECK (
                        relationship_type NOT IN (
                            'COMPANION_WITH', 'ANTAGONISTIC_TO', 'ROTATE_AWAY_FROM'
                        )
                        OR (source IS NOT NULL AND source_type IS NOT NULL)
                    )
                )
                """
        )
        try rebuildDiseaseTableForKnowledgeTypes(db)
        try db.execute(sql: "INSERT INTO relationship_new SELECT * FROM relationship")
        try db.execute(sql: "DROP TABLE relationship")
        try db.execute(sql: "ALTER TABLE relationship_new RENAME TO relationship")
        try db.execute(sql: "CREATE INDEX relationship_from ON relationship(from_entity_id)")
        try db.execute(sql: "CREATE INDEX relationship_to ON relationship(to_entity_id)")
        try db.execute(
            sql: """
                CREATE UNIQUE INDEX relationship_single_located_in_parent
                ON relationship(from_entity_id)
                WHERE relationship_type = 'LOCATED_IN'
                """
        )
    }
}

extension SchemaMigrations {
    private static func rebuildDiseaseTableForKnowledgeTypes(_ db: Database) throws {
        try db.execute(
            sql: """
                CREATE TABLE disease_new (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    pathogen TEXT,
                    pathogen_type TEXT NOT NULL CHECK (
                        pathogen_type IN (
                            'fungal', 'bacterial', 'viral',
                            'oomycete', 'nematode', 'physiological',
                            'phytoplasma', 'protist'
                        )
                    ),
                    symptoms TEXT,
                    affected_plant_parts TEXT NOT NULL DEFAULT '[]',
                    transmission TEXT,
                    prevention TEXT NOT NULL DEFAULT '[]',
                    management TEXT NOT NULL DEFAULT '[]'
                )
                """
        )
        try db.execute(sql: "INSERT INTO disease_new SELECT * FROM disease")
        try db.execute(sql: "DROP TABLE disease")
        try db.execute(sql: "ALTER TABLE disease_new RENAME TO disease")
    }
}
