public struct Disease: Equatable, Sendable, Codable {
    public typealias ID = TaxonID<Disease>

    public var id: ID
    public var name: String
    public var pathogen: String?
    public var pathogenType: PathogenType
    public var symptoms: String?
    public var affectedPlantParts: [PlantPart]
    public var transmission: String?
    public var prevention: [String]
    public var management: [String]

    public init(
        id: ID = .generate(),
        name: String,
        pathogen: String? = nil,
        pathogenType: PathogenType,
        symptoms: String? = nil,
        affectedPlantParts: [PlantPart] = [],
        transmission: String? = nil,
        prevention: [String] = [],
        management: [String] = []
    ) {
        self.id = id
        self.name = name
        self.pathogen = pathogen
        self.pathogenType = pathogenType
        self.symptoms = symptoms
        self.affectedPlantParts = affectedPlantParts
        self.transmission = transmission
        self.prevention = prevention
        self.management = management
    }
}

public struct Pathogen: Equatable, Sendable, Codable {
    public typealias ID = TaxonID<Pathogen>

    public var id: ID
    public var name: String

    public init(id: ID = .generate(), name: String) {
        self.id = id
        self.name = name
    }
}

public struct EnvironmentalCondition: Equatable, Sendable, Codable {
    public typealias ID = TaxonID<EnvironmentalCondition>

    public var id: ID
    public var name: String

    public init(id: ID = .generate(), name: String) {
        self.id = id
        self.name = name
    }
}
