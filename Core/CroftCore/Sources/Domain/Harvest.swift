import Foundation

public typealias HarvestID = PropagationID<Harvest>

public enum HarvestUnit: String, CaseIterable, Codable, Hashable, Sendable {
    case gram
    case kilogram
    case ounce
    case pound
    case count
    case bunch
    case custom
}

public enum HarvestQuality: String, CaseIterable, Codable, Hashable, Sendable {
    case excellent
    case good
    case fair
    case poor
}

public struct Harvest: Equatable, Sendable, Codable {
    public typealias ID = HarvestID

    public var id: ID
    public var plantingID: Planting.ID
    public var harvestedOn: Date
    public var quantity: Double
    public var unit: HarvestUnit
    public var customUnit: String?
    public var quality: HarvestQuality?
    public var notes: String?

    public init(
        id: ID = .generate(),
        plantingID: Planting.ID,
        harvestedOn: Date,
        quantity: Double,
        unit: HarvestUnit,
        customUnit: String? = nil,
        quality: HarvestQuality? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.plantingID = plantingID
        self.harvestedOn = harvestedOn
        self.quantity = quantity
        self.unit = unit
        self.customUnit = customUnit
        self.quality = quality
        self.notes = notes
    }
}
