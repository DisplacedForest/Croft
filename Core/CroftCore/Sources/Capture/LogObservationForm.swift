import Foundation
import Observation

import enum Domain.LifecycleStage
import enum Domain.ObservationTarget

@Observable
public final class LogObservationForm {
    public var target: ObservationTarget?
    public var observedAt: Date
    public var notes: String = ""
    public var stage: LifecycleStage?
    public var photos: [Data] = []
    public private(set) var validationMessage: String?
    public private(set) var savedID: ObservationRecord.ID?

    private let context: CaptureContext
    private var attachedCount = 0

    public init(context: CaptureContext, target: ObservationTarget?, now: Date = Date()) {
        self.context = context
        self.target = target
        observedAt = now
    }

    public var canSave: Bool {
        target != nil
            && (!notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || stage != nil
                || !photos.isEmpty)
    }

    @discardableResult
    public func save() throws -> ObservationRecord {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard target != nil else {
            validationMessage = "Pick what this observation is about."
            throw CaptureValidationError.incomplete
        }
        guard !trimmed.isEmpty || stage != nil || !photos.isEmpty else {
            validationMessage = "Pick a stage, write a note, or attach a photo."
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
        guard let target else {
            throw CaptureValidationError.incomplete
        }
        let observation = ObservationRecord(
            target: target,
            observedAt: observedAt,
            notes: trimmed.isEmpty ? nil : trimmed,
            stage: stage
        )
        try context.observations.insert(observation)
        savedID = observation.id
        return observation.id
    }
}
