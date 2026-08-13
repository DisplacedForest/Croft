import GRDB

extension SchemaMigrations {
    static let applyGardenTasks: @Sendable (Database) throws -> Void = { db in
        try createTaskTable(db)
        try rebuildEntityTableForTasks(db)
        try rebuildRelationshipTableForTasks(db)
    }

    private static func createTaskTable(_ db: Database) throws {
        try db.execute(
            sql: """
                CREATE TABLE task (
                    id TEXT PRIMARY KEY NOT NULL,
                    type TEXT NOT NULL CHECK (
                        type IN (
                            'water', 'fertilize', 'prune', 'trellis', 'thin',
                            'transplant', 'inspect', 'harvest', 'treat', 'other'
                        )
                    ),
                    custom_type TEXT,
                    title TEXT NOT NULL,
                    notes TEXT,
                    due_on DATETIME,
                    completed INTEGER NOT NULL DEFAULT 0,
                    completed_on DATETIME,
                    garden_id TEXT REFERENCES garden(id) ON DELETE RESTRICT,
                    bed_id TEXT REFERENCES bed(id) ON DELETE RESTRICT,
                    planting_id TEXT REFERENCES planting(id) ON DELETE RESTRICT,
                    CHECK ((type = 'other') = (custom_type IS NOT NULL)),
                    CHECK ((completed != 0) = (completed_on IS NOT NULL)),
                    CHECK (
                        (garden_id IS NOT NULL)
                        + (bed_id IS NOT NULL)
                        + (planting_id IS NOT NULL) <= 1
                    )
                )
                """
        )
        try db.execute(sql: "CREATE INDEX task_on_garden_id ON task(garden_id)")
        try db.execute(sql: "CREATE INDEX task_on_bed_id ON task(bed_id)")
        try db.execute(sql: "CREATE INDEX task_on_planting_id ON task(planting_id)")
    }

    private static func rebuildEntityTableForTasks(_ db: Database) throws {
        try db.execute(
            sql: """
                CREATE TABLE entity_new (
                    id TEXT PRIMARY KEY NOT NULL,
                    entity_type TEXT NOT NULL CHECK (
                        entity_type IN (
                            'plant', 'pest', 'disease', 'seed_lot', 'planting',
                            'property', 'garden', 'growing_area', 'bed',
                            'pathogen', 'environmental_condition', 'starter_batch',
                            'observation', 'harvest', 'task'
                        )
                    )
                )
                """
        )
        try db.execute(sql: "INSERT INTO entity_new SELECT id, entity_type FROM entity")
        try db.execute(sql: "DROP TABLE entity")
        try db.execute(sql: "ALTER TABLE entity_new RENAME TO entity")
        try createEntityRestrictTriggersForTasks(db)
    }

    private static let taskRestrictedTargets = [
        ("LOCATED_IN", "entity_located_in_restrict", "entity is a LOCATED_IN target"),
        ("OBSERVED_ON", "entity_observed_on_restrict", "entity is an OBSERVED_ON target"),
        ("HARVESTED_FROM", "entity_harvested_from_restrict", "entity is a HARVESTED_FROM target"),
        ("TASK_FOR", "entity_task_for_restrict", "entity is a TASK_FOR target"),
    ]

    private static func createEntityRestrictTriggersForTasks(_ db: Database) throws {
        for (type, trigger, message) in taskRestrictedTargets {
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

    private static func rebuildRelationshipTableForTasks(_ db: Database) throws {
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
                            'OBSERVED_ON', 'HARVESTED_FROM',
                            'TASK_FOR'
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
        try createRelationshipIndexesForTasks(db)
    }

    private static let taskSingleCardinalityIndexes = [
        ("LOCATED_IN", "relationship_single_located_in_parent"),
        ("INSTANCE_OF", "relationship_single_instance_of"),
        ("LOT_OF", "relationship_single_lot_of"),
        ("SOWN_FROM", "relationship_single_sown_from"),
        ("OBSERVED_ON", "relationship_single_observed_on"),
        ("HARVESTED_FROM", "relationship_single_harvested_from"),
        ("TASK_FOR", "relationship_single_task_for"),
    ]

    private static func createRelationshipIndexesForTasks(_ db: Database) throws {
        try db.execute(sql: "CREATE INDEX relationship_from ON relationship(from_entity_id)")
        try db.execute(sql: "CREATE INDEX relationship_to ON relationship(to_entity_id)")
        for (type, index) in taskSingleCardinalityIndexes {
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
