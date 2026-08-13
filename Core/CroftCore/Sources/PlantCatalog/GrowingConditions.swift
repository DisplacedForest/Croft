import Domain

public struct PlantAttribute<Value: Equatable & Sendable>: Equatable, Sendable {
    public var value: Value
    public var isCultivarOverride: Bool

    public init(value: Value, isCultivarOverride: Bool = false) {
        self.value = value
        self.isCultivarOverride = isCultivarOverride
    }
}

public struct GrowingConditions: Equatable, Sendable {
    public var sunExposure: SunExposure?
    public var waterNeed: WaterNeed?
    public var soilPH: ClosedRange<Double>?
    public var lifeCycle: LifeCycle?
    public var frostTolerance: FrostTolerance?
    public var spacingCentimeters: PlantAttribute<ClosedRange<Double>>?
    public var daysToMaturity: PlantAttribute<ClosedRange<Int>>?
    public var growthHabit: PlantAttribute<GrowthHabit>?
    public var harvestableParts: [HarvestablePart]

    public init(
        sunExposure: SunExposure? = nil,
        waterNeed: WaterNeed? = nil,
        soilPH: ClosedRange<Double>? = nil,
        lifeCycle: LifeCycle? = nil,
        frostTolerance: FrostTolerance? = nil,
        spacingCentimeters: PlantAttribute<ClosedRange<Double>>? = nil,
        daysToMaturity: PlantAttribute<ClosedRange<Int>>? = nil,
        growthHabit: PlantAttribute<GrowthHabit>? = nil,
        harvestableParts: [HarvestablePart] = []
    ) {
        self.sunExposure = sunExposure
        self.waterNeed = waterNeed
        self.soilPH = soilPH
        self.lifeCycle = lifeCycle
        self.frostTolerance = frostTolerance
        self.spacingCentimeters = spacingCentimeters
        self.daysToMaturity = daysToMaturity
        self.growthHabit = growthHabit
        self.harvestableParts = harvestableParts
    }

    public static func merged(species: Species, cultivar: Cultivar?) -> GrowingConditions {
        GrowingConditions(
            sunExposure: species.sunExposure,
            waterNeed: species.waterNeed,
            soilPH: species.soilPH,
            lifeCycle: species.lifeCycle,
            frostTolerance: species.frostTolerance,
            spacingCentimeters: resolved(species.spacingCentimeters, cultivar?.spacingCentimeters),
            daysToMaturity: resolved(species.daysToMaturity, cultivar?.daysToMaturity),
            growthHabit: resolved(species.growthHabit, cultivar?.growthHabit),
            harvestableParts: species.harvestableParts
        )
    }

    private static func resolved<Value: Equatable & Sendable>(
        _ base: Value?,
        _ override: Value?
    ) -> PlantAttribute<Value>? {
        if let override {
            PlantAttribute(value: override, isCultivarOverride: true)
        } else if let base {
            PlantAttribute(value: base, isCultivarOverride: false)
        } else {
            nil
        }
    }
}
