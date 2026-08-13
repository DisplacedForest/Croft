import Foundation
import Observation
import PlantCatalog

import struct Domain.Bed
import enum Domain.PlantIdentity
import struct Domain.Planting
import enum Domain.PlantingSource

@Observable
public final class AddPlantingForm {
    public var identity: PlantIdentity?
    public var bedID: Bed.ID?
    public var source: PlantingSource?
    public var quantity: Int?
    public var plantedOn: Date
    public var notes: String = ""
    public private(set) var validationMessage: String?

    private let context: CaptureContext

    public init(context: CaptureContext, bedID: Bed.ID? = nil, now: Date = Date()) {
        self.context = context
        self.bedID = bedID ?? context.defaults.lastBedID
        plantedOn = now
    }

    public var canSave: Bool {
        identity != nil && bedID != nil
    }

    @discardableResult
    public func save() throws -> Planting {
        guard let identity, let bedID else {
            validationMessage = "Pick a plant and a bed first."
            throw CaptureValidationError.incomplete
        }
        let adopted = try context.adopter.adopt(identity)
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let planting = Planting(
            identity: adopted,
            bedID: bedID,
            source: source,
            plantedOn: plantedOn,
            quantity: quantity,
            status: .active,
            notes: trimmed.isEmpty ? nil : trimmed
        )
        try context.plantings.insert(planting)
        context.defaults.lastBedID = bedID
        return planting
    }
}

public enum CaptureValidationError: Error, Hashable {
    case incomplete
}
