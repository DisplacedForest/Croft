import GRDB

extension SchemaMigrations {
    static let applyPropertyLocation: @Sendable (Database) throws -> Void = { db in
        try db.execute(
            sql: """
                CREATE TABLE property_new (
                    id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    notes TEXT,
                    archived INTEGER NOT NULL DEFAULT 0,
                    latitude REAL,
                    longitude REAL,
                    hardiness_zone INTEGER,
                    last_frost_month INTEGER,
                    last_frost_day INTEGER,
                    first_frost_month INTEGER,
                    first_frost_day INTEGER,
                    CHECK ((latitude IS NULL) = (longitude IS NULL)),
                    CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
                    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180),
                    CHECK ((last_frost_month IS NULL) = (last_frost_day IS NULL)),
                    CHECK (last_frost_month IS NULL OR last_frost_month BETWEEN 1 AND 12),
                    CHECK (last_frost_day IS NULL OR last_frost_day BETWEEN 1 AND 31),
                    CHECK ((first_frost_month IS NULL) = (first_frost_day IS NULL)),
                    CHECK (first_frost_month IS NULL OR first_frost_month BETWEEN 1 AND 12),
                    CHECK (first_frost_day IS NULL OR first_frost_day BETWEEN 1 AND 31)
                )
                """
        )
        try db.execute(
            sql: """
                INSERT INTO property_new (id, name, notes, archived)
                SELECT id, name, notes, archived FROM property
                """
        )
        try db.execute(sql: "DROP TABLE property")
        try db.execute(sql: "ALTER TABLE property_new RENAME TO property")
    }
}
