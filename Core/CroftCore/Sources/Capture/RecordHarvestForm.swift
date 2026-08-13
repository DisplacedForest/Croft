import Foundation
import Observation

import struct Domain.Harvest
import enum Domain.HarvestQuality
import enum Domain.HarvestUnit
import struct Domain.Planting

@Observable
public final class RecordHarvestForm {
    public let plantingID: Planting.ID
    public var quantityText: String = ""
    public var unit: HarvestUnit
    public var customUnit: String = ""
    public var quality: HarvestQuality?
    public var harvestedOn: Date
    public var notes: String = ""
    public private(set) var validationMessage: String?
    public private(set) var savedCount = 0

    private let context: CaptureContext

    public init(context: CaptureContext, plantingID: Planting.ID, now: Date = Date()) {
        self.context = context
        self.plantingID = plantingID
        unit = context.defaults.lastHarvestUnit ?? .gram
        harvestedOn = now
    }

    public var quantity: Double? {
        Double(quantityText.replacingOccurrences(of: ",", with: "."))
    }

    public var canSave: Bool {
        guard let quantity else {
            return false
        }
        if unit == .custom {
            return quantity > 0
                && !customUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return quantity > 0
    }

    @discardableResult
    public func save() throws -> Harvest {
        guard canSave, let quantity else {
            validationMessage = "Enter a quantity above zero."
            throw CaptureValidationError.incomplete
        }
        let trimmedUnit = customUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let harvest = Harvest(
            plantingID: plantingID,
            harvestedOn: harvestedOn,
            quantity: quantity,
            unit: unit,
            customUnit: unit == .custom ? trimmedUnit : nil,
            quality: quality,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        try context.harvests.insert(harvest)
        context.defaults.lastHarvestUnit = unit
        savedCount += 1
        return harvest
    }

    public func prepareForAnother() {
        quantityText = ""
        quality = nil
        notes = ""
        validationMessage = nil
    }
}
