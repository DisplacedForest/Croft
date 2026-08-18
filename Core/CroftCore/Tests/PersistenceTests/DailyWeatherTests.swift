import Domain
import Foundation
import GRDB
import Testing

@testable import Persistence

let dailyWeatherIdentifier = "v019-daily-weather"

private struct WeatherFixture {
    let database: AppDatabase
    let repository: DailyWeatherRepository
    let property: Property

    init() throws {
        database = try AppDatabase.inMemory()
        repository = DailyWeatherRepository(database)
        property = Property(name: "Home")
        try GardenStructureRepository(database).create(property)
    }

    func stamp(_ year: Int, _ month: Int, _ day: Int) throws -> DayStamp {
        try #require(DayStamp(year: year, month: month, day: day))
    }

    func record(
        _ day: DayStamp,
        high: Double? = nil,
        provenance: WeatherProvenance = .observed
    ) -> DailyWeather {
        DailyWeather(
            propertyID: property.id, day: day, highCelsius: high, provenance: provenance)
    }
}

struct DailyWeatherMigrationTests {
    @Test func theMigrationAppendsAfterHarvestYield() throws {
        let identifiers = SchemaMigrations.identifiers
        let index = try #require(identifiers.firstIndex(of: dailyWeatherIdentifier))
        try #require(index > 0)
        #expect(identifiers[index - 1] == harvestYieldIdentifier)
        #expect(index == identifiers.count - 1)
    }

    @Test func theTableAndIndexExistAtHead() throws {
        let database = try AppDatabase.inMemory()
        let state = try database.writer.read { db in
            (
                table: try db.tableExists("daily_weather"),
                indexes: try db.indexes(on: "daily_weather").map(\.name)
            )
        }
        #expect(state.table)
        #expect(state.indexes.contains("daily_weather_on_property_id"))
    }

    @Test func anUnknownProvenanceIsRejectedByTheDatabase() throws {
        let fixture = try WeatherFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO daily_weather (property_id, date, provenance)
                        VALUES (?, '2026-08-18', 'guessed')
                        """,
                    arguments: [fixture.property.id.rawValue]
                )
            }
        }
    }

    @Test func aMalformedDateIsRejectedByTheDatabase() throws {
        let fixture = try WeatherFixture()
        for bad in ["18-08-2026", "2026/08/18", "2026-8-18", "today"] {
            #expect(throws: DatabaseError.self) {
                try fixture.database.writer.write { db in
                    try db.execute(
                        sql: """
                            INSERT INTO daily_weather (property_id, date, provenance)
                            VALUES (?, ?, 'observed')
                            """,
                        arguments: [fixture.property.id.rawValue, bad]
                    )
                }
            }
        }
    }

    @Test func aSecondRowForTheSameDayIsRejectedByTheDatabase() throws {
        let fixture = try WeatherFixture()
        try fixture.database.writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO daily_weather (property_id, date, provenance)
                    VALUES (?, '2026-08-18', 'observed')
                    """,
                arguments: [fixture.property.id.rawValue]
            )
        }
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO daily_weather (property_id, date, provenance)
                        VALUES (?, '2026-08-18', 'backfilled')
                        """,
                    arguments: [fixture.property.id.rawValue]
                )
            }
        }
    }

    @Test func aWeatherRowForAMissingPropertyIsRejected() throws {
        let fixture = try WeatherFixture()
        #expect(throws: DatabaseError.self) {
            try fixture.database.writer.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO daily_weather (property_id, date, provenance)
                        VALUES ('ghost', '2026-08-18', 'observed')
                        """
                )
            }
        }
    }

    @Test func theGraphSchemaCarriesNoWeather() throws {
        let database = try AppDatabase.inMemory()
        let schemas = try database.writer.read { db in
            try String.fetchAll(
                db,
                sql: """
                    SELECT sql FROM sqlite_master
                    WHERE name IN ('entity', 'relationship')
                    """
            )
        }
        #expect(schemas.count == 2)
        #expect(!schemas.contains { $0.lowercased().contains("weather") })
    }
}

struct DailyWeatherRepositoryTests {
    @Test func reUpsertingTheSameDayConvergesToOneRow() throws {
        let fixture = try WeatherFixture()
        let day = try fixture.stamp(2026, 8, 18)
        try fixture.repository.upsert(fixture.record(day, high: 21))
        try fixture.repository.upsert(fixture.record(day, high: 24, provenance: .backfilled))
        let count = try fixture.database.writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM daily_weather")
        }
        #expect(count == 1)
        let stored = try #require(
            try fixture.repository.record(for: fixture.property.id, on: day))
        #expect(stored.highCelsius == 24)
        #expect(stored.provenance == .backfilled)
    }

    @Test func everyFieldRoundTrips() throws {
        let fixture = try WeatherFixture()
        let day = try fixture.stamp(2026, 8, 18)
        let record = DailyWeather(
            propertyID: fixture.property.id,
            day: day,
            highCelsius: 24.5,
            lowCelsius: 11.0,
            precipitationMillimeters: 3.2,
            provenance: .observed
        )
        try fixture.repository.upsert(record)
        #expect(try fixture.repository.record(for: fixture.property.id, on: day) == record)
    }

    @Test func rangeQueriesOrderAcrossMonthBoundaries() throws {
        let fixture = try WeatherFixture()
        let days = [
            try fixture.stamp(2026, 9, 1),
            try fixture.stamp(2026, 8, 30),
            try fixture.stamp(2026, 8, 31),
            try fixture.stamp(2026, 9, 2),
        ]
        for day in days {
            try fixture.repository.upsert(fixture.record(day))
        }
        try fixture.repository.upsert(fixture.record(try fixture.stamp(2026, 7, 31)))
        try fixture.repository.upsert(fixture.record(try fixture.stamp(2026, 9, 3)))
        let series = try fixture.repository.range(
            for: fixture.property.id,
            from: try fixture.stamp(2026, 8, 1),
            through: try fixture.stamp(2026, 9, 2)
        )
        #expect(
            series.map(\.day.storageValue) == [
                "2026-08-30", "2026-08-31", "2026-09-01", "2026-09-02",
            ])
    }

    @Test func rangeQueriesAreScopedToTheProperty() throws {
        let fixture = try WeatherFixture()
        let neighbor = Property(name: "Allotment")
        try GardenStructureRepository(fixture.database).create(neighbor)
        let day = try fixture.stamp(2026, 8, 18)
        try fixture.repository.upsert(
            DailyWeather(propertyID: neighbor.id, day: day, provenance: .observed))
        #expect(
            try fixture.repository.range(for: fixture.property.id, from: day, through: day)
                .isEmpty)
    }

    @Test func deletingThePropertyCascadesToItsWeather() throws {
        let fixture = try WeatherFixture()
        try fixture.repository.upsert(fixture.record(try fixture.stamp(2026, 8, 18)))
        try GardenStructureRepository(fixture.database).deleteProperty(fixture.property.id)
        let count = try fixture.database.writer.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM daily_weather")
        }
        #expect(count == 0)
    }

    @Test func anUnknownStoredProvenanceFailsFetch() throws {
        let fixture = try WeatherFixture()
        let day = try fixture.stamp(2026, 8, 18)
        try fixture.repository.upsert(fixture.record(day))
        try fixture.database.writer.write { db in
            try db.execute(sql: "PRAGMA ignore_check_constraints = ON")
            try db.execute(sql: "UPDATE daily_weather SET provenance = 'guessed'")
            try db.execute(sql: "PRAGMA ignore_check_constraints = OFF")
        }
        #expect(
            throws: TaxonomyCodingError.unknownRawValue(
                table: "daily_weather",
                column: "provenance",
                value: "guessed"
            )
        ) {
            try fixture.repository.record(for: fixture.property.id, on: day)
        }
    }
}
