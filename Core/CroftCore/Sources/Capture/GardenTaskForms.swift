import Foundation
import Observation

import struct Domain.GardenTask
import enum Domain.GardenTaskTarget
import enum Domain.GardenTaskType

@Observable
public final class AddTaskForm {
    public var title: String = ""
    public var type: GardenTaskType = .other
    public var customType: String = ""
    public var target: GardenTaskTarget?
    public var dueOn: Date?
    public var notes: String = ""
    public private(set) var validationMessage: String?

    private let context: CaptureContext

    public init(context: CaptureContext, target: GardenTaskTarget? = nil) {
        self.context = context
        self.target = target
    }

    public var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    public func save() throws -> GardenTask {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationMessage = "Give the task a title."
            throw CaptureValidationError.incomplete
        }
        let trimmedCustom = customType.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let task = GardenTask(
            type: type,
            customType: type == .other && !trimmedCustom.isEmpty ? trimmedCustom : nil,
            title: trimmed,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            dueOn: dueOn,
            target: target
        )
        try context.tasks.insert(task)
        return task
    }
}

@Observable
public final class TaskChecklist {
    public private(set) var open: [GardenTask] = []
    public var actionError: String?

    private let context: CaptureContext

    public init(context: CaptureContext) {
        self.context = context
        refresh()
    }

    public func refresh() {
        do {
            open = try context.tasks.openTasks()
        } catch {
            actionError = error.localizedDescription
        }
    }

    public func complete(_ id: GardenTask.ID, on date: Date = Date()) {
        do {
            try context.tasks.complete(id: id, on: date)
            refresh()
        } catch {
            actionError = error.localizedDescription
        }
    }
}
