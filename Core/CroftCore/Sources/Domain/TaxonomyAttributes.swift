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
