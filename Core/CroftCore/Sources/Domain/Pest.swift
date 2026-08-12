public struct Pest: Equatable, Sendable, Codable {
    public typealias ID = TaxonID<Pest>

    public var id: ID
    public var commonName: String
    public var scientificName: String?
    public var organismType: OrganismType
    public var description: String?
    public var lifeCycle: String?
    public var affectedPlantParts: [PlantPart]
    public var typicalDamage: String?
    public var activeSeasons: [Season]
    public var geographicRange: String?

    public init(
        id: ID = .generate(),
        commonName: String,
        scientificName: String? = nil,
        organismType: OrganismType,
        description: String? = nil,
        lifeCycle: String? = nil,
        affectedPlantParts: [PlantPart] = [],
        typicalDamage: String? = nil,
        activeSeasons: [Season] = [],
        geographicRange: String? = nil
    ) {
        self.id = id
        self.commonName = commonName
        self.scientificName = scientificName
        self.organismType = organismType
        self.description = description
        self.lifeCycle = lifeCycle
        self.affectedPlantParts = affectedPlantParts
        self.typicalDamage = typicalDamage
        self.activeSeasons = activeSeasons
        self.geographicRange = geographicRange
    }
}
