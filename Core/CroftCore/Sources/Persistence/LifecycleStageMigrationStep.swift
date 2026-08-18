import GRDB

extension SchemaMigrations {
    static let applyLifecycleStages: @Sendable (Database) throws -> Void = { db in
        try rebuildObservationTableForLifecycleStages(db)
    }

    private static let lifecycleObservationTargetColumns = [
        "planting_id", "cultivar_id", "species_id", "bed_id", "garden_id",
    ]

    private static func rebuildObservationTableForLifecycleStages(_ db: Database) throws {
        try db.execute(
            sql: """
                CREATE TABLE observation_new (
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
                    stage TEXT CHECK (
                        stage IN (
                            'germinated', 'transplanted', 'first_flower',
                            'first_fruit_set', 'pulled'
                        )
                    ),
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
        try db.execute(
            sql: """
                INSERT INTO observation_new
                    (id, planting_id, cultivar_id, species_id, bed_id, garden_id,
                     observed_at, notes, symptoms, measurements, tags)
                SELECT id, planting_id, cultivar_id, species_id, bed_id, garden_id,
                     observed_at, notes, symptoms, measurements, tags
                FROM observation
                """
        )
        try db.execute(sql: "DROP TABLE observation")
        try db.execute(sql: "ALTER TABLE observation_new RENAME TO observation")
        for column in lifecycleObservationTargetColumns {
            try db.execute(sql: "CREATE INDEX observation_on_\(column) ON observation(\(column))")
        }
    }
}
