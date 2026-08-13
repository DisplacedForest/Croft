import GRDB

extension SchemaMigrations {
    static let applyCultivationProfile: @Sendable (Database) throws -> Void = { db in
        try rebuildSpeciesTableForCultivationProfile(db)
        try rebuildCultivarTableForCultivationProfile(db)
    }

    private static let speciesColumnsBeforeCultivationProfile = """
        id, genus_id, scientific_name, common_names,
        life_cycle, growth_habit, sun_exposure, water_need,
        soil_ph_min, soil_ph_max, spacing_cm_min, spacing_cm_max,
        days_to_maturity_min, days_to_maturity_max,
        hardiness_zone_min, hardiness_zone_max, harvestable_parts
        """

    private static let speciesCultivationColumns = """
        germination_temp_c_min REAL,
        germination_temp_c_optimal_min REAL,
        germination_temp_c_optimal_max REAL,
        germination_temp_c_max REAL,
        germination_days_min INTEGER,
        germination_days_max INTEGER,
        sowing_depth_cm_min REAL,
        sowing_depth_cm_max REAL,
        row_spacing_cm_min REAL,
        row_spacing_cm_max REAL,
        sowing_method TEXT,
        weeks_indoors_min INTEGER,
        weeks_indoors_max INTEGER,
        frost_tolerance TEXT,
        transplant_soil_temp_c_min REAL,
        days_to_maturity_basis TEXT
        """

    private static let speciesRangeChecks = """
        CHECK ((soil_ph_min IS NULL) = (soil_ph_max IS NULL)),
        CHECK (soil_ph_min IS NULL OR soil_ph_min <= soil_ph_max),
        CHECK ((spacing_cm_min IS NULL) = (spacing_cm_max IS NULL)),
        CHECK (spacing_cm_min IS NULL OR spacing_cm_min <= spacing_cm_max),
        CHECK ((days_to_maturity_min IS NULL) = (days_to_maturity_max IS NULL)),
        CHECK (
            days_to_maturity_min IS NULL
            OR days_to_maturity_min <= days_to_maturity_max
        ),
        CHECK ((hardiness_zone_min IS NULL) = (hardiness_zone_max IS NULL)),
        CHECK (
            hardiness_zone_min IS NULL
            OR hardiness_zone_min <= hardiness_zone_max
        )
        """

    private static let speciesCultivationRangeChecks = """
        CHECK (
            (germination_temp_c_optimal_min IS NULL)
            = (germination_temp_c_optimal_max IS NULL)
        ),
        CHECK (
            germination_temp_c_optimal_min IS NULL
            OR germination_temp_c_optimal_min <= germination_temp_c_optimal_max
        ),
        CHECK ((germination_days_min IS NULL) = (germination_days_max IS NULL)),
        CHECK (
            germination_days_min IS NULL
            OR germination_days_min <= germination_days_max
        ),
        CHECK ((sowing_depth_cm_min IS NULL) = (sowing_depth_cm_max IS NULL)),
        CHECK (
            sowing_depth_cm_min IS NULL
            OR sowing_depth_cm_min <= sowing_depth_cm_max
        ),
        CHECK ((row_spacing_cm_min IS NULL) = (row_spacing_cm_max IS NULL)),
        CHECK (
            row_spacing_cm_min IS NULL
            OR row_spacing_cm_min <= row_spacing_cm_max
        ),
        CHECK ((weeks_indoors_min IS NULL) = (weeks_indoors_max IS NULL)),
        CHECK (
            weeks_indoors_min IS NULL
            OR weeks_indoors_min <= weeks_indoors_max
        )
        """

    private static func rebuildSpeciesTableForCultivationProfile(_ db: Database) throws {
        try db.execute(
            sql: """
                CREATE TABLE species_new (
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
                    \(speciesCultivationColumns),
                    \(speciesRangeChecks),
                    \(speciesCultivationRangeChecks)
                )
                """
        )
        try db.execute(
            sql: """
                INSERT INTO species_new (\(speciesColumnsBeforeCultivationProfile))
                SELECT \(speciesColumnsBeforeCultivationProfile) FROM species
                """
        )
        try db.execute(sql: "DROP TABLE species")
        try db.execute(sql: "ALTER TABLE species_new RENAME TO species")
        try db.execute(sql: "CREATE INDEX species_on_genus_id ON species(genus_id)")
    }

    private static func rebuildCultivarTableForCultivationProfile(_ db: Database) throws {
        let carried = """
            id, species_id, name, common_names,
            days_to_maturity_min, days_to_maturity_max,
            spacing_cm_min, spacing_cm_max, growth_habit
            """
        try db.execute(
            sql: """
                CREATE TABLE cultivar_new (
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
                    planting_seasons TEXT NOT NULL DEFAULT '[]',
                    seed_preps TEXT NOT NULL DEFAULT '[]',
                    heirloom INTEGER,
                    seed_types TEXT NOT NULL DEFAULT '[]',
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
        try db.execute(
            sql: """
                INSERT INTO cultivar_new (\(carried))
                SELECT \(carried) FROM cultivar
                """
        )
        try db.execute(sql: "DROP TABLE cultivar")
        try db.execute(sql: "ALTER TABLE cultivar_new RENAME TO cultivar")
        try db.execute(sql: "CREATE INDEX cultivar_on_species_id ON cultivar(species_id)")
    }
}
