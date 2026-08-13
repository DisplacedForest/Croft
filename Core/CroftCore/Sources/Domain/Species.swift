public struct Species: Equatable, Sendable, Codable {
    public typealias ID = TaxonID<Species>

    public var id: ID
    public var genusID: Genus.ID
    public var scientificName: String
    public var commonNames: [String]
    public var lifeCycle: LifeCycle?
    public var growthHabit: GrowthHabit?
    public var sunExposure: SunExposure?
    public var waterNeed: WaterNeed?
    public var soilPH: ClosedRange<Double>?
    public var spacingCentimeters: ClosedRange<Double>?
    public var daysToMaturity: ClosedRange<Int>?
    public var hardinessZones: ClosedRange<Int>?
    public var germinationTempMin: Double?
    public var germinationTempOptimal: ClosedRange<Double>?
    public var germinationTempMax: Double?
    public var germinationDays: ClosedRange<Int>?
    public var sowingDepthCentimeters: ClosedRange<Double>?
    public var rowSpacingCentimeters: ClosedRange<Double>?
    public var sowingMethod: SowingMethod?
    public var weeksIndoorsBeforeTransplant: ClosedRange<Int>?
    public var frostTolerance: FrostTolerance?
    public var transplantSoilTempMin: Double?
    public var daysToMaturityBasis: DaysToMaturityBasis?
    public var harvestableParts: [HarvestablePart]

    public init(
        id: ID = .generate(),
        genusID: Genus.ID,
        scientificName: String,
        commonNames: [String] = [],
        lifeCycle: LifeCycle? = nil,
        growthHabit: GrowthHabit? = nil,
        sunExposure: SunExposure? = nil,
        waterNeed: WaterNeed? = nil,
        soilPH: ClosedRange<Double>? = nil,
        spacingCentimeters: ClosedRange<Double>? = nil,
        daysToMaturity: ClosedRange<Int>? = nil,
        hardinessZones: ClosedRange<Int>? = nil,
        germinationTempMin: Double? = nil,
        germinationTempOptimal: ClosedRange<Double>? = nil,
        germinationTempMax: Double? = nil,
        germinationDays: ClosedRange<Int>? = nil,
        sowingDepthCentimeters: ClosedRange<Double>? = nil,
        rowSpacingCentimeters: ClosedRange<Double>? = nil,
        sowingMethod: SowingMethod? = nil,
        weeksIndoorsBeforeTransplant: ClosedRange<Int>? = nil,
        frostTolerance: FrostTolerance? = nil,
        transplantSoilTempMin: Double? = nil,
        daysToMaturityBasis: DaysToMaturityBasis? = nil,
        harvestableParts: [HarvestablePart] = []
    ) {
        self.id = id
        self.genusID = genusID
        self.scientificName = scientificName
        self.commonNames = commonNames
        self.lifeCycle = lifeCycle
        self.growthHabit = growthHabit
        self.sunExposure = sunExposure
        self.waterNeed = waterNeed
        self.soilPH = soilPH
        self.spacingCentimeters = spacingCentimeters
        self.daysToMaturity = daysToMaturity
        self.hardinessZones = hardinessZones
        self.germinationTempMin = germinationTempMin
        self.germinationTempOptimal = germinationTempOptimal
        self.germinationTempMax = germinationTempMax
        self.germinationDays = germinationDays
        self.sowingDepthCentimeters = sowingDepthCentimeters
        self.rowSpacingCentimeters = rowSpacingCentimeters
        self.sowingMethod = sowingMethod
        self.weeksIndoorsBeforeTransplant = weeksIndoorsBeforeTransplant
        self.frostTolerance = frostTolerance
        self.transplantSoilTempMin = transplantSoilTempMin
        self.daysToMaturityBasis = daysToMaturityBasis
        self.harvestableParts = harvestableParts
    }
}
