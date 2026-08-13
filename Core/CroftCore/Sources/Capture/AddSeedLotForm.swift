import Foundation
import Observation

import struct Domain.Cultivar
import enum Domain.PlantIdentity
import struct Domain.SeedLot

@Observable
public final class AddSeedLotForm {
    public var cultivarID: Cultivar.ID?
    public var source: String = ""
    public var acquiredOn: Date
    public var quantityText: String = ""
    public var seedCountText: String = ""
    public var notes: String = ""
    public private(set) var validationMessage: String?

    private let context: CaptureContext

    public init(context: CaptureContext, now: Date = Date()) {
        self.context = context
        acquiredOn = now
    }

    public var canSave: Bool {
        cultivarID != nil && (seedCountText.isEmpty || Int(seedCountText) != nil)
    }

    @discardableResult
    public func save() throws -> SeedLot {
        guard let cultivarID, canSave else {
            validationMessage = "Pick a cultivar first."
            throw CaptureValidationError.incomplete
        }
        let receipt = try context.adopter.adopt(.cultivar(cultivarID))
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuantity = quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let lot = SeedLot(
            cultivarID: cultivarID,
            source: trimmedSource.isEmpty ? nil : trimmedSource,
            acquiredOn: acquiredOn,
            quantity: trimmedQuantity.isEmpty ? nil : trimmedQuantity,
            seedCount: Int(seedCountText),
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
        )
        do {
            try context.seedLots.insert(lot)
        } catch {
            context.adopter.undo(receipt)
            validationMessage = "Couldn't save the seed lot. Try again."
            throw error
        }
        return lot
    }
}
