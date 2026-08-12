import Foundation

public typealias StarterBatchID = PropagationID<StarterBatch>

public enum StarterBatchStatus: String, CaseIterable, Codable, Hashable, Sendable {
    case sown
    case growing
    case transplanted
    case failed
}

public struct StarterBatch: Equatable, Sendable, Codable {
    public typealias ID = StarterBatchID

    public var id: ID
    public var seedLotID: SeedLot.ID
    public var sownOn: Date?
    public var quantity: Int?
    public var status: StarterBatchStatus

    public init(
        id: ID = .generate(),
        seedLotID: SeedLot.ID,
        sownOn: Date? = nil,
        quantity: Int? = nil,
        status: StarterBatchStatus = .sown
    ) {
        self.id = id
        self.seedLotID = seedLotID
        self.sownOn = sownOn
        self.quantity = quantity
        self.status = status
    }
}
