import GRDB

extension SchemaMigrations {
    static let applySeedLots: @Sendable (Database) throws -> Void = { db in
        try db.execute(
            sql: """
                CREATE TABLE seed_lot (
                    id TEXT PRIMARY KEY NOT NULL,
                    cultivar_id TEXT NOT NULL
                        REFERENCES cultivar(id) ON DELETE RESTRICT,
                    source TEXT,
                    acquired_on DATETIME,
                    quantity TEXT,
                    seed_count INTEGER,
                    notes TEXT
                )
                """
        )
        try db.execute(sql: "CREATE INDEX seed_lot_on_cultivar_id ON seed_lot(cultivar_id)")
        try db.execute(
            sql: """
                CREATE TABLE starter_batch (
                    id TEXT PRIMARY KEY NOT NULL,
                    seed_lot_id TEXT NOT NULL
                        REFERENCES seed_lot(id) ON DELETE RESTRICT,
                    sown_on DATETIME,
                    quantity INTEGER,
                    status TEXT NOT NULL CHECK (
                        status IN ('sown', 'growing', 'transplanted', 'failed')
                    )
                )
                """
        )
        try db.execute(
            sql: "CREATE INDEX starter_batch_on_seed_lot_id ON starter_batch(seed_lot_id)")
        try rebuildEntityTableForSeedLots(db)
        try rebuildRelationshipTableForSeedLots(db)
    }

    private static func rebuildEntityTableForSeedLots(_ db: Database) throws {
        try db.execute(
            sql: """
                CREATE TABLE entity_new (
                    id TEXT PRIMARY KEY NOT NULL,
                    entity_type TEXT NOT NULL CHECK (
                        entity_type IN (
                            'plant', 'pest', 'disease', 'seed_lot', 'planting',
                            'property', 'garden', 'growing_area', 'bed',
                            'pathogen', 'environmental_condition', 'starter_batch'
                        )
                    )
                )
                """
        )
        try db.execute(sql: "INSERT INTO entity_new SELECT id, entity_type FROM entity")
        try db.execute(sql: "DROP TABLE entity")
        try db.execute(sql: "ALTER TABLE entity_new RENAME TO entity")
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
    }

    private static func rebuildRelationshipTableForSeedLots(_ db: Database) throws {
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
                            'LOT_OF', 'SOWN_FROM'
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
