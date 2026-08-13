import Foundation

public typealias PlantingID = PropagationID<Planting>

public enum PlantIdentity: Hashable, Sendable, Codable {
    case cultivar(Cultivar.ID)
    case species(Species.ID)
}

public enum PlantingSource: Hashable, Sendable, Codable {
    case seedLot(SeedLot.ID)
    case starterBatch(StarterBatch.ID)
}

public enum PlantingStatus: String, CaseIterable, Codable, Hashable, Sendable {
    case planned
    case active
    case finished
    case failed
}

public struct Planting: Equatable, Sendable, Codable {
    public typealias ID = PlantingID

    public var id: ID
    public var identity: PlantIdentity
    public var bedID: Bed.ID
    public var source: PlantingSource?
    public var plantedOn: Date?
    public var transplantedOn: Date?
    public var quantity: Int?
    public var spacingCentimeters: Double?
    public var status: PlantingStatus
    public var expectedMaturityOn: Date?
    public var endedOn: Date?
    public var notes: String?

    public init(
        id: ID = .generate(),
        identity: PlantIdentity,
        bedID: Bed.ID,
        source: PlantingSource? = nil,
        plantedOn: Date? = nil,
        transplantedOn: Date? = nil,
        quantity: Int? = nil,
        spacingCentimeters: Double? = nil,
        status: PlantingStatus = .planned,
        expectedMaturityOn: Date? = nil,
        endedOn: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.identity = identity
        self.bedID = bedID
        self.source = source
        self.plantedOn = plantedOn
        self.transplantedOn = transplantedOn
        self.quantity = quantity
        self.spacingCentimeters = spacingCentimeters
        self.status = status
        self.expectedMaturityOn = expectedMaturityOn
        self.endedOn = endedOn
        self.notes = notes
    }
}
