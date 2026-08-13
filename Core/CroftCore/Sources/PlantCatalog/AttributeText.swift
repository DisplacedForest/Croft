import Domain
import Foundation

extension SunExposure {
    public var displayName: String {
        switch self {
        case .fullSun: "Full sun"
        case .partialSun: "Partial sun"
        case .partialShade: "Partial shade"
        case .fullShade: "Full shade"
        }
    }
}

extension WaterNeed {
    public var displayName: String {
        switch self {
        case .low: "Low"
        case .moderate: "Moderate"
        case .high: "High"
        }
    }
}

extension LifeCycle {
    public var displayName: String {
        switch self {
        case .annual: "Annual"
        case .biennial: "Biennial"
        case .perennial: "Perennial"
        }
    }
}

extension GrowthHabit {
    public var displayName: String {
        switch self {
        case .upright: "Upright"
        case .bush: "Bush"
        case .vine: "Vine"
        case .sprawling: "Sprawling"
        case .rosette: "Rosette"
        case .clumping: "Clumping"
        }
    }
}

extension FrostTolerance {
    public var displayName: String {
        switch self {
        case .tender: "Tender"
        case .halfHardy: "Half hardy"
        case .hardy: "Hardy"
        }
    }
}

extension HarvestablePart {
    public var displayName: String {
        switch self {
        case .leaf: "Leaves"
        case .stem: "Stems"
        case .root: "Roots"
        case .tuber: "Tubers"
        case .bulb: "Bulbs"
        case .fruit: "Fruit"
        case .seed: "Seeds"
        case .flower: "Flowers"
        }
    }
}

extension PlantPart {
    public var displayName: String {
        switch self {
        case .leaf: "Leaves"
        case .stem: "Stems"
        case .root: "Roots"
        case .tuber: "Tubers"
        case .bulb: "Bulbs"
        case .fruit: "Fruit"
        case .seed: "Seeds"
        case .flower: "Flowers"
        }
    }
}

extension PlantingStatus {
    public var displayName: String {
        switch self {
        case .planned: "Planned"
        case .active: "Growing"
        case .finished: "Finished"
        case .failed: "Failed"
        }
    }
}

extension ActivityEvent.Kind {
    public var displayName: String {
        switch self {
        case .planted: "Planted"
        case .transplanted: "Transplanted"
        case .finished: "Finished"
        case .failed: "Failed"
        }
    }
}

extension PlantThreat.Kind {
    public var displayName: String {
        switch self {
        case .pest: "Pest"
        case .disease: "Disease"
        }
    }
}

public enum ConditionText {
    public static func days(_ range: ClosedRange<Int>) -> String {
        if range.lowerBound == range.upperBound {
            "\(range.lowerBound) days"
        } else {
            "\(range.lowerBound) to \(range.upperBound) days"
        }
    }

    public static func centimeters(_ range: ClosedRange<Double>) -> String {
        if range.lowerBound == range.upperBound {
            "\(number(range.lowerBound)) cm"
        } else {
            "\(number(range.lowerBound)) to \(number(range.upperBound)) cm"
        }
    }

    public static func soilPH(_ range: ClosedRange<Double>) -> String {
        if range.lowerBound == range.upperBound {
            "pH \(phNumber(range.lowerBound))"
        } else {
            "pH \(phNumber(range.lowerBound)) to \(phNumber(range.upperBound))"
        }
    }

    private static func number(_ value: Double) -> String {
        if value.rounded() == value {
            String(Int(value))
        } else {
            String(format: "%.1f", value)
        }
    }

    private static func phNumber(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}
