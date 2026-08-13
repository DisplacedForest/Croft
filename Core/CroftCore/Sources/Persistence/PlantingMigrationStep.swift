import GRDB

extension SchemaMigrations {
    static let applyPlantings: @Sendable (Database) throws -> Void = { db in
        try db.execute(
            sql: """
                CREATE TABLE planting (
                    id TEXT PRIMARY KEY NOT NULL,
                    cultivar_id TEXT
                        REFERENCES cultivar(id) ON DELETE RESTRICT,
                    species_id TEXT
                        REFERENCES species(id) ON DELETE RESTRICT,
                    bed_id TEXT NOT NULL
                        REFERENCES bed(id) ON DELETE RESTRICT,
                    seed_lot_id TEXT
                        REFERENCES seed_lot(id) ON DELETE RESTRICT,
                    starter_batch_id TEXT
                        REFERENCES starter_batch(id) ON DELETE RESTRICT,
                    planted_on DATETIME,
                    transplanted_on DATETIME,
                    quantity INTEGER,
                    spacing_cm REAL,
                    status TEXT NOT NULL CHECK (
                        status IN ('planned', 'active', 'finished', 'failed')
                    ),
                    expected_maturity_on DATETIME,
                    ended_on DATETIME,
                    notes TEXT,
                    CHECK ((cultivar_id IS NULL) != (species_id IS NULL)),
                    CHECK (seed_lot_id IS NULL OR starter_batch_id IS NULL)
                )
                """
        )
        for column in ["cultivar_id", "species_id", "bed_id", "seed_lot_id", "starter_batch_id"] {
            try db.execute(sql: "CREATE INDEX planting_on_\(column) ON planting(\(column))")
        }
        try rebuildRelationshipTableForPlantings(db)
    }

    private static func rebuildRelationshipTableForPlantings(_ db: Database) throws {
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
                            'INSTANCE_OF', 'PLANTED_FROM'
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
