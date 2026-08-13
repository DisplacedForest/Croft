public enum LifeCycle: String, CaseIterable, Codable, Sendable {
    case annual
    case biennial
    case perennial
}

public enum GrowthHabit: String, CaseIterable, Codable, Sendable {
    case upright
    case bush
    case vine
    case sprawling
    case rosette
    case clumping
}

public enum SunExposure: String, CaseIterable, Codable, Sendable {
    case fullSun
    case partialSun
    case partialShade
    case fullShade
}

public enum WaterNeed: String, CaseIterable, Codable, Sendable {
    case low
    case moderate
    case high
}

public enum HarvestablePart: String, CaseIterable, Codable, Sendable {
    case leaf
    case stem
    case root
    case tuber
    case bulb
    case fruit
    case seed
    case flower
}

public enum SowingMethod: String, CaseIterable, Codable, Sendable {
    case direct
    case transplant
    case both
    case plantingStock
}

public enum FrostTolerance: String, CaseIterable, Codable, Sendable {
    case tender
    case halfHardy
    case hardy
}

public enum DaysToMaturityBasis: String, CaseIterable, Codable, Sendable {
    case fromTransplant
    case fromDirectSow
    case fromPlantingStock
}

public enum PlantingSeason: String, CaseIterable, Codable, Sendable {
    case spring
    case summer
    case fall
    case winter
    case coolSeason
    case warmSeason
}

public enum SeedPrep: String, CaseIterable, Codable, Sendable {
    case soaking
    case scarification
    case stratification
    case coldStratification
    case requiresLight
    case requiresDark
}

public enum SeedType: String, CaseIterable, Codable, Sendable {
    case openPollinated
    case hybrid
    case heirloom
    case organic
    case bulb
    case root
}
