import Domain
import Foundation
import GRDB

struct DailyWeatherRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "daily_weather"

    var propertyID: String
    var date: String
    var highCelsius: Double?
    var lowCelsius: Double?
    var precipitationMillimeters: Double?
    var provenance: String

    enum CodingKeys: String, CodingKey {
        case propertyID = "property_id"
        case date
        case highCelsius = "high_celsius"
        case lowCelsius = "low_celsius"
        case precipitationMillimeters = "precipitation_millimeters"
        case provenance
    }

    init(_ record: DailyWeather) {
        propertyID = record.propertyID.rawValue
        date = record.day.storageValue
        highCelsius = record.highCelsius
        lowCelsius = record.lowCelsius
        precipitationMillimeters = record.precipitationMillimeters
        provenance = record.provenance.rawValue
    }

    func model() throws -> DailyWeather {
        let decoder = TaxonomyRowDecoder(table: Self.databaseTableName)
        guard let day = DayStamp(storageValue: date) else {
            throw TaxonomyCodingError.unknownRawValue(
                table: Self.databaseTableName, column: "date", value: date)
        }
        return DailyWeather(
            propertyID: Property.ID(rawValue: propertyID),
            day: day,
            highCelsius: highCelsius,
            lowCelsius: lowCelsius,
            precipitationMillimeters: precipitationMillimeters,
            provenance: try decoder.enumValue(
                WeatherProvenance.self, from: provenance, column: "provenance")
        )
    }
}

public struct DailyWeatherRepository: Sendable {
    private let writer: any DatabaseWriter
    private let changes: ChangeLogger

    public init(_ database: AppDatabase) {
        writer = database.writer
        changes = ChangeLogger(database)
    }

    public func upsert(_ record: DailyWeather) throws {
        let row = DailyWeatherRecord(record)
        let entityID = "\(record.propertyID.rawValue)/\(record.day.storageValue)"
        try writer.write { db in
            let existed =
                try Bool.fetchOne(
                    db,
                    sql: """
                        SELECT EXISTS(
                            SELECT 1 FROM daily_weather WHERE property_id = ? AND date = ?
                        )
                        """,
                    arguments: [row.propertyID, row.date]
                ) ?? false
            try db.execute(
                sql: """
                    INSERT INTO daily_weather
                        (property_id, date, high_celsius, low_celsius,
                         precipitation_millimeters, provenance)
                    VALUES (?, ?, ?, ?, ?, ?)
                    ON CONFLICT (property_id, date) DO UPDATE SET
                        high_celsius = excluded.high_celsius,
                        low_celsius = excluded.low_celsius,
                        precipitation_millimeters = excluded.precipitation_millimeters,
                        provenance = excluded.provenance
                    """,
                arguments: [
                    row.propertyID, row.date, row.highCelsius, row.lowCelsius,
                    row.precipitationMillimeters, row.provenance,
                ]
            )
            try changes.record(
                .dailyWeather, entityID, existed ? .update : .create, in: db)
        }
    }

    public func record(for propertyID: Property.ID, on day: DayStamp) throws -> DailyWeather? {
        try writer.read { db in
            try DailyWeatherRecord
                .filter(Column("property_id") == propertyID.rawValue)
                .filter(Column("date") == day.storageValue)
                .fetchOne(db)?
                .model()
        }
    }

    public func range(
        for propertyID: Property.ID,
        from start: DayStamp,
        through end: DayStamp
    ) throws -> [DailyWeather] {
        try writer.read { db in
            try DailyWeatherRecord
                .filter(Column("property_id") == propertyID.rawValue)
                .filter(Column("date") >= start.storageValue)
                .filter(Column("date") <= end.storageValue)
                .order(Column("date"))
                .fetchAll(db)
                .map { try $0.model() }
        }
    }
}

extension DailyWeatherRepository: DailyWeatherWriting {}
