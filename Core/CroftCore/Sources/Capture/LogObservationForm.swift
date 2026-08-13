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
    public private(set) var savedID: ObservationRecord.ID?

    private let context: CaptureContext
    private var attachedCount = 0

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
        do {
            let id = try savedID ?? insertRecord(notes: trimmed)
            while attachedCount < photos.count {
                _ = try context.observations.addPhoto(photos[attachedCount], to: id)
                attachedCount += 1
            }
            validationMessage = nil
            guard let observation = try context.observations.fetch(id: id) else {
                throw CaptureValidationError.incomplete
            }
            return observation
        } catch {
            validationMessage = "Couldn't save the observation. Try again."
            throw error
        }
    }

    private func insertRecord(notes trimmed: String) throws -> ObservationRecord.ID {
        let observation = ObservationRecord(
            target: target,
            observedAt: observedAt,
            notes: trimmed.isEmpty ? nil : trimmed
        )
        try context.observations.insert(observation)
        savedID = observation.id
        return observation.id
    }
}
