import GRDB

public enum SchemaMigrations {
    static let migrations: [(identifier: String, apply: @Sendable (Database) throws -> Void)] = [
        (
            "v001-baseline",
            { db in
                try db.execute(sql: "PRAGMA application_id = \(databaseApplicationID)")
            }
        ),
        (
            "v003-taxonomy",
            { db in
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
        ),
    ]

    public static let identifiers: [String] = migrations.map(\.identifier)

    public static let databaseApplicationID = 0x4352_4F46

    public static func migrator(through identifier: String? = nil) -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        for migration in migrations {
            migrator.registerMigration(migration.identifier, migrate: migration.apply)
            if migration.identifier == identifier {
                break
            }
        }
        return migrator
    }
}
