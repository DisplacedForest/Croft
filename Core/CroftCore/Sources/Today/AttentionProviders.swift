import Foundation

import enum Domain.DaysToMaturityBasis
import struct Domain.GardenTask
import enum Domain.SowingAction

public enum AttentionProviders {
    static let reasonLocale = Locale(identifier: "en_US")
}

extension AttentionProviders {
    public struct HarvestCandidate: Equatable, Sendable {
        public let plantingID: String
        public let plantName: String
        public let locationName: String?
        public let plantedOn: Date?
        public let transplantedOn: Date?
        public let expectedMaturityOn: Date?
        public let daysToMaturity: ClosedRange<Int>?
        public let basis: DaysToMaturityBasis?
        public let firstHarvestOn: Date?

        public init(
            plantingID: String,
            plantName: String,
            locationName: String? = nil,
            plantedOn: Date? = nil,
            transplantedOn: Date? = nil,
            expectedMaturityOn: Date? = nil,
            daysToMaturity: ClosedRange<Int>? = nil,
            basis: DaysToMaturityBasis? = nil,
            firstHarvestOn: Date? = nil
        ) {
            self.plantingID = plantingID
            self.plantName = plantName
            self.locationName = locationName
            self.plantedOn = plantedOn
            self.transplantedOn = transplantedOn
            self.expectedMaturityOn = expectedMaturityOn
            self.daysToMaturity = daysToMaturity
            self.basis = basis
            self.firstHarvestOn = firstHarvestOn
        }
    }

    public struct PlantableGroup: Equatable, Sendable {
        public let action: SowingAction
        public let plantNames: [String]
        public let windowEnd: Date
        public let firstFrost: Date?

        public init(
            action: SowingAction,
            plantNames: [String],
            windowEnd: Date,
            firstFrost: Date? = nil
        ) {
            self.action = action
            self.plantNames = plantNames
            self.windowEnd = windowEnd
            self.firstFrost = firstFrost
        }
    }

    public struct QuietCandidate: Equatable, Sendable {
        public let plantingID: String
        public let plantName: String
        public let locationName: String?
        public let plantedOn: Date?
        public let lastObservedOn: Date?

        public init(
            plantingID: String,
            plantName: String,
            locationName: String? = nil,
            plantedOn: Date? = nil,
            lastObservedOn: Date? = nil
        ) {
            self.plantingID = plantingID
            self.plantName = plantName
            self.locationName = locationName
            self.plantedOn = plantedOn
            self.lastObservedOn = lastObservedOn
        }
    }

    public struct RecentEvent: Equatable, Sendable {
        public let date: Date
        public let text: String

        public init(date: Date, text: String) {
            self.date = date
            self.text = text
        }
    }
}

extension AttentionProviders {
    public static func taskItems(
        openTasks: [GardenTask],
        now: Date,
        calendar: Calendar
    ) -> [AttentionItem] {
        let startOfToday = calendar.startOfDay(for: now)
        var items: [AttentionItem] = []
        for task in openTasks {
            guard let due = task.dueOn else {
                continue
            }
            if due < startOfToday {
                items.append(
                    AttentionItem(
                        id: "task-\(task.id.rawValue)",
                        kind: .overdueTask,
                        title: task.title,
                        reason: overdueReason(due: due, now: now, calendar: calendar),
                        taskID: task.id,
                        orderDate: due
                    ))
            } else if calendar.isDate(due, inSameDayAs: now) {
                items.append(
                    AttentionItem(
                        id: "task-\(task.id.rawValue)",
                        kind: .dueTodayTask,
                        title: task.title,
                        taskID: task.id,
                        orderDate: due
                    ))
            }
        }
        return items
    }

    public static func harvestChecks(
        candidates: [HarvestCandidate],
        now: Date,
        calendar: Calendar
    ) -> [AttentionItem] {
        var items: [AttentionItem] = []
        for candidate in candidates where candidate.firstHarvestOn == nil {
            guard let expected = expectedMaturity(of: candidate, calendar: calendar) else {
                continue
            }
            let days =
                calendar.dateComponents(
                    [.day], from: calendar.startOfDay(for: expected),
                    to: calendar.startOfDay(for: now)
                ).day ?? 0
            guard days > 0 else {
                continue
            }
            let title =
                candidate.locationName.map { "\(candidate.plantName), \($0)" }
                ?? candidate.plantName
            let noun = days == 1 ? "day" : "days"
            items.append(
                AttentionItem(
                    id: "harvest-\(candidate.plantingID)",
                    kind: .harvestCheck,
                    title: title,
                    reason: "\(days) \(noun) past expected maturity, no harvest recorded",
                    orderDate: expected
                ))
        }
        return items
    }

    public static func plantableItems(
        groups: [PlantableGroup],
        now: Date,
        calendar: Calendar
    ) -> [AttentionItem] {
        groups.compactMap { group in
            guard !group.plantNames.isEmpty else {
                return nil
            }
            return AttentionItem(
                id: "plantable-\(actionSlug(group.action))",
                kind: .plantableNow,
                title: "\(actionPhrase(group.action)) \(nameList(group.plantNames))",
                reason: plantableReason(group: group, now: now, calendar: calendar),
                orderDate: group.windowEnd
            )
        }
    }

    public static func quietItems(
        candidates: [QuietCandidate],
        now: Date,
        calendar: Calendar
    ) -> [AttentionItem] {
        var items: [AttentionItem] = []
        for candidate in candidates {
            guard let anchor = candidate.lastObservedOn ?? candidate.plantedOn else {
                continue
            }
            let days =
                calendar.dateComponents(
                    [.day], from: calendar.startOfDay(for: anchor),
                    to: calendar.startOfDay(for: now)
                ).day ?? 0
            guard days >= AttentionLimits.quietThresholdDays else {
                continue
            }
            let title =
                candidate.locationName.map { "\(candidate.plantName), \($0)" }
                ?? candidate.plantName
            items.append(
                AttentionItem(
                    id: "quiet-\(candidate.plantingID)",
                    kind: .quietLately,
                    title: title,
                    reason: "No observation in \(days) days",
                    orderDate: anchor
                ))
        }
        return items
    }

    public static func recentLines(
        events: [RecentEvent],
        now: Date,
        calendar: Calendar
    ) -> [String] {
        let cutoff = calendar.date(
            byAdding: .day, value: -AttentionLimits.recentlyLookbackDays,
            to: calendar.startOfDay(for: now))
        guard let cutoff else {
            return []
        }
        return
            events
            .filter { $0.date >= cutoff && $0.date <= now }
            .sorted { $0.date > $1.date }
            .prefix(AttentionLimits.recentlyLineCap)
            .map { "\(dayPhrase($0.date, now: now, calendar: calendar)): \($0.text)" }
    }
}

extension AttentionProviders {
    static func dayPhrase(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today"
        }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)
        if let yesterday, calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        return date.formatted(
            Date.FormatStyle(locale: reasonLocale, calendar: calendar)
                .weekday(.wide))
    }

    static func overdueReason(due: Date, now: Date, calendar: Calendar) -> String {
        let days =
            calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: due),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
        let dueText = due.formatted(
            Date.FormatStyle(locale: reasonLocale, calendar: calendar)
                .month(.abbreviated).day())
        let ago = days == 1 ? "yesterday" : "\(days) days ago"
        return "Due \(dueText), \(ago)"
    }

    static func plantableReason(
        group: PlantableGroup,
        now: Date,
        calendar: Calendar
    ) -> String {
        let style = Date.FormatStyle(locale: reasonLocale, calendar: calendar)
            .month(.abbreviated).day()
        if let firstFrost = group.firstFrost {
            let days =
                calendar.dateComponents(
                    [.day], from: calendar.startOfDay(for: now),
                    to: calendar.startOfDay(for: firstFrost)
                ).day ?? 0
            let weeks = max(days / 7, 0)
            if weeks >= 2 {
                return "\(weeks) weeks to first frost, \(firstFrost.formatted(style))"
            }
        }
        return "Window closes \(group.windowEnd.formatted(style))"
    }

    static func actionPhrase(_ action: SowingAction) -> String {
        switch action {
        case .sowIndoors: "Start indoors"
        case .directSow: "Direct sow"
        case .transplantOut: "Transplant out"
        }
    }

    static func actionSlug(_ action: SowingAction) -> String {
        switch action {
        case .sowIndoors: "indoors"
        case .directSow: "direct"
        case .transplantOut: "transplant"
        }
    }

    static func nameList(_ names: [String]) -> String {
        let shown = names.prefix(3).map { $0 }
        let extra = names.count - shown.count
        var text: String
        switch shown.count {
        case 1:
            text = shown[0]
        case 2:
            text = "\(shown[0]) and \(shown[1])"
        default:
            text = "\(shown[0]), \(shown[1]), and \(shown[2])"
        }
        if extra > 0 {
            text += ", and \(extra) more"
        }
        return text
    }

    private static func expectedMaturity(
        of candidate: HarvestCandidate,
        calendar: Calendar
    ) -> Date? {
        if let stored = candidate.expectedMaturityOn {
            return stored
        }
        guard let days = candidate.daysToMaturity?.upperBound else {
            return nil
        }
        let start =
            candidate.basis == .fromTransplant
            ? candidate.transplantedOn ?? candidate.plantedOn
            : candidate.plantedOn
        guard let start else {
            return nil
        }
        return calendar.date(byAdding: .day, value: days, to: start)
    }
}
