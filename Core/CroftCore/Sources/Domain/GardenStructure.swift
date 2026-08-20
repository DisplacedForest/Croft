public struct Property: Equatable, Sendable, Codable {
    public typealias ID = StructureID<Property>

    public var id: ID
    public var name: String
    public var notes: String?
    public var isArchived: Bool
    public var location: GeoCoordinate?
    public var hardinessZone: HardinessZone?
    public var lastFrost: MonthDay?
    public var firstFrost: MonthDay?
    public var zoneSource: ClimateSource
    public var frostDatesSource: ClimateSource

    public init(
        id: ID = .generate(),
        name: String,
        notes: String? = nil,
        isArchived: Bool = false,
        location: GeoCoordinate? = nil,
        hardinessZone: HardinessZone? = nil,
        lastFrost: MonthDay? = nil,
        firstFrost: MonthDay? = nil,
        zoneSource: ClimateSource = .derived,
        frostDatesSource: ClimateSource = .derived
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.isArchived = isArchived
        self.location = location
        self.hardinessZone = hardinessZone
        self.lastFrost = lastFrost
        self.firstFrost = firstFrost
        self.zoneSource = zoneSource
        self.frostDatesSource = frostDatesSource
    }
}

public struct Garden: Equatable, Sendable, Codable {
    public typealias ID = StructureID<Garden>

    public var id: ID
    public var name: String
    public var notes: String?
    public var isArchived: Bool

    public init(
        id: ID = .generate(),
        name: String,
        notes: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.isArchived = isArchived
    }
}

public struct GrowingArea: Equatable, Sendable, Codable {
    public typealias ID = StructureID<GrowingArea>

    public var id: ID
    public var name: String
    public var notes: String?
    public var isArchived: Bool

    public init(
        id: ID = .generate(),
        name: String,
        notes: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.isArchived = isArchived
    }
}

public enum BedKind: String, CaseIterable, Codable, Hashable, Sendable {
    case raised
    case inGround = "in_ground"
    case container
}

public struct Bed: Equatable, Sendable, Codable {
    public typealias ID = StructureID<Bed>

    public var id: ID
    public var name: String
    public var kind: BedKind
    public var notes: String?
    public var isArchived: Bool

    public init(
        id: ID = .generate(),
        name: String,
        kind: BedKind,
        notes: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.notes = notes
        self.isArchived = isArchived
    }
}
