import GRDB

extension SchemaMigrations {
    static let applyClimateProvenance: @Sendable (Database) throws -> Void = { db in
        try db.execute(
            sql: """
                ALTER TABLE property ADD COLUMN zone_source TEXT NOT NULL
                    DEFAULT 'derived' CHECK (zone_source IN ('derived', 'user'))
                """
        )
        try db.execute(
            sql: """
                ALTER TABLE property ADD COLUMN frost_dates_source TEXT NOT NULL
                    DEFAULT 'derived' CHECK (frost_dates_source IN ('derived', 'user'))
                """
        )
        try db.execute(
            sql: "UPDATE property SET zone_source = 'user' WHERE hardiness_zone IS NOT NULL"
        )
        try db.execute(
            sql: """
                UPDATE property SET frost_dates_source = 'user'
                WHERE last_frost_month IS NOT NULL OR first_frost_month IS NOT NULL
                """
        )
    }
}
