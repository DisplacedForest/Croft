import GRDB

extension SchemaMigrations {
    static let applyHarvests: @Sendable (Database) throws -> Void = { db in
        try createHarvestTable(db)
        try rebuildEntityTableForHarvests(db)
        try rebuildRelationshipTableForHarvests(db)
    }

    private static func createHarvestTable(_ db: Database) throws {
        try db.execute(
            sql: """
                CREATE TABLE harvest (
                    id TEXT PRIMARY KEY NOT NULL,
                    planting_id TEXT NOT NULL
                        REFERENCES planting(id) ON DELETE RESTRICT,
                    harvested_on DATETIME NOT NULL,
                    quantity REAL NOT NULL CHECK (quantity > 0),
                    unit TEXT NOT NULL CHECK (
                        unit IN (
                            'gram', 'kilogram', 'ounce', 'pound',
                            'count', 'bunch', 'custom'
                        )
                    ),
                    custom_unit TEXT,
                    quality TEXT CHECK (
                        quality IN ('excellent', 'good', 'fair', 'poor')
                    ),
                    notes TEXT,
                    CHECK ((unit = 'custom') = (custom_unit IS NOT NULL))
                )
                """
        )
        try db.execute(sql: "CREATE INDEX harvest_on_planting_id ON harvest(planting_id)")
    }

    private static func rebuildEntityTableForHarvests(_ db: Database) throws {
        try db.execute(
            sql: """
                CREATE TABLE entity_new (
                    id TEXT PRIMARY KEY NOT NULL,
                    entity_type TEXT NOT NULL CHECK (
                        entity_type IN (
                            'plant', 'pest', 'disease', 'seed_lot', 'planting',
                            'property', 'garden', 'growing_area', 'bed',
                            'pathogen', 'environmental_condition', 'starter_batch',
                            'observation', 'harvest'
                        )
                    )
                )
                """
        )
        try db.execute(sql: "INSERT INTO entity_new SELECT id, entity_type FROM entity")
        try db.execute(sql: "DROP TABLE entity")
        try db.execute(sql: "ALTER TABLE entity_new RENAME TO entity")
        try createEntityRestrictTriggersForHarvests(db)
    }

    private static let restrictedTargets = [
        ("LOCATED_IN", "entity_located_in_restrict", "entity is a LOCATED_IN target"),
        ("OBSERVED_ON", "entity_observed_on_restrict", "entity is an OBSERVED_ON target"),
        ("HARVESTED_FROM", "entity_harvested_from_restrict", "entity is a HARVESTED_FROM target"),
    ]

    private static func createEntityRestrictTriggersForHarvests(_ db: Database) throws {
        for (type, trigger, message) in restrictedTargets {
            try db.execute(
                sql: """
                    CREATE TRIGGER \(trigger)
                    BEFORE DELETE ON entity
                    FOR EACH ROW
                    WHEN EXISTS (
                        SELECT 1 FROM relationship
                        WHERE to_entity_id = OLD.id
                        AND relationship_type = '\(type)'
                    )
                    BEGIN
                        SELECT RAISE(ABORT, '\(message)');
                    END
                    """
            )
        }
    }

    private static func rebuildRelationshipTableForHarvests(_ db: Database) throws {
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
                            'OBSERVED_ON', 'HARVESTED_FROM'
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
        try createRelationshipIndexesForHarvests(db)
    }

    private static let harvestSingleCardinalityIndexes = [
        ("LOCATED_IN", "relationship_single_located_in_parent"),
        ("INSTANCE_OF", "relationship_single_instance_of"),
        ("LOT_OF", "relationship_single_lot_of"),
        ("SOWN_FROM", "relationship_single_sown_from"),
        ("OBSERVED_ON", "relationship_single_observed_on"),
        ("HARVESTED_FROM", "relationship_single_harvested_from"),
    ]

    private static func createRelationshipIndexesForHarvests(_ db: Database) throws {
        try db.execute(sql: "CREATE INDEX relationship_from ON relationship(from_entity_id)")
        try db.execute(sql: "CREATE INDEX relationship_to ON relationship(to_entity_id)")
        for (type, index) in harvestSingleCardinalityIndexes {
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
