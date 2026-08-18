import Foundation

public struct DailyMinimum: Equatable, Sendable {
    public let date: Date
    public let celsius: Double

    public init(date: Date, celsius: Double) {
        self.date = date
        self.celsius = celsius
    }
}

public struct DerivedFrostDates: Equatable, Sendable {
    public let lastFrost: MonthDay?
    public let firstFrost: MonthDay?

    public init(lastFrost: MonthDay?, firstFrost: MonthDay?) {
        self.lastFrost = lastFrost
        self.firstFrost = firstFrost
    }
}

public enum ClimateDerivation {
    public static let frostThresholdCelsius = 0.0
    public static let seasonMidpointOffset = 183
    static let referenceYear = 2001

    public static func frostDates(
        minima: [DailyMinimum],
        southernHemisphere: Bool,
        calendar: Calendar = PlantingWindows.utcCalendar
    ) -> DerivedFrostDates {
        var lastOffsets: [Int: Int] = [:]
        var firstOffsets: [Int: Int] = [:]
        for minimum in minima where minimum.celsius <= frostThresholdCelsius {
            guard
                let position = seasonPosition(
                    of: minimum.date, southernHemisphere: southernHemisphere, calendar: calendar)
            else {
                continue
            }
            if position.offset < seasonMidpointOffset {
                lastOffsets[position.season] = max(
                    lastOffsets[position.season] ?? .min, position.offset)
            } else {
                firstOffsets[position.season] = min(
                    firstOffsets[position.season] ?? .max, position.offset)
            }
        }
        return DerivedFrostDates(
            lastFrost: median(Array(lastOffsets.values)).flatMap {
                monthDay(atOffset: $0, southernHemisphere: southernHemisphere, calendar: calendar)
            },
            firstFrost: median(Array(firstOffsets.values)).flatMap {
                monthDay(atOffset: $0, southernHemisphere: southernHemisphere, calendar: calendar)
            }
        )
    }

    public static func estimatedZone(
        minima: [DailyMinimum],
        southernHemisphere: Bool,
        calendar: Calendar = PlantingWindows.utcCalendar
    ) -> Int? {
        var seasonMinima: [Int: Double] = [:]
        for minimum in minima {
            guard
                let position = seasonPosition(
                    of: minimum.date, southernHemisphere: southernHemisphere, calendar: calendar)
            else {
                continue
            }
            seasonMinima[position.season] = Swift.min(
                seasonMinima[position.season] ?? .greatestFiniteMagnitude, minimum.celsius)
        }
        guard !seasonMinima.isEmpty else {
            return nil
        }
        let averageCelsius =
            seasonMinima.values.reduce(0, +) / Double(seasonMinima.count)
        let fahrenheit = averageCelsius * 9 / 5 + 32
        let zone = Int((fahrenheit + 60) / 10) + 1
        return Swift.min(Swift.max(zone, 1), 13)
    }

    static func seasonPosition(
        of date: Date,
        southernHemisphere: Bool,
        calendar: Calendar
    ) -> (season: Int, offset: Int)? {
        let parts = calendar.dateComponents([.year, .month], from: date)
        guard let year = parts.year, let month = parts.month else {
            return nil
        }
        let season = southernHemisphere && month >= 7 ? year : southernHemisphere ? year - 1 : year
        guard
            let start = seasonStart(
                season, southernHemisphere: southernHemisphere, calendar: calendar)
        else {
            return nil
        }
        let offset = calendar.dateComponents([.day], from: start, to: date).day
        guard let offset, offset >= 0 else {
            return nil
        }
        return (season, offset)
    }

    static func seasonStart(
        _ season: Int,
        southernHemisphere: Bool,
        calendar: Calendar
    ) -> Date? {
        var parts = DateComponents()
        parts.year = season
        parts.month = southernHemisphere ? 7 : 1
        parts.day = 1
        return calendar.date(from: parts)
    }

    static func monthDay(
        atOffset offset: Int,
        southernHemisphere: Bool,
        calendar: Calendar
    ) -> MonthDay? {
        guard
            let start = seasonStart(
                referenceYear, southernHemisphere: southernHemisphere, calendar: calendar),
            let date = calendar.date(byAdding: .day, value: offset, to: start)
        else {
            return nil
        }
        let parts = calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else {
            return nil
        }
        return MonthDay(month: month, day: day)
    }

    static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else {
            return nil
        }
        let sorted = values.sorted()
        return sorted[(sorted.count - 1) / 2]
    }
}
