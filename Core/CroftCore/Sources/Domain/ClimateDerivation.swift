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
    static let referenceYear = 2001

    public static func frostDates(
        minima: [DailyMinimum],
        southernHemisphere: Bool,
        calendar: Calendar = PlantingWindows.utcCalendar
    ) -> DerivedFrostDates {
        var lastOffsets: [Int: Int] = [:]
        var firstOffsets: [Int: Int] = [:]
        for minimum in minima where minimum.celsius <= frostThresholdCelsius {
            let parts = calendar.dateComponents([.year, .month, .day], from: minimum.date)
            guard let year = parts.year, let month = parts.month, let day = parts.day else {
                continue
            }
            let season = seasonKey(year: year, month: month, southernHemisphere: southernHemisphere)
            guard
                let offset = normalizedOffset(
                    month: month, day: day,
                    southernHemisphere: southernHemisphere, calendar: calendar)
            else {
                continue
            }
            let springHalf = southernHemisphere ? month >= 7 : month <= 6
            if springHalf {
                lastOffsets[season] = max(lastOffsets[season] ?? .min, offset)
            } else {
                firstOffsets[season] = min(firstOffsets[season] ?? .max, offset)
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
            let parts = calendar.dateComponents([.year, .month], from: minimum.date)
            guard let year = parts.year, let month = parts.month else {
                continue
            }
            let season = seasonKey(year: year, month: month, southernHemisphere: southernHemisphere)
            seasonMinima[season] = Swift.min(
                seasonMinima[season] ?? .greatestFiniteMagnitude, minimum.celsius)
        }
        guard !seasonMinima.isEmpty else {
            return nil
        }
        let averageCelsius = seasonMinima.values.reduce(0, +) / Double(seasonMinima.count)
        let fahrenheit = averageCelsius * 9 / 5 + 32
        let zone = Int(floor((fahrenheit + 60) / 10)) + 1
        return Swift.min(Swift.max(zone, 1), 13)
    }

    static func seasonKey(year: Int, month: Int, southernHemisphere: Bool) -> Int {
        guard southernHemisphere else {
            return year
        }
        return month >= 7 ? year : year - 1
    }

    static func normalizedOffset(
        month: Int,
        day: Int,
        southernHemisphere: Bool,
        calendar: Calendar
    ) -> Int? {
        var parts = DateComponents()
        parts.year =
            southernHemisphere && month < 7 ? referenceYear + 1 : referenceYear
        parts.month = month
        parts.day = month == 2 && day == 29 ? 28 : day
        guard
            let date = calendar.date(from: parts),
            let start = seasonStart(southernHemisphere: southernHemisphere, calendar: calendar)
        else {
            return nil
        }
        return calendar.dateComponents([.day], from: start, to: date).day
    }

    static func seasonStart(southernHemisphere: Bool, calendar: Calendar) -> Date? {
        var parts = DateComponents()
        parts.year = referenceYear
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
            let start = seasonStart(southernHemisphere: southernHemisphere, calendar: calendar),
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
