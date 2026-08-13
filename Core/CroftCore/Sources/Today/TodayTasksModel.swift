import Foundation
import Observation

import struct Domain.GardenTask

public protocol GardenTaskProviding: Sendable {
    func openTasks() throws -> [GardenTask]
    func complete(id: GardenTask.ID, on date: Date) throws
}

@MainActor
@Observable
public final class TodayTasksModel {
    public private(set) var overdue: [GardenTask] = []
    public private(set) var dueToday: [GardenTask] = []

    private let provider: any GardenTaskProviding
    private let calendar: Calendar

    public init(provider: any GardenTaskProviding, calendar: Calendar = .current) {
        self.provider = provider
        self.calendar = calendar
    }

    public var isEmpty: Bool {
        overdue.isEmpty && dueToday.isEmpty
    }

    public func refresh(now: Date = Date()) {
        guard let tasks = try? provider.openTasks() else {
            return
        }
        let startOfToday = calendar.startOfDay(for: now)
        overdue = tasks.filter { task in
            guard let due = task.dueOn else {
                return false
            }
            return due < startOfToday
        }
        dueToday = tasks.filter { task in
            guard let due = task.dueOn else {
                return false
            }
            return due >= startOfToday && calendar.isDate(due, inSameDayAs: now)
        }
    }

    public func complete(_ task: GardenTask, now: Date = Date()) {
        try? provider.complete(id: task.id, on: now)
        refresh(now: now)
    }
}
