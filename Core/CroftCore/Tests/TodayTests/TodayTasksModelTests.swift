import Foundation
import Testing

import struct Domain.GardenTask
import enum Domain.GardenTaskType

@testable import Today

private final class StubTaskProvider: GardenTaskProviding, @unchecked Sendable {
    var tasks: [GardenTask]
    var completed: [(id: GardenTask.ID, date: Date)] = []
    var failing = false

    init(tasks: [GardenTask]) {
        self.tasks = tasks
    }

    func openTasks() throws -> [GardenTask] {
        guard !failing else {
            throw StubFailure.unavailable
        }
        return tasks.filter { !$0.completed }
    }

    func complete(id: GardenTask.ID, on date: Date) throws {
        guard !failing else {
            throw StubFailure.unavailable
        }
        completed.append((id, date))
        tasks = tasks.map { task in
            var task = task
            if task.id == id {
                task.completed = true
                task.completedOn = date
            }
            return task
        }
    }
}

private enum StubFailure: Error {
    case unavailable
}

private let utcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
    return calendar
}()

private let noon = Date(timeIntervalSince1970: 1_755_086_400)

private func task(_ title: String, dueOffset: TimeInterval?) -> GardenTask {
    GardenTask(
        type: .water,
        title: title,
        dueOn: dueOffset.map { noon.addingTimeInterval($0) }
    )
}

private let day: TimeInterval = 86_400

@MainActor
private func makeModel(_ provider: StubTaskProvider) -> TodayTasksModel {
    TodayTasksModel(provider: provider, calendar: utcCalendar)
}

@Test @MainActor func dueTodaySelectionExcludesUndatedAndFuture() {
    let provider = StubTaskProvider(tasks: [
        task("this morning", dueOffset: -day / 4),
        task("tonight", dueOffset: day / 4),
        task("tomorrow", dueOffset: day),
        task("someday", dueOffset: nil),
    ])
    let model = makeModel(provider)
    model.refresh(now: noon)
    #expect(model.dueToday.map(\.title) == ["this morning", "tonight"])
    #expect(model.overdue.isEmpty)
}

@Test @MainActor func overdueSelectionUsesStartOfDayNotTheInstant() {
    let provider = StubTaskProvider(tasks: [
        task("yesterday", dueOffset: -day),
        task("last week", dueOffset: -7 * day),
        task("this morning", dueOffset: -day / 4),
    ])
    let model = makeModel(provider)
    model.refresh(now: noon)
    #expect(model.overdue.map(\.title) == ["yesterday", "last week"])
    #expect(model.dueToday.map(\.title) == ["this morning"])
}

@Test @MainActor func providerOrderIsPreserved() {
    let provider = StubTaskProvider(tasks: [
        task("first", dueOffset: -2 * day),
        task("second", dueOffset: -day),
        task("third", dueOffset: 0),
        task("fourth", dueOffset: day / 4),
    ])
    let model = makeModel(provider)
    model.refresh(now: noon)
    #expect(model.overdue.map(\.title) == ["first", "second"])
    #expect(model.dueToday.map(\.title) == ["third", "fourth"])
}

@Test @MainActor func completingATaskRemovesItAndRecordsTheCompletion() throws {
    let provider = StubTaskProvider(tasks: [
        task("water the beds", dueOffset: 0),
        task("thin the carrots", dueOffset: 0),
    ])
    let model = makeModel(provider)
    model.refresh(now: noon)
    let target = try #require(model.dueToday.first)

    model.complete(target, now: noon)

    #expect(model.dueToday.map(\.title) == ["thin the carrots"])
    #expect(provider.completed.map(\.id) == [target.id])
    #expect(provider.completed.map(\.date) == [noon])
}

@Test @MainActor func emptyWhenNothingIsDue() {
    let provider = StubTaskProvider(tasks: [
        task("someday", dueOffset: nil),
        task("next month", dueOffset: 30 * day),
    ])
    let model = makeModel(provider)
    model.refresh(now: noon)
    #expect(model.isEmpty)
}

@Test @MainActor func failedRefreshLeavesTheListAsItWas() {
    let provider = StubTaskProvider(tasks: [task("water", dueOffset: 0)])
    let model = makeModel(provider)
    model.refresh(now: noon)
    #expect(!model.isEmpty)

    provider.failing = true
    model.refresh(now: noon)
    #expect(model.dueToday.map(\.title) == ["water"])
}
