import GRDB

extension SchemaMigrations {
    static let applyObservations: @Sendable (Database) throws -> Void = { db in
        try createObservationTable(db)
        try createObservationPhotoTable(db)
        try rebuildEntityTableForObservations(db)
        try rebuildRelationshipTableForObservations(db)
    }

    private static let observationTargetColumns = [
        "planting_id", "cultivar_id", "species_id", "bed_id", "garden_id",
    ]

    private static func createObservationTable(_ db: Database) throws {
        try db.execute(
            sql: """
                CREATE TABLE observation (
                    id TEXT PRIMARY KEY NOT NULL,
                    planting_id TEXT
                        REFERENCES planting(id) ON DELETE RESTRICT,
                    cultivar_id TEXT
                        REFERENCES cultivar(id) ON DELETE RESTRICT,
                    species_id TEXT
                        REFERENCES species(id) ON DELETE RESTRICT,
                    bed_id TEXT
                        REFERENCES bed(id) ON DELETE RESTRICT,
                    garden_id TEXT
                        REFERENCES garden(id) ON DELETE RESTRICT,
                    observed_at DATETIME NOT NULL,
                    notes TEXT,
                    growth_state TEXT,
                    symptoms TEXT NOT NULL DEFAULT '[]',
                    measurements TEXT NOT NULL DEFAULT '[]',
                    tags TEXT NOT NULL DEFAULT '[]',
                    CHECK (
                        (planting_id IS NOT NULL) + (cultivar_id IS NOT NULL)
                        + (species_id IS NOT NULL) + (bed_id IS NOT NULL)
                        + (garden_id IS NOT NULL) = 1
                    )
                )
                """
        )
        for column in observationTargetColumns {
            try db.execute(sql: "CREATE INDEX observation_on_\(column) ON observation(\(column))")
        }
    }

    private static func createObservationPhotoTable(_ db: Database) throws {
        try db.execute(
            sql: """
                CREATE TABLE observation_photo (
                    id TEXT PRIMARY KEY NOT NULL,
                    observation_id TEXT NOT NULL
                        REFERENCES observation(id) ON DELETE CASCADE,
                    relative_path TEXT NOT NULL UNIQUE,
                    created_at DATETIME NOT NULL
                )
                """
        )
        try db.execute(
            sql: """
                CREATE INDEX observation_photo_on_observation_id
                ON observation_photo(observation_id)
                """
        )
    }

    private static func rebuildEntityTableForObservations(_ db: Database) throws {
        try db.execute(
            sql: """
                CREATE TABLE entity_new (
                    id TEXT PRIMARY KEY NOT NULL,
                    entity_type TEXT NOT NULL CHECK (
                        entity_type IN (
                            'plant', 'pest', 'disease', 'seed_lot', 'planting',
                            'property', 'garden', 'growing_area', 'bed',
                            'pathogen', 'environmental_condition', 'starter_batch',
                            'observation'
                        )
                    )
                )
                """
        )
        try db.execute(sql: "INSERT INTO entity_new SELECT id, entity_type FROM entity")
        try db.execute(sql: "DROP TABLE entity")
        try db.execute(sql: "ALTER TABLE entity_new RENAME TO entity")
        try createEntityRestrictTriggers(db)
    }

    private static func createEntityRestrictTriggers(_ db: Database) throws {
        try db.execute(
            sql: """
                CREATE TRIGGER entity_located_in_restrict
                BEFORE DELETE ON entity
                FOR EACH ROW
                WHEN EXISTS (
                    SELECT 1 FROM relationship
                    WHERE to_entity_id = OLD.id
                    AND relationship_type = 'LOCATED_IN'
                )
                BEGIN
                    SELECT RAISE(ABORT, 'entity is a LOCATED_IN target');
                END
                """
        )
        try db.execute(
            sql: """
                CREATE TRIGGER entity_observed_on_restrict
                BEFORE DELETE ON entity
                FOR EACH ROW
                WHEN EXISTS (
                    SELECT 1 FROM relationship
                    WHERE to_entity_id = OLD.id
                    AND relationship_type = 'OBSERVED_ON'
                )
                BEGIN
                    SELECT RAISE(ABORT, 'entity is an OBSERVED_ON target');
                END
                """
        )
    }

    private static func rebuildRelationshipTableForObservations(_ db: Database) throws {
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
                            'VECTOR_OF', 'RESISTANT_TO',
                            'OBSERVED_ON'
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
        try createRelationshipIndexesForObservations(db)
    }

    private static let singleCardinalityIndexes = [
        ("LOCATED_IN", "relationship_single_located_in_parent"),
        ("INSTANCE_OF", "relationship_single_instance_of"),
        ("LOT_OF", "relationship_single_lot_of"),
        ("SOWN_FROM", "relationship_single_sown_from"),
        ("OBSERVED_ON", "relationship_single_observed_on"),
    ]

    private static func createRelationshipIndexesForObservations(_ db: Database) throws {
        try db.execute(sql: "CREATE INDEX relationship_from ON relationship(from_entity_id)")
        try db.execute(sql: "CREATE INDEX relationship_to ON relationship(to_entity_id)")
        for (type, index) in singleCardinalityIndexes {
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
