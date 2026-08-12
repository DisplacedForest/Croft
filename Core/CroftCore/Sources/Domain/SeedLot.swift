import Foundation

public typealias SeedLotID = PropagationID<SeedLot>

public struct SeedLot: Equatable, Sendable, Codable {
    public typealias ID = SeedLotID

    public var id: ID
    public var cultivarID: Cultivar.ID
    public var source: String?
    public var acquiredOn: Date?
    public var quantity: String?
    public var seedCount: Int?
    public var notes: String?

    public init(
        id: ID = .generate(),
        cultivarID: Cultivar.ID,
        source: String? = nil,
        acquiredOn: Date? = nil,
        quantity: String? = nil,
        seedCount: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.cultivarID = cultivarID
        self.source = source
        self.acquiredOn = acquiredOn
        self.quantity = quantity
        self.seedCount = seedCount
        self.notes = notes
    }
}
