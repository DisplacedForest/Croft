public struct Property: Equatable, Sendable, Codable {
    public typealias ID = StructureID<Property>

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
