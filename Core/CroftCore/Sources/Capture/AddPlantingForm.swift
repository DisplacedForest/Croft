import Foundation
import Observation
import PlantCatalog

import struct Domain.Bed
import enum Domain.PlantIdentity
import struct Domain.Planting
import enum Domain.PlantingSource
import enum Domain.PlantingStatus

@Observable
public final class AddPlantingForm {
    public var identity: PlantIdentity?
    public var bedID: Bed.ID?
    public var source: PlantingSource?
    public var quantity: Int?
    public var plantedOn: Date
    public var notes: String = ""
    public private(set) var validationMessage: String?
    public let intendedStatus: PlantingStatus
    public private(set) var rotationWarning: RotationWarning?
    public private(set) var bedHistory: [FamilyOccupancy] = []
    public private(set) var showsEmptyHistoryNote = false

    private let context: CaptureContext

    public init(
        context: CaptureContext,
        bedID: Bed.ID? = nil,
        identity: PlantIdentity? = nil,
        planned: Bool = false,
        now: Date = Date()
    ) {
        self.context = context
        self.bedID = bedID ?? context.defaults.lastBedID
        self.identity = identity
        intendedStatus = planned ? .planned : .active
        plantedOn = now
    }

    public var canSave: Bool {
        identity != nil && bedID != nil
    }

    public func refreshRotation(on reference: Date = Date()) {
        guard let bedID else {
            rotationWarning = nil
            bedHistory = []
            showsEmptyHistoryNote = false
            return
        }
        let rotation = context.rotationHistory
        rotationWarning = identity.flatMap {
            try? rotation.warning(for: $0, inBed: bedID, on: reference)
        }
        if intendedStatus == .planned {
            let lines = try? rotation.historyLines(inBed: bedID, on: reference)
            bedHistory = lines ?? []
            showsEmptyHistoryNote = lines?.isEmpty == true
        } else {
            bedHistory = []
            showsEmptyHistoryNote = false
        }
    }

    @discardableResult
    public func save() throws -> Planting {
        guard let identity, let bedID else {
            validationMessage = "Pick a plant and a bed first."
            throw CaptureValidationError.incomplete
        }
        let receipt = try context.adopter.adopt(identity)
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let planting = Planting(
            identity: identity,
            bedID: bedID,
            source: source,
            plantedOn: intendedStatus == .active ? plantedOn : nil,
            quantity: quantity,
            status: intendedStatus,
            notes: trimmed.isEmpty ? nil : trimmed
        )
        do {
            try context.plantings.insert(planting)
        } catch {
            context.adopter.undo(receipt)
            validationMessage = "Couldn't save the planting. Try again."
            throw error
        }
        context.defaults.lastBedID = bedID
        return planting
    }
}

public enum CaptureValidationError: Error, Hashable {
    case incomplete
}
