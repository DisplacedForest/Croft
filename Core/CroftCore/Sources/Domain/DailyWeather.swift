import Foundation

public struct DayStamp: Equatable, Hashable, Sendable, Codable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    private static let daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    public init?(year: Int, month: Int, day: Int) {
        guard (1...9999).contains(year), (1...12).contains(month),
            (1...DayStamp.lastDay(ofMonth: month, in: year)).contains(day)
        else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    private static func lastDay(ofMonth month: Int, in year: Int) -> Int {
        if month == 2, year % 4 == 0, year % 100 != 0 || year % 400 == 0 {
            return 29
        }
        return daysInMonth[month - 1]
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? 1
        month = components.month ?? 1
        day = components.day ?? 1
    }

    public init?(storageValue: String) {
        let parts = storageValue.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
            let stamp = DayStamp(year: year, month: month, day: day)
        else {
            return nil
        }
        self = stamp
    }

    public var storageValue: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public static func < (lhs: DayStamp, rhs: DayStamp) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

public enum WeatherProvenance: String, CaseIterable, Codable, Hashable, Sendable {
    case observed
    case backfilled
    case missing
}

public struct DailyWeather: Equatable, Sendable, Codable {
    public var propertyID: Property.ID
    public var day: DayStamp
    public var highCelsius: Double?
    public var lowCelsius: Double?
    public var precipitationMillimeters: Double?
    public var provenance: WeatherProvenance

    public init(
        propertyID: Property.ID,
        day: DayStamp,
        highCelsius: Double? = nil,
        lowCelsius: Double? = nil,
        precipitationMillimeters: Double? = nil,
        provenance: WeatherProvenance
    ) {
        self.propertyID = propertyID
        self.day = day
        self.highCelsius = highCelsius
        self.lowCelsius = lowCelsius
        self.precipitationMillimeters = precipitationMillimeters
        self.provenance = provenance
    }
}

public protocol DailyWeatherWriting: Sendable {
    func upsert(_ record: DailyWeather) throws
}
