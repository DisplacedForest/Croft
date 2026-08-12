public struct PlantFamily: Equatable, Sendable, Codable {
    public typealias ID = TaxonID<PlantFamily>

    public var id: ID
    public var name: String
    public var commonNames: [String]

    public init(
        id: ID = .generate(),
        name: String,
        commonNames: [String] = []
    ) {
        self.id = id
        self.name = name
        self.commonNames = commonNames
    }
}
