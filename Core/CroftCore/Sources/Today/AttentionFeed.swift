import Foundation

import struct Domain.GardenTask

public enum AttentionKind: CaseIterable, Hashable, Sendable {
    case frostAlert
    case overdueTask
    case dueTodayTask
    case harvestCheck
    case plantableNow
    case quietLately

    public var label: String {
        switch self {
        case .frostAlert: "Frost alert"
        case .overdueTask: "Overdue"
        case .dueTodayTask: "Today"
        case .harvestCheck: "Harvest check"
        case .plantableNow: "Plantable now"
        case .quietLately: "Quiet lately"
        }
    }
}

public struct AttentionItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let kind: AttentionKind
    public let title: String
    public let reason: String?
    public let taskID: GardenTask.ID?
    public let orderDate: Date

    public init(
        id: String,
        kind: AttentionKind,
        title: String,
        reason: String? = nil,
        taskID: GardenTask.ID? = nil,
        orderDate: Date
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.reason = reason
        self.taskID = taskID
        self.orderDate = orderDate
    }
}

public enum AttentionLimits {
    public static let totalCap = 8
    public static let quietThresholdDays = 14
    public static let recentlyLineCap = 5
    public static let recentlyLookbackDays = 7

    public static func quota(for kind: AttentionKind) -> Int {
        switch kind {
        case .frostAlert: 2
        case .overdueTask: 5
        case .dueTodayTask: 4
        case .harvestCheck: 3
        case .plantableNow: 2
        case .quietLately: 2
        }
    }
}

public enum AttentionFeed {
    public static func compose(_ items: [AttentionItem]) -> [AttentionItem] {
        var result: [AttentionItem] = []
        for kind in AttentionKind.allCases {
            let ofKind =
                items
                .filter { $0.kind == kind }
                .sorted { first, second in
                    first.orderDate == second.orderDate
                        ? first.id < second.id
                        : first.orderDate < second.orderDate
                }
                .prefix(AttentionLimits.quota(for: kind))
            result.append(contentsOf: ofKind)
        }
        return Array(result.prefix(AttentionLimits.totalCap))
    }
}
