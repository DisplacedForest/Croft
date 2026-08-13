import Foundation
import Observation

import enum Domain.ObservationTarget

@Observable
public final class LogObservationForm {
    public let target: ObservationTarget
    public var observedAt: Date
    public var notes: String = ""
    public var photos: [Data] = []
    public private(set) var validationMessage: String?

    private let context: CaptureContext

    public init(context: CaptureContext, target: ObservationTarget, now: Date = Date()) {
        self.context = context
        self.target = target
        observedAt = now
    }

    public var canSave: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !photos.isEmpty
    }

    @discardableResult
    public func save() throws -> ObservationRecord {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !photos.isEmpty else {
            validationMessage = "Write a note or attach a photo."
            throw CaptureValidationError.incomplete
        }
        let observation = ObservationRecord(
            target: target,
            observedAt: observedAt,
            notes: trimmed.isEmpty ? nil : trimmed
        )
        try context.observations.insert(observation)
        for data in photos {
            _ = try context.observations.addPhoto(data, to: observation.id)
        }
        return observation
    }
}
