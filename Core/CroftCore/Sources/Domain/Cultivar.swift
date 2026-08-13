public struct Cultivar: Equatable, Sendable, Codable {
    public typealias ID = TaxonID<Cultivar>

    public var id: ID
    public var speciesID: Species.ID
    public var name: String
    public var commonNames: [String]
    public var daysToMaturity: ClosedRange<Int>?
    public var spacingCentimeters: ClosedRange<Double>?
    public var growthHabit: GrowthHabit?
    public var plantingSeasons: [PlantingSeason]
    public var seedPreps: [SeedPrep]
    public var heirloom: Bool?
    public var seedTypes: [SeedType]

    public init(
        id: ID = .generate(),
        speciesID: Species.ID,
        name: String,
        commonNames: [String] = [],
        daysToMaturity: ClosedRange<Int>? = nil,
        spacingCentimeters: ClosedRange<Double>? = nil,
        growthHabit: GrowthHabit? = nil,
        plantingSeasons: [PlantingSeason] = [],
        seedPreps: [SeedPrep] = [],
        heirloom: Bool? = nil,
        seedTypes: [SeedType] = []
    ) {
        self.id = id
        self.speciesID = speciesID
        self.name = name
        self.commonNames = commonNames
        self.daysToMaturity = daysToMaturity
        self.spacingCentimeters = spacingCentimeters
        self.growthHabit = growthHabit
        self.plantingSeasons = plantingSeasons
        self.seedPreps = seedPreps
        self.heirloom = heirloom
        self.seedTypes = seedTypes
    }
}
