import Foundation

public typealias HarvestID = PropagationID<Harvest>

public enum HarvestYield: Equatable, Hashable, Sendable, Codable {
    case measured(Quantity)
    case custom(amount: Double, label: String)
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
    public var yield: HarvestYield
    public var harvestedPart: HarvestablePart?
    public var quality: HarvestQuality?
    public var notes: String?

    public init(
        id: ID = .generate(),
        plantingID: Planting.ID,
        harvestedOn: Date,
        yield: HarvestYield,
        harvestedPart: HarvestablePart? = nil,
        quality: HarvestQuality? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.plantingID = plantingID
        self.harvestedOn = harvestedOn
        self.yield = yield
        self.harvestedPart = harvestedPart
        self.quality = quality
        self.notes = notes
    }
}
