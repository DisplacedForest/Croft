import GRDB

extension SchemaMigrations {
    static let applyBaseline: @Sendable (Database) throws -> Void = { db in
        try db.execute(sql: "PRAGMA application_id = \(databaseApplicationID)")
    }

    static let applyGraph: @Sendable (Database) throws -> Void = { db in
        try db.execute(
            sql: """
                CREATE TABLE entity (
                    id TEXT PRIMARY KEY NOT NULL,
                    entity_type TEXT NOT NULL CHECK (
                        entity_type IN (
                            'plant', 'pest', 'disease',
                            'garden_location', 'seed_lot', 'planting'
                        )
                    )
                )
                """
        )
        try db.execute(
            sql: """
                CREATE TABLE relationship (
                    id TEXT PRIMARY KEY NOT NULL,
                    from_entity_id TEXT NOT NULL
                        REFERENCES entity(id) ON DELETE CASCADE,
                    relationship_type TEXT NOT NULL CHECK (
                        relationship_type IN (
                            'SUSCEPTIBLE_TO', 'HOST_OF',
                            'COMPANION_WITH', 'LOCATED_IN'
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
                    UNIQUE (from_entity_id, relationship_type, to_entity_id)
                )
                """
        )
        try db.execute(sql: "CREATE INDEX relationship_from ON relationship(from_entity_id)")
        try db.execute(sql: "CREATE INDEX relationship_to ON relationship(to_entity_id)")
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

    static let applyTaxonomy: @Sendable (Database) throws -> Void = { db in
        try db.execute(
            sql: """
                CREATE TABLE plant_family (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    common_names TEXT NOT NULL DEFAULT '[]'
                )
                """
        )
        try db.execute(
            sql: """
                CREATE TABLE genus (
                    id TEXT PRIMARY KEY NOT NULL,
                    family_id TEXT NOT NULL
                        REFERENCES plant_family(id) ON DELETE RESTRICT,
                    name TEXT NOT NULL
                )
                """
        )
        try db.execute(sql: "CREATE INDEX genus_on_family_id ON genus(family_id)")
        try db.execute(
            sql: """
                CREATE TABLE species (
                    id TEXT PRIMARY KEY NOT NULL,
                    genus_id TEXT NOT NULL
                        REFERENCES genus(id) ON DELETE RESTRICT,
                    scientific_name TEXT NOT NULL,
                    common_names TEXT NOT NULL DEFAULT '[]',
                    life_cycle TEXT,
                    growth_habit TEXT,
                    sun_exposure TEXT,
                    water_need TEXT,
                    soil_ph_min REAL,
                    soil_ph_max REAL,
                    spacing_cm_min REAL,
                    spacing_cm_max REAL,
                    days_to_maturity_min INTEGER,
                    days_to_maturity_max INTEGER,
                    hardiness_zone_min INTEGER,
                    hardiness_zone_max INTEGER,
                    harvestable_parts TEXT NOT NULL DEFAULT '[]',
                    CHECK ((soil_ph_min IS NULL) = (soil_ph_max IS NULL)),
                    CHECK (soil_ph_min IS NULL OR soil_ph_min <= soil_ph_max),
                    CHECK ((spacing_cm_min IS NULL) = (spacing_cm_max IS NULL)),
                    CHECK (spacing_cm_min IS NULL OR spacing_cm_min <= spacing_cm_max),
                    CHECK (
                        (days_to_maturity_min IS NULL) = (days_to_maturity_max IS NULL)
                    ),
                    CHECK (
                        days_to_maturity_min IS NULL
                        OR days_to_maturity_min <= days_to_maturity_max
                    ),
                    CHECK (
                        (hardiness_zone_min IS NULL) = (hardiness_zone_max IS NULL)
                    ),
                    CHECK (
                        hardiness_zone_min IS NULL
                        OR hardiness_zone_min <= hardiness_zone_max
                    )
                )
                """
        )
        try db.execute(sql: "CREATE INDEX species_on_genus_id ON species(genus_id)")
        try db.execute(
            sql: """
                CREATE TABLE cultivar (
                    id TEXT PRIMARY KEY NOT NULL,
                    species_id TEXT NOT NULL
                        REFERENCES species(id) ON DELETE RESTRICT,
                    name TEXT NOT NULL,
                    common_names TEXT NOT NULL DEFAULT '[]',
                    days_to_maturity_min INTEGER,
                    days_to_maturity_max INTEGER,
                    spacing_cm_min REAL,
                    spacing_cm_max REAL,
                    growth_habit TEXT,
                    CHECK (
                        (days_to_maturity_min IS NULL) = (days_to_maturity_max IS NULL)
                    ),
                    CHECK (
                        days_to_maturity_min IS NULL
                        OR days_to_maturity_min <= days_to_maturity_max
                    ),
                    CHECK ((spacing_cm_min IS NULL) = (spacing_cm_max IS NULL)),
                    CHECK (spacing_cm_min IS NULL OR spacing_cm_min <= spacing_cm_max)
                )
                """
        )
        try db.execute(sql: "CREATE INDEX cultivar_on_species_id ON cultivar(species_id)")
    }

    static let applyGardenStructure: @Sendable (Database) throws -> Void = { db in
        for table in ["property", "garden", "growing_area"] {
            try db.execute(
                sql: """
                    CREATE TABLE \(table) (
                        id TEXT PRIMARY KEY NOT NULL,
                        name TEXT NOT NULL,
                        notes TEXT,
                        archived INTEGER NOT NULL DEFAULT 0
                    )
                    """
            )
        }
        try db.execute(
            sql: """
                CREATE TABLE bed (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    kind TEXT NOT NULL CHECK (
                        kind IN ('raised', 'in_ground', 'container')
                    ),
                    notes TEXT,
                    archived INTEGER NOT NULL DEFAULT 0
                )
                """
        )
        try db.execute(
            sql: """
                CREATE TABLE entity_new (
                    id TEXT PRIMARY KEY NOT NULL,
                    entity_type TEXT NOT NULL CHECK (
                        entity_type IN (
                            'plant', 'pest', 'disease', 'seed_lot', 'planting',
                            'property', 'garden', 'growing_area', 'bed'
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
        try db.execute(
            sql: """
                CREATE UNIQUE INDEX relationship_single_located_in_parent
                ON relationship(from_entity_id)
                WHERE relationship_type = 'LOCATED_IN'
                """
        )
    }

    static let applyPests: @Sendable (Database) throws -> Void = { db in
        try db.execute(
            sql: """
                CREATE TABLE pest (
                    id TEXT PRIMARY KEY NOT NULL,
                    common_name TEXT NOT NULL,
                    scientific_name TEXT,
                    organism_type TEXT NOT NULL CHECK (
                        organism_type IN ('pest', 'beneficial')
                    ),
                    description TEXT,
                    life_cycle TEXT,
                    affected_plant_parts TEXT NOT NULL DEFAULT '[]',
                    typical_damage TEXT,
                    active_seasons TEXT NOT NULL DEFAULT '[]',
                    geographic_range TEXT
                )
                """
        )
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
                            'PARASITIZED_BY', 'PREDATED_BY'
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
                    UNIQUE (from_entity_id, relationship_type, to_entity_id)
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
