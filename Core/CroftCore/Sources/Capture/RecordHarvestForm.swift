import Foundation
import Observation

import struct Domain.Harvest
import enum Domain.HarvestQuality
import enum Domain.HarvestYield
import enum Domain.HarvestablePart
import struct Domain.Planting
import struct Domain.Quantity
import enum Domain.QuantityUnit
import enum Domain.UnitSystem

@Observable
public final class RecordHarvestForm {
    public let unitChoices: [HarvestUnitChoice]
    public private(set) var partChoices: [HarvestablePart] = []
    public var plantingID: Planting.ID? {
        didSet {
            guard plantingID != oldValue else {
                return
            }
            reseedParts()
        }
    }
    public var quantityText: String = ""
    public var unitChoice: HarvestUnitChoice
    public var customUnit: String = ""
    public var harvestedPart: HarvestablePart?
    public var quality: HarvestQuality?
    public var harvestedOn: Date
    public var notes: String = ""
    public private(set) var validationMessage: String?
    public private(set) var savedCount = 0

    private let context: CaptureContext

    public init(context: CaptureContext, plantingID: Planting.ID?, now: Date = Date()) {
        self.context = context
        self.plantingID = plantingID
        let system = context.defaults.preferredUnitSystem
        unitChoices = HarvestUnitChoice.ordered(preferring: system)
        unitChoice =
            context.defaults.lastHarvestUnit ?? .unit(system == .metric ? .gram : .pound)
        harvestedOn = now
        reseedParts()
    }

    private func reseedParts() {
        partChoices = plantingID.flatMap { try? context.harvestableParts(for: $0) } ?? []
        harvestedPart = partChoices.count == 1 ? partChoices.first : nil
    }

    public var yield: HarvestYield? {
        switch unitChoice {
        case .unit(let unit):
            guard
                let quantity = try? Quantity.parse(amountText: quantityText, unit: unit),
                quantity.canonicalAmount > 0
            else {
                return nil
            }
            return .measured(quantity)
        case .custom:
            let label = customUnit.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                let amount = Double(quantityText.replacingOccurrences(of: ",", with: ".")),
                amount > 0, !label.isEmpty
            else {
                return nil
            }
            return .custom(amount: amount, label: label)
        }
    }

    public var canSave: Bool { plantingID != nil && yield != nil }

    @discardableResult
    public func save() throws -> Harvest {
        guard let plantingID else {
            validationMessage = "Pick a planting."
            throw CaptureValidationError.incomplete
        }
        guard let yield else {
            validationMessage = "Enter a quantity above zero."
            throw CaptureValidationError.incomplete
        }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let harvest = Harvest(
            plantingID: plantingID,
            harvestedOn: harvestedOn,
            yield: yield,
            harvestedPart: harvestedPart,
            quality: quality,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        try context.harvests.insert(harvest)
        context.defaults.lastHarvestUnit = unitChoice
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
