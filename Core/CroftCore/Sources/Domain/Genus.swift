public struct Genus: Equatable, Sendable, Codable {
    public typealias ID = TaxonID<Genus>

    public var id: ID
    public var familyID: PlantFamily.ID
    public var name: String

    public init(
        id: ID = .generate(),
        familyID: PlantFamily.ID,
        name: String
    ) {
        self.id = id
        self.familyID = familyID
        self.name = name
    }
}
