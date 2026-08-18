import GRDB

extension SchemaMigrations {
    static let applyDailyWeather: @Sendable (Database) throws -> Void = { db in
        try db.execute(
            sql: """
                CREATE TABLE daily_weather (
                    property_id TEXT NOT NULL
                        REFERENCES property(id) ON DELETE CASCADE,
                    date TEXT NOT NULL CHECK (
                        date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
                    ),
                    high_celsius REAL,
                    low_celsius REAL,
                    precipitation_millimeters REAL,
                    provenance TEXT NOT NULL CHECK (
                        provenance IN ('observed', 'backfilled', 'missing')
                    ),
                    PRIMARY KEY (property_id, date)
                )
                """
        )
        try db.execute(
            sql: "CREATE INDEX daily_weather_on_property_id ON daily_weather(property_id)")
    }
}
