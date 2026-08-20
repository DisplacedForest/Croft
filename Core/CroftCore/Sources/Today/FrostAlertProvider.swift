import Foundation

import enum Domain.FrostTolerance

extension AttentionProviders {
    public static let tenderFrostThresholdCelsius = 2.0
    public static let halfHardyFrostThresholdCelsius = 0.0
    public static let frostAlertHorizonDays = 2

    public struct FrostRiskCandidate: Equatable, Sendable {
        public let plantingID: String
        public let plantName: String
        public let locationName: String?
        public let frostTolerance: FrostTolerance?

        public init(
            plantingID: String,
            plantName: String,
            locationName: String? = nil,
            frostTolerance: FrostTolerance? = nil
        ) {
            self.plantingID = plantingID
            self.plantName = plantName
            self.locationName = locationName
            self.frostTolerance = frostTolerance
        }
    }

    public static func frostAlerts(
        forecast: [DayForecast],
        candidates: [FrostRiskCandidate],
        now: Date,
        calendar: Calendar
    ) -> [AttentionItem] {
        let start = calendar.startOfDay(for: now)
        guard
            let horizon = calendar.date(byAdding: .day, value: frostAlertHorizonDays, to: start)
        else {
            return []
        }
        var items: [AttentionItem] = []
        for day in forecast where day.date >= start && day.date < horizon {
            let low = day.low.converted(to: .celsius).value
            let atRisk = candidates.filter { candidate in
                guard let threshold = frostThresholdCelsius(for: candidate.frostTolerance) else {
                    return false
                }
                return low <= threshold
            }
            guard !atRisk.isEmpty else {
                continue
            }
            let names = atRisk.map { candidate in
                candidate.locationName.map { "\(candidate.plantName) (\($0))" }
                    ?? candidate.plantName
            }
            items.append(
                AttentionItem(
                    id: "frost-\(dayKey(day.date, calendar: calendar))",
                    kind: .frostAlert,
                    title: nameList(names),
                    reason: frostReason(day: day, now: now, calendar: calendar),
                    orderDate: day.date
                ))
        }
        return items
    }

    static func frostThresholdCelsius(for tolerance: FrostTolerance?) -> Double? {
        switch tolerance {
        case .tender: tenderFrostThresholdCelsius
        case .halfHardy: halfHardyFrostThresholdCelsius
        case .hardy, nil: nil
        }
    }

    static func frostReason(day: DayForecast, now: Date, calendar: Calendar) -> String {
        let low = day.low.formatted(
            WeatherDisplay.temperatureStyle(width: .narrow).locale(reasonLocale))
        if calendar.isDate(day.date, inSameDayAs: now) {
            return "Low of \(low) tonight"
        }
        let weekday = day.date.formatted(
            Date.FormatStyle(locale: reasonLocale, calendar: calendar).weekday(.wide))
        return "Low of \(low) \(weekday) night"
    }

    private static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }
}
